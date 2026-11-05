// hotspot-page puts the hospital's Wi-Fi page on the router and moves phones to it.
// Run it from the backend folder:
//
//	hotspot-page status
//	hotspot-page check             confirms hotspot_modern was uploaded in WinBox
//	hotspot-page enable            uses the new page and allows the once-a-day login
//	hotspot-page disable           goes back to the old page and settings
//	hotspot-page phone <MAC>       the phone sees the page once a day
//	hotspot-page unphone <MAC>     the phone logs in by MAC again, without the page
//	hotspot-page again <MAC>       ends the device's session and cookies, as the daily job does
//	hotspot-page daily             the page comes back for phones every day at 6 AM
//	hotspot-page undaily           removes that job
//	hotspot-page list              prints the users and hosts, one per line
//	hotspot-page phones <file>     moves the MACs in the file, 10 every 2 minutes
//	hotspot-page pilot <IP>        tries blocking the apps by address on one device, for an hour
//	hotspot-page pilotstatus       shows the trial's rules and their counters
//	hotspot-page unpilot           ends the trial now
//
// A phone is moved by renaming its hotspot user to p-<MAC>: login by MAC no longer
// finds it, so the page shows, and the page's button logs in with that name. Other
// devices are not touched, and a device with no user still cannot get in.
package main

import (
	"context"
	"fmt"
	"os"
	"strconv"
	"strings"
	"time"

	"github.com/google/uuid"
	"github.com/hospital/nms-backend/internal/config"
	"github.com/hospital/nms-backend/internal/database"
	"github.com/hospital/nms-backend/internal/repository"
	"github.com/hospital/nms-backend/pkg/logger"
	"github.com/hospital/nms-backend/pkg/mikrotik"
)

const (
	profile    = "hsprof1"
	newDir     = "hotspot_modern"
	oldDir     = "hotspot"
	newLoginBy = "mac,cookie,http-chap,http-pap,mac-cookie"
	oldLoginBy = "mac,cookie,http-chap"
	newCookie  = "1d"
	oldCookie  = "3d"
	dailyJob   = "hospital-page-daily"
	// Only the phones' p- users: everything else keeps its login.
	dailyScript = `/ip hotspot cookie remove [find where user~"^p-"]; /ip hotspot active remove [find where user~"^p-"]`

	pilotPrefix = "nms-pilot-"
	pilotJob    = "nms-pilot-end"
	pilotScript = `/ip firewall filter remove [find where comment~"^nms-pilot-"]; /ip firewall raw remove [find where comment~"^nms-pilot-"]; /system scheduler remove [find where name="nms-pilot-end"]`

	batchSize       = 10
	batchPause      = 2 * time.Minute
	cpuFull         = 95
	cpuFullReadings = 3
)

// Copied unchanged from the hospital's old folder.
var kept = []string{"error.html", "errors.txt", "redirect.html", "rlogin.html", "radvert.html"}

var pages = []string{"login.html", "alogin.html", "status.html", "logout.html", "logo.png"}

type router struct {
	conn *mikrotik.APIConnection
}

func connect() (*router, error) {
	cfg, err := config.Load(0)
	if err != nil {
		return nil, err
	}
	logger.Init("error", "json")
	db, err := database.NewPostgresDB(cfg)
	if err != nil {
		return nil, err
	}
	defer db.Close()
	ctx, cancel := context.WithTimeout(context.Background(), 20*time.Second)
	defer cancel()
	v, err := repository.NewInternetRepository(db).GetActiveMikroTikIntegration(ctx, uuid.MustParse("00000000-0000-0000-0000-000000000001"))
	if err != nil {
		return nil, err
	}
	if v.Username == nil || v.EncryptedPassword == nil {
		return nil, fmt.Errorf("the router login is not saved")
	}
	c, err := mikrotik.NewClientFromEndpoint(v.BaseURL, *v.Username, *v.EncryptedPassword, 15*time.Second)
	if err != nil {
		return nil, err
	}
	conn := mikrotik.NewAPIConnection(c.Host(), c.Port(), c.Username(), c.Password(), 15*time.Second)
	if err := conn.Connect(); err != nil {
		return nil, err
	}
	if err := conn.Login(); err != nil {
		conn.Close()
		return nil, err
	}
	return &router{conn: conn}, nil
}

func (r *router) find(path, key, value string) (map[string]string, error) {
	rows, err := r.conn.Command(path + "/print")
	if err != nil {
		return nil, err
	}
	for _, row := range rows {
		if row[key] == value {
			return row, nil
		}
	}
	return nil, nil
}

// check confirms the folder uploaded in WinBox is complete. The NMS account has no
// FTP right, so it cannot upload the files itself.
func (r *router) check() error {
	rows, err := r.conn.Command("/file/print")
	if err != nil {
		return err
	}
	have := map[string]bool{}
	for _, row := range rows {
		if strings.HasPrefix(row["name"], newDir+"/") {
			have[strings.TrimPrefix(row["name"], newDir+"/")] = true
			fmt.Println(" on router:", row["name"], row["size"])
		}
	}
	for _, name := range append(append([]string(nil), kept...), pages...) {
		if !have[name] {
			return fmt.Errorf("%s is missing from %s on the router", name, newDir)
		}
	}
	fmt.Println("the folder is complete")
	return nil
}

func (r *router) setProfile(dir, loginBy, cookie string) error {
	p, err := r.find("/ip/hotspot/profile", "name", profile)
	if err != nil {
		return err
	}
	if p == nil {
		return fmt.Errorf("hotspot profile %s not found", profile)
	}
	_, err = r.conn.Command("/ip/hotspot/profile/set", "=.id="+p[".id"], "=html-directory="+dir, "=login-by="+loginBy, "=http-cookie-lifetime="+cookie)
	return err
}

func (r *router) status() error {
	p, err := r.find("/ip/hotspot/profile", "name", profile)
	if err != nil {
		return err
	}
	fmt.Println("page folder:", p["html-directory"], " login-by:", p["login-by"], " cookie:", p["http-cookie-lifetime"])
	active, err := r.conn.Command("/ip/hotspot/active/print")
	if err != nil {
		return err
	}
	by := map[string]int{}
	for _, a := range active {
		by[a["login-by"]]++
	}
	hosts, err := r.conn.Command("/ip/hotspot/host/print")
	if err != nil {
		return err
	}
	waiting := 0
	for _, h := range hosts {
		if h["authorized"] != "true" {
			waiting++
		}
	}
	fmt.Println("logged in:", len(active), by, " not logged in:", waiting)
	res, err := r.conn.Command("/system/resource/print")
	if err == nil && len(res) > 0 {
		fmt.Println("cpu:", res[0]["cpu-load"])
	}
	return nil
}

// endSession makes the device log in again.
func (r *router) endSession(mac string) error {
	for _, path := range []string{"/ip/hotspot/active", "/ip/hotspot/cookie", "/ip/hotspot/host"} {
		rows, err := r.conn.Command(path + "/print")
		if err != nil {
			return err
		}
		for _, row := range rows {
			if strings.EqualFold(row["mac-address"], mac) {
				if _, err := r.conn.Command(path+"/remove", "=.id="+row[".id"]); err != nil {
					return err
				}
			}
		}
	}
	return nil
}

// renameUser moves a device's user from one name to the other, keeping everything else.
func (r *router) renameUser(from, to, mac string) error {
	u, err := r.find("/ip/hotspot/user", "name", from)
	if err != nil {
		return err
	}
	if u == nil {
		return fmt.Errorf("no hotspot user named %s", from)
	}
	if u["password"] != "" {
		return fmt.Errorf("user %s has a password; left alone", from)
	}
	if _, err := r.conn.Command("/ip/hotspot/user/set", "=.id="+u[".id"], "=name="+to); err != nil {
		return err
	}
	fmt.Println("user renamed:", from, "->", to, " profile:", u["profile"])
	return r.endSession(mac)
}

// daily makes the page come back for phones each morning: a login renews the cookie,
// so without this a phone used every day would never see the page again.
func (r *router) daily() error {
	if j, err := r.find("/system/scheduler", "name", dailyJob); err != nil {
		return err
	} else if j != nil {
		return fmt.Errorf("%s is already there", dailyJob)
	}
	clock, err := r.conn.Command("/system/clock/print")
	if err != nil {
		return err
	}
	if _, err := r.conn.Command("/system/scheduler/add", "=name="+dailyJob, "=start-date="+clock[0]["date"], "=start-time=06:00:00", "=interval=1d", "=policy=read,write", "=on-event="+dailyScript); err != nil {
		return err
	}
	j, err := r.find("/system/scheduler", "name", dailyJob)
	if err != nil {
		return err
	}
	fmt.Println("router clock:", clock[0]["date"], clock[0]["time"], clock[0]["time-zone-name"])
	fmt.Println("job:", j["name"], "start", j["start-date"], j["start-time"], "interval", j["interval"], "next-run", j["next-run"], "policy", j["policy"], "disabled", j["disabled"])
	fmt.Println("script:", j["on-event"])
	return nil
}

func (r *router) undaily() error {
	j, err := r.find("/system/scheduler", "name", dailyJob)
	if err != nil || j == nil {
		return err
	}
	_, err = r.conn.Command("/system/scheduler/remove", "=.id="+j[".id"])
	return err
}

// list prints what a rollout has to choose from. Passwords are not printed.
func (r *router) list() error {
	for _, t := range []struct{ tag, path, key string }{{"user", "/ip/hotspot/user", "name"}, {"host", "/ip/hotspot/host", "mac-address"}, {"active", "/ip/hotspot/active", "mac-address"}, {"cookie", "/ip/hotspot/cookie", "mac-address"}} {
		rows, err := r.conn.Command(t.path + "/print")
		if err != nil {
			return err
		}
		for _, row := range rows {
			fmt.Printf("%s|%s|%s|%s|%t|%s|%s\n", t.tag, row[t.key], row["profile"], row["address"], row["password"] != "", row["authorized"], row["user"])
		}
	}
	return nil
}

// phones moves the MACs in a file (one per line) a batch at a time, because each
// moved phone asks the router for the page at once. It stops when the CPU stays full;
// running it again carries on, since phones already moved are skipped.
func (r *router) phones(file string) error {
	data, err := os.ReadFile(file)
	if err != nil {
		return err
	}
	macs := strings.Fields(strings.ToUpper(string(data)))
	users, err := r.conn.Command("/ip/hotspot/user/print")
	if err != nil {
		return err
	}
	byName := map[string]map[string]string{}
	for _, u := range users {
		byName[u["name"]] = u
	}
	moved, skipped := 0, 0
	var batch []string
	for i, mac := range macs {
		u := byName[mac]
		if u == nil || u["password"] != "" {
			fmt.Println("skipped:", mac)
			skipped++
		} else {
			if _, err := r.conn.Command("/ip/hotspot/user/set", "=.id="+u[".id"], "=name=p-"+mac); err != nil {
				return err
			}
			batch = append(batch, mac)
			moved++
		}
		if len(batch) < batchSize && i < len(macs)-1 {
			continue
		}
		if len(batch) == 0 {
			continue
		}
		if err := r.endSessions(batch); err != nil {
			return err
		}
		batch = nil
		fmt.Println("moved", moved, "of", len(macs), "skipped", skipped)
		if i < len(macs)-1 {
			if err := r.settle(); err != nil {
				return err
			}
		}
	}
	return nil
}

// endSessions is endSession for many devices, reading each table once.
func (r *router) endSessions(macs []string) error {
	want := map[string]bool{}
	for _, mac := range macs {
		want[mac] = true
	}
	for _, path := range []string{"/ip/hotspot/active", "/ip/hotspot/cookie", "/ip/hotspot/host"} {
		rows, err := r.conn.Command(path + "/print")
		if err != nil {
			return err
		}
		for _, row := range rows {
			if want[strings.ToUpper(row["mac-address"])] {
				if _, err := r.conn.Command(path+"/remove", "=.id="+row[".id"]); err != nil {
					return err
				}
			}
		}
	}
	return nil
}

// settle waits between batches and refuses to go on while the CPU stays full.
func (r *router) settle() error {
	full := 0
	for i := 0; i < int(batchPause/(10*time.Second)); i++ {
		time.Sleep(10 * time.Second)
		res, err := r.conn.Command("/system/resource/print")
		if err != nil {
			return fmt.Errorf("the router stopped answering, stopped here: %w", err)
		}
		fmt.Println(" cpu:", res[0]["cpu-load"])
		if load, _ := strconv.Atoi(res[0]["cpu-load"]); load >= cpuFull {
			full++
		} else {
			full = 0
		}
		if full >= cpuFullReadings {
			return fmt.Errorf("CPU at %d%% or more for %d readings, stopped here", cpuFull, full)
		}
	}
	return nil
}

// pilot tries blocking the apps by address on one device, for an hour. Its entries are
// not named nms-marco-, so a Marco sync leaves them alone, and a job on the router takes
// them away even if this PC is off.
func (r *router) pilot(ip string) error {
	if j, err := r.find("/system/scheduler", "name", pilotJob); err != nil {
		return err
	} else if j != nil {
		return fmt.Errorf("%s is already there; run unpilot first", pilotJob)
	}
	clock, err := r.conn.Command("/system/clock/print")
	if err != nil {
		return err
	}
	now, err := time.Parse("Jan/02/2006 15:04:05", clock[0]["date"]+" "+clock[0]["time"])
	if err != nil {
		return err
	}
	at := now.Add(time.Hour)
	if _, err := r.conn.Command("/system/scheduler/add", "=name="+pilotJob, "=start-date="+strings.ToLower(at.Format("Jan/02/2006")), "=start-time="+at.Format("15:04:05"), "=interval=1h", "=policy=read,write", "=on-event="+pilotScript); err != nil {
		return err
	}
	rules := [][]string{
		{"=comment=" + pilotPrefix + "facebook", "=dst-address-list=collect all  facebook ips"},
		{"=comment=" + pilotPrefix + "instagram", "=dst-address-list=collect all instagram ips"},
		{"=comment=" + pilotPrefix + "tiktok", "=dst-address=71.18.0.0/16"},
	}
	first, err := r.conn.Command("/ip/firewall/filter/print")
	if err != nil {
		return err
	}
	for _, rule := range rules {
		args := append([]string{"=chain=forward", "=action=drop", "=src-address=" + ip}, rule...)
		for _, row := range first {
			if row["dynamic"] != "true" {
				args = append(args, "=place-before="+row[".id"])
				break
			}
		}
		if _, err := r.conn.Command("/ip/firewall/filter/add", args...); err != nil {
			return err
		}
	}
	for _, word := range []string{"snssdk", "pstatp", "muscdn"} {
		if _, err := r.conn.Command("/ip/firewall/raw/add", "=chain=prerouting", "=action=drop", "=src-address="+ip, "=protocol=udp", "=dst-port=53", "=content="+word, "=comment="+pilotPrefix+"dns-"+word); err != nil {
			return err
		}
	}
	fmt.Println("pilot on for", ip, "until", at.Format("15:04:05"))
	return r.pilotStatus()
}

func (r *router) pilotStatus() error {
	for _, path := range []string{"/ip/firewall/filter", "/ip/firewall/raw"} {
		rows, err := r.conn.Command(path + "/print")
		if err != nil {
			return err
		}
		for i, row := range rows {
			if strings.HasPrefix(row["comment"], pilotPrefix) {
				fmt.Println(path, "position", i, row["comment"], "packets", row["packets"], "src", row["src-address"])
			}
		}
	}
	res, err := r.conn.Command("/system/resource/print")
	if err == nil && len(res) > 0 {
		fmt.Println("cpu:", res[0]["cpu-load"])
	}
	return nil
}

func (r *router) unpilot() error {
	for _, path := range []string{"/ip/firewall/filter", "/ip/firewall/raw"} {
		rows, err := r.conn.Command(path + "/print")
		if err != nil {
			return err
		}
		for _, row := range rows {
			if strings.HasPrefix(row["comment"], pilotPrefix) {
				if _, err := r.conn.Command(path+"/remove", "=.id="+row[".id"]); err != nil {
					return err
				}
			}
		}
	}
	j, err := r.find("/system/scheduler", "name", pilotJob)
	if err != nil || j == nil {
		return err
	}
	_, err = r.conn.Command("/system/scheduler/remove", "=.id="+j[".id"])
	return err
}

func main() {
	if len(os.Args) < 2 {
		fmt.Println("usage: hotspot-page status|check|enable|disable|phone <MAC>|unphone <MAC>|daily|undaily")
		os.Exit(2)
	}
	r, err := connect()
	if err == nil {
		defer r.conn.Close()
		mac := ""
		if len(os.Args) > 2 {
			mac = strings.ToUpper(os.Args[2])
		}
		switch os.Args[1] {
		case "status":
			err = r.status()
		case "check":
			err = r.check()
		case "enable":
			if err = r.check(); err != nil {
				break
			}
			if err = r.setProfile(newDir, newLoginBy, newCookie); err == nil {
				err = r.status()
			}
		case "disable":
			if err = r.setProfile(oldDir, oldLoginBy, oldCookie); err == nil {
				err = r.status()
			}
		case "phone":
			err = r.renameUser(mac, "p-"+mac, mac)
		case "again":
			err = r.endSession(mac)
		case "daily":
			err = r.daily()
		case "undaily":
			err = r.undaily()
		case "list":
			err = r.list()
		case "phones":
			err = r.phones(os.Args[2])
		case "pilot":
			err = r.pilot(os.Args[2])
		case "pilotstatus":
			err = r.pilotStatus()
		case "unpilot":
			err = r.unpilot()
		case "unphone":
			err = r.renameUser("p-"+mac, mac, mac)
		default:
			err = fmt.Errorf("unknown command %s", os.Args[1])
		}
	}
	if err != nil {
		fmt.Println("ERROR:", err)
		os.Exit(1)
	}
}

// marco-remove is the emergency tool for when an NMS change hurts the router. It
// stops the NMS server so the rules cannot come back, turns router writes off in
// .env, and deletes every router entry named "nms-marco-". Nothing without that
// prefix is touched. It keeps retrying because a struggling router answers only now
// and then, and prints each entry it removes.
//
// Keep the exe in the backend folder, next to .env. With --check it only reports
// what is on the router and changes nothing.
package main

import (
	"bufio"
	"context"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"regexp"
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
	prefix      = "nms-marco-"
	giveUpAfter = 5 * time.Minute
	routerWait  = 8 * time.Second
)

type router interface {
	Command(string, ...string) ([]map[string]string, error)
	Close() error
}

type login struct {
	host           string
	port           int
	username, pass string
}

// Rules go first, then what they point to.
var paths = []string{"/ip/firewall/filter", "/queue/simple", "/ip/firewall/address-list", "/ip/firewall/layer7-protocol", "/system/scheduler"}

var input = bufio.NewReader(os.Stdin)

func main() {
	code := run()
	fmt.Print("\nPress Enter to close.")
	input.ReadString('\n')
	os.Exit(code)
}

func run() int {
	checkOnly := len(os.Args) > 1 && os.Args[1] == "--check"
	dir := "."
	if exe, err := os.Executable(); err == nil {
		dir = filepath.Dir(exe)
		_ = os.Chdir(dir) // .env is read from the current folder
	}

	fmt.Println("=== NMS emergency tool ===")
	if checkOnly {
		fmt.Println("Check only: nothing will be changed.")
	} else {
		fmt.Println("This will:")
		fmt.Println("  1. stop the NMS server")
		fmt.Println("  2. set ROUTER_POLICY_WRITES=false in .env")
		fmt.Println("  3. delete every router entry named nms-marco- (all group blocks and limits)")
		fmt.Println("Your own router rules are not touched.")
		fmt.Print("\nType YES and press Enter to continue: ")
		answer, _ := input.ReadString('\n')
		if strings.TrimSpace(strings.ToUpper(answer)) != "YES" {
			fmt.Println("Nothing was changed.")
			return 0
		}
		fmt.Println()
		stopServer(dir)
		if err := writesOff(filepath.Join(dir, ".env")); err != nil {
			fmt.Println("WARNING: could not change .env:", err)
			fmt.Println("Set ROUTER_POLICY_WRITES=false yourself before starting the server.")
		} else {
			fmt.Println("Router writes are off in .env.")
		}
	}

	who := findLogin()
	dial := func() (router, error) {
		conn := mikrotik.NewAPIConnection(who.host, who.port, who.username, who.pass, routerWait)
		if err := conn.Connect(); err != nil {
			return nil, err
		}
		if err := conn.Login(); err != nil {
			conn.Close()
			return nil, err
		}
		return conn, nil
	}

	fmt.Printf("Connecting to the router at %s:%d ...\n", who.host, who.port)
	total := 0
	deadline := time.Now().Add(giveUpAfter)
	for {
		if time.Now().After(deadline) {
			fmt.Printf("\nGAVE UP after %s: the router is not answering. Removed %d entries so far.\n", giveUpAfter, total)
			fmt.Println("Open WinBox by MAC address and use the commands in docs/ROUTER_SAFETY.md.")
			return 1
		}
		conn, err := dial()
		if err != nil {
			fmt.Printf("%s no answer, trying again: %v\n", time.Now().Format("15:04:05"), err)
			time.Sleep(2 * time.Second)
			continue
		}
		if checkOnly {
			err := check(conn)
			if err == nil {
				report(conn)
				conn.Close()
				return 0
			}
			fmt.Println("connection lost, trying again:", err)
			conn.Close()
			continue
		}
		removed, err := sweep(conn)
		total += removed
		if err != nil {
			fmt.Println("connection lost, trying again:", err)
			conn.Close()
			continue
		}
		if removed == 0 { // a clean pass: nothing was left to remove
			fmt.Printf("\nDONE: removed %d entries, none left.\n\n", total)
			report(conn)
			conn.Close()
			return 0
		}
		conn.Close()
	}
}

// isManaged reports whether an entry is one the NMS created.
func isManaged(r map[string]string) bool {
	return strings.HasPrefix(r["comment"], prefix) || strings.HasPrefix(r["name"], prefix)
}

func sweep(conn router) (int, error) {
	removed := 0
	for _, path := range paths {
		rows, err := conn.Command(path + "/print")
		if err != nil {
			return removed, err
		}
		for _, r := range rows {
			if !isManaged(r) {
				continue
			}
			if _, err := conn.Command(path+"/remove", "=.id="+r[".id"]); err != nil {
				return removed, fmt.Errorf("remove %s %q: %w", path, r["comment"], err)
			}
			removed++
			fmt.Printf("removed %s %s\n", path, show(r, "comment", "name", "chain", "action", "src-address-list", "dst-address-list", "protocol", "dst-port", "layer7-protocol", "list", "address", "target", "max-limit", "disabled"))
		}
	}
	return removed, nil
}

// check counts the entries a removal would take. Print commands only.
func check(conn router) error {
	fmt.Println()
	for _, path := range paths {
		rows, err := conn.Command(path + "/print")
		if err != nil {
			return err
		}
		found, active := 0, 0
		for _, r := range rows {
			if !isManaged(r) {
				continue
			}
			found++
			if r["disabled"] != "true" {
				active++
			}
		}
		fmt.Printf("%-32s %d nms-marco entries, %d switched on\n", path, found, active)
	}
	fmt.Println()
	return nil
}

// report prints what the router looks like. Print commands only.
func report(conn router) {
	if rows, err := conn.Command("/system/resource/print"); err == nil {
		for _, r := range rows {
			fmt.Println("router:", show(r, "uptime", "cpu-load", "free-memory", "total-memory"))
		}
	}
	if rows, err := conn.Command("/ip/route/print"); err == nil {
		for _, r := range rows {
			if r["dst-address"] == "0.0.0.0/0" {
				fmt.Println("default route:", show(r, "gateway", "active", "disabled"))
			}
		}
	}
}

func show(r map[string]string, keys ...string) string {
	var b strings.Builder
	for _, k := range keys {
		if v := r[k]; v != "" {
			b.WriteString(" " + k + "=" + v)
		}
	}
	return b.String()
}

// stopServer stops NMS programs running from this folder, and nothing else.
func stopServer(dir string) {
	folder := strings.ReplaceAll(dir, "'", "''")
	script := fmt.Sprintf(`$p = Get-Process | Where-Object { $_.Id -ne %d -and $_.Path -like '%s\*' }; $p | Stop-Process -Force; @($p).Count`, os.Getpid(), folder)
	out, err := exec.Command("powershell", "-NoProfile", "-NonInteractive", "-Command", script).CombinedOutput()
	if err != nil {
		fmt.Println("WARNING: could not stop the NMS server, stop it yourself:", err)
		return
	}
	fmt.Printf("NMS programs stopped: %s\n", strings.TrimSpace(string(out)))
}

var writesLine = regexp.MustCompile(`(?m)^ROUTER_POLICY_WRITES=[^\r\n]*`)

// writesOff sets ROUTER_POLICY_WRITES=false, leaving the rest of the file as it is.
func writesOff(file string) error {
	data, err := os.ReadFile(file)
	if err != nil {
		return err
	}
	var out []byte
	if writesLine.Match(data) {
		out = writesLine.ReplaceAll(data, []byte("ROUTER_POLICY_WRITES=false"))
	} else {
		out = append(append(append([]byte(nil), data...), '\n'), []byte("ROUTER_POLICY_WRITES=false\n")...)
	}
	if string(out) == string(data) {
		return nil
	}
	return os.WriteFile(file, out, 0o600)
}

// findLogin takes the router's login from the NMS database. If the database is not
// running it asks, and keeps what is typed only until the program closes.
func findLogin() login {
	result := make(chan *login, 1)
	go func() { result <- loginFromDatabase() }()
	select {
	case who := <-result:
		if who != nil {
			return *who
		}
	case <-time.After(20 * time.Second):
	}
	fmt.Println("\nThe NMS database is not answering, so type the router's login.")
	fmt.Print("Router address [172.16.0.1]: ")
	host, _ := input.ReadString('\n')
	host = strings.TrimSpace(host)
	if host == "" {
		host = "172.16.0.1"
	}
	fmt.Print("User: ")
	user, _ := input.ReadString('\n')
	fmt.Print("Password (shown as you type): ")
	pass, _ := input.ReadString('\n')
	return login{host: host, port: 8728, username: strings.TrimSpace(user), pass: strings.TrimRight(pass, "\r\n")}
}

func loginFromDatabase() *login {
	cfg, err := config.Load(0)
	if err != nil {
		return nil
	}
	logger.Init("error", "json")
	db, err := database.NewPostgresDB(cfg)
	if err != nil {
		return nil
	}
	defer db.Close()
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()
	org := uuid.MustParse("00000000-0000-0000-0000-000000000001")
	vendor, err := repository.NewInternetRepository(db).GetActiveMikroTikIntegration(ctx, org)
	if err != nil {
		return nil
	}
	username, password := "admin", ""
	if vendor.Username != nil {
		username = *vendor.Username
	}
	if vendor.EncryptedPassword != nil {
		password = *vendor.EncryptedPassword
	}
	client, err := mikrotik.NewClientFromEndpoint(vendor.BaseURL, username, password, routerWait)
	if err != nil {
		return nil
	}
	return &login{host: client.Host(), port: client.Port(), username: client.Username(), pass: client.Password()}
}

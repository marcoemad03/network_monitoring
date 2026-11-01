// Command inspect reads the state of the router without changing anything.
//
// It only ever issues "/print" commands (anything else is refused in readOnly),
// takes the credentials from the environment so they never touch disk, and
// prints a short report: RouterOS version, and every NMS-managed or
// router-wide entry that could have affected traffic.
//
//	MT_USER=... MT_PASS=... go run ./cmd/inspect
package main

import (
	"fmt"
	"os"
	"strconv"
	"strings"
	"time"

	"github.com/hospital/nms-backend/pkg/mikrotik"
)

func getenv(key, fallback string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return fallback
}

type reader struct{ conn *mikrotik.APIConnection }

// readOnly is the only way this tool talks to the router.
func (r reader) readOnly(cmd string, attrs ...string) ([]map[string]string, error) {
	if !strings.HasSuffix(cmd, "/print") {
		return nil, fmt.Errorf("refused non-read command %q", cmd)
	}
	return r.conn.Command(cmd, attrs...)
}

func (r reader) show(title, cmd string, props []string, keep func(map[string]string) bool) {
	rows, err := r.readOnly(cmd, "=.proplist=.id,"+strings.Join(props, ","))
	fmt.Printf("\n== %s (%s)\n", title, cmd)
	if err != nil {
		fmt.Println("  error:", err)
		return
	}
	n := 0
	for _, row := range rows {
		if keep != nil && !keep(row) {
			continue
		}
		n++
		var parts []string
		for _, p := range props {
			if v := row[p]; v != "" {
				parts = append(parts, p+"="+v)
			}
		}
		fmt.Println("  -", strings.Join(parts, " "))
	}
	fmt.Printf("  total=%d shown=%d\n", len(rows), n)
}

func main() {
	user, pass := os.Getenv("MT_USER"), os.Getenv("MT_PASS")
	if user == "" || pass == "" {
		fmt.Println("set MT_USER and MT_PASS (optional: MT_HOST, MT_PORT)")
		os.Exit(2)
	}
	port, _ := strconv.Atoi(getenv("MT_PORT", "8728"))
	conn := mikrotik.NewAPIConnection(getenv("MT_HOST", "172.16.0.1"), port, user, pass, 10*time.Second)
	if err := conn.Connect(); err != nil {
		fmt.Println("connect error:", err)
		os.Exit(1)
	}
	defer conn.Close()
	if err := conn.Login(); err != nil {
		fmt.Println("login error:", err)
		os.Exit(1)
	}
	r := reader{conn}

	managed := func(row map[string]string) bool { return strings.HasPrefix(row["comment"], "nms-") }

	rows, err := r.readOnly("/system/resource/print")
	if err != nil {
		fmt.Println("resource error:", err)
	} else if len(rows) > 0 {
		x := rows[0]
		fmt.Printf("RouterOS %s | board=%s | arch=%s | uptime=%s | cpu-load=%s%% | free-mem=%s/%s\n",
			x["version"], x["board-name"], x["architecture-name"], x["uptime"], x["cpu-load"], x["free-memory"], x["total-memory"])
	}
	r.show("identity", "/system/identity/print", []string{"name"}, nil)

	r.show("NMS firewall filter rules", "/ip/firewall/filter/print",
		[]string{"chain", "action", "src-address", "src-mac-address", "layer7-protocol", "disabled", "comment"}, managed)
	r.show("ALL drop/reject filter rules (anything that can cut traffic)", "/ip/firewall/filter/print",
		[]string{"chain", "action", "src-address", "dst-address", "src-mac-address", "layer7-protocol", "disabled", "comment"},
		func(row map[string]string) bool { return row["action"] == "drop" || row["action"] == "reject" })
	r.show("NMS simple queues", "/queue/simple/print",
		[]string{"name", "target", "max-limit", "disabled", "comment"}, managed)
	r.show("NMS address-lists", "/ip/firewall/address-list/print",
		[]string{"list", "address", "disabled", "comment"}, managed)
	r.show("NMS layer7 protocols", "/ip/firewall/layer7-protocol/print",
		[]string{"name", "comment"}, managed)
	r.show("static DNS entries", "/ip/dns/static/print",
		[]string{"name", "address", "disabled", "comment"}, nil)
	r.show("scheduler", "/system/scheduler/print",
		[]string{"name", "start-time", "interval", "disabled", "comment"}, nil)
}

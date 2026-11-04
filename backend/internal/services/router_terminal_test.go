package services

import (
	"context"
	"strings"
	"testing"
)

func terminalRouter() *rowRouter {
	return &rowRouter{rows: map[string][]map[string]string{
		"/ip/firewall/filter": {
			{".id": "*1", "comment": "nms-marco-aaaaaaaa-sites", "chain": "forward"},
			{".id": "*2", "comment": "Dr.Hany Excep Mob (Youtube)", "chain": "forward"},
			{".id": "*3", "chain": "forward", "dynamic": "true", "comment": "nms-marco-dynamic"},
		},
		"/queue/simple":                {{".id": "*4", "comment": "nms-marco-q-x", "name": "nms-marco-q-x"}, {".id": "*5", "name": "Manager"}},
		"/ip/firewall/address-list":    {{".id": "*6", "comment": "nms-marco-src-x", "list": "s"}, {".id": "*7", "list": "collect all youtube ips"}},
		"/ip/firewall/layer7-protocol": {{".id": "*8", "name": "nms-marco-l7-youtube"}, {".id": "*9", "name": "BlockYoutube"}},
		"/system/scheduler":            {{".id": "*A", "name": "nms-marco-deadman"}, {".id": "*B", "name": "backup"}},
	}}
}

const emergencyLines = `/ip firewall filter remove [find where comment~"^nms-marco-"]
/queue simple remove [find where comment~"^nms-marco-"]
/ip firewall address-list remove [find where comment~"^nms-marco-"]
/ip firewall layer7-protocol remove [find where name~"^nms-marco-"]
/system scheduler remove [find where name="nms-marco-deadman"]`

func removedIDs(f *rowRouter) string {
	var ids []string
	for _, c := range f.commands {
		if strings.HasSuffix(c.path, "/remove") {
			ids = append(ids, strings.TrimPrefix(c.attrs[0], "=.id="))
		}
	}
	return strings.Join(ids, ",")
}

func TestTerminalRunsTheEmergencyCommands(t *testing.T) {
	f := terminalRouter()
	res := runTerminal(f, emergencyLines, false)
	if !res.NeedsConfirm || len(res.Lines) != 5 {
		t.Fatalf("preview = %+v", res)
	}
	if removedIDs(f) != "" {
		t.Fatalf("nothing may change before the person confirms: %s", removedIDs(f))
	}
	if n := res.Lines[0].Names; len(n) != 1 || n[0] != "nms-marco-aaaaaaaa-sites" {
		t.Errorf("the preview must say what would go: %v", n)
	}

	res = runTerminal(f, emergencyLines, true)
	if got := removedIDs(f); got != "*1,*4,*6,*8,*A" {
		t.Errorf("removed %s, want only the NMS's own entries", got)
	}
	for _, l := range res.Lines {
		if l.Error != "" || l.Changed != 1 {
			t.Errorf("%+v", l)
		}
	}
}

func TestTerminalPrint(t *testing.T) {
	f := terminalRouter()
	res := runTerminal(f, "/ip firewall filter print where chain=forward\n# a note\n\n/ip/firewall/layer7-protocol/print", false)
	if res.NeedsConfirm || len(res.Lines) != 2 || res.Lines[0].Matched != 3 || res.Lines[1].Matched != 2 {
		t.Fatalf("%+v", res)
	}
	if len(f.commands) != 2 {
		t.Errorf("a print must only read: %v", f.commands)
	}
}

func TestTerminalRefuses(t *testing.T) {
	for line, why := range map[string]string{
		"/ip firewall filter remove":                             "find",
		"/ip firewall filter remove [find]":                      "find",
		"/ip firewall filter add chain=forward action=drop":      "only print",
		"/system reboot":                                         "only print",
		"/system reset-configuration":                            "only print",
		"/user remove [find where name=admin]":                   "cannot be changed",
		"/user print":                                            "cannot be read",
		"/ip hotspot user print":                                 "cannot be read",
		"/ppp secret print":                                      "cannot be read",
		"/interface disable [find where name=ether2]":            "cannot be changed",
		"/ip route remove [find where dst-address=0.0.0.0/0]":    "cannot be changed",
		"/system scheduler disable [find where name=backup]":     "only be removed",
		`/ip firewall filter remove [find where comment~"^nms-]`: "quote",
		`/ip firewall filter remove [find where comment~"(("]`:   "bad pattern",
		"ip firewall filter print":                               "starts with /",
	} {
		f := terminalRouter()
		res := runTerminal(f, line, true)
		if len(res.Lines) != 1 || !strings.Contains(res.Lines[0].Error, why) {
			t.Errorf("%s: %+v", line, res.Lines)
		}
		if len(f.commands) != 0 {
			t.Errorf("%s reached the router: %v", line, f.commands)
		}
	}
}

func TestTerminalStopsAtTheFirstBadLine(t *testing.T) {
	f := terminalRouter()
	res := runTerminal(f, "/system reboot\n"+`/ip firewall filter remove [find where comment~"^nms-marco-"]`, true)
	if len(res.Lines) != 1 || removedIDs(f) != "" {
		t.Errorf("%+v, removed %s", res, removedIDs(f))
	}
}

func TestTerminalWithWritesOffChangesNothing(t *testing.T) {
	f := terminalRouter()
	sess := newRouterSession(context.Background(), f, false, nil)
	runTerminal(sess, emergencyLines, true)
	if removedIDs(f) != "" {
		t.Errorf("writes are off, yet: %s", removedIDs(f))
	}
	if len(sess.Planned()) != 5 {
		t.Errorf("planned = %v", sess.Planned())
	}
}

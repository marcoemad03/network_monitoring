package main

import (
	"errors"
	"os"
	"path/filepath"
	"strings"
	"testing"
)

type fakeRouter struct {
	rows    map[string][]map[string]string
	calls   []string
	failOn  string
	removed map[string][]string
}

func (f *fakeRouter) Command(path string, attrs ...string) ([]map[string]string, error) {
	f.calls = append(f.calls, path+" "+strings.Join(attrs, " "))
	if f.failOn != "" && strings.HasPrefix(path, f.failOn) {
		return nil, errors.New("i/o timeout")
	}
	if strings.HasSuffix(path, "/print") {
		table := strings.TrimSuffix(path, "/print")
		var keep []map[string]string
		for _, r := range f.rows[table] {
			if !contains(f.removed[table], r[".id"]) {
				keep = append(keep, r)
			}
		}
		return keep, nil
	}
	if strings.HasSuffix(path, "/remove") {
		table := strings.TrimSuffix(path, "/remove")
		if f.removed == nil {
			f.removed = map[string][]string{}
		}
		f.removed[table] = append(f.removed[table], strings.TrimPrefix(attrs[0], "=.id="))
	}
	return nil, nil
}
func (f *fakeRouter) Close() error { return nil }

func contains(list []string, s string) bool {
	for _, v := range list {
		if v == s {
			return true
		}
	}
	return false
}

func hospitalRouter() *fakeRouter {
	return &fakeRouter{rows: map[string][]map[string]string{
		"/ip/firewall/filter": {
			{".id": "*1", "comment": "nms-marco-a3ed7430-l7-youtube", "disabled": "false"},
			{".id": "*2", "comment": "Dr.Hany Excep Mob (Youtube)", "disabled": "false"},
			{".id": "*3", "comment": "collect youtube ip adrress"},
			{".id": "*4", "disabled": "false"},
		},
		"/queue/simple":             {{".id": "*5", "name": "nms-marco-q-dev-aa", "comment": "nms-marco-q-dev-aa"}, {".id": "*6", "name": "Manager"}},
		"/ip/firewall/address-list": {{".id": "*7", "comment": "nms-marco-src-a3ed7430-x", "list": "nms-marco-src-a3ed7430"}, {".id": "*8", "list": "collect all youtube ips"}},
		"/ip/firewall/layer7-protocol": {
			{".id": "*9", "name": "nms-marco-l7-youtube", "comment": "nms-marco-l7-youtube"},
			{".id": "*A", "name": "BlockYoutube", "comment": "BlockYoutube"},
		},
		"/system/scheduler": {{".id": "*B", "name": "nms-marco-deadman"}, {".id": "*C", "name": "backup"}},
	}}
}

func TestSweepRemovesOnlyNmsMarcoEntries(t *testing.T) {
	f := hospitalRouter()
	n, err := sweep(f)
	if err != nil || n != 5 {
		t.Fatalf("removed %d, err %v", n, err)
	}
	want := map[string][]string{
		"/ip/firewall/filter":          {"*1"},
		"/queue/simple":                {"*5"},
		"/ip/firewall/address-list":    {"*7"},
		"/ip/firewall/layer7-protocol": {"*9"},
		"/system/scheduler":            {"*B"},
	}
	for table, ids := range want {
		if strings.Join(f.removed[table], ",") != strings.Join(ids, ",") {
			t.Errorf("%s: removed %v, want %v", table, f.removed[table], ids)
		}
	}
	// The second pass is how the tool knows it is finished.
	if n, err := sweep(f); err != nil || n != 0 {
		t.Errorf("second pass removed %d, err %v", n, err)
	}
}

func TestSweepRemovesRulesBeforeWhatTheyPointTo(t *testing.T) {
	f := hospitalRouter()
	if _, err := sweep(f); err != nil {
		t.Fatal(err)
	}
	var order []string
	for _, c := range f.calls {
		if strings.Contains(c, "/remove") {
			order = append(order, strings.Fields(c)[0])
		}
	}
	if order[0] != "/ip/firewall/filter/remove" {
		t.Errorf("rules must go first: %v", order)
	}
}

func TestSweepReportsALostConnectionAndCountsWhatItDid(t *testing.T) {
	f := hospitalRouter()
	f.failOn = "/ip/firewall/address-list"
	n, err := sweep(f)
	if err == nil || n != 2 {
		t.Errorf("removed %d, err %v", n, err)
	}
}

func TestCheckChangesNothing(t *testing.T) {
	f := hospitalRouter()
	if err := check(f); err != nil {
		t.Fatal(err)
	}
	report(f)
	for _, c := range f.calls {
		if !strings.Contains(c, "/print") {
			t.Errorf("check sent a change: %s", c)
		}
	}
}

func TestWritesOff(t *testing.T) {
	cases := []struct{ name, before, after string }{
		{"on", "A=1\nROUTER_POLICY_WRITES=true\nB=2\n", "A=1\nROUTER_POLICY_WRITES=false\nB=2\n"},
		{"windows line ends", "A=1\r\nROUTER_POLICY_WRITES=true\r\nB=2\r\n", "A=1\r\nROUTER_POLICY_WRITES=false\r\nB=2\r\n"},
		{"already off", "ROUTER_POLICY_WRITES=false\n", "ROUTER_POLICY_WRITES=false\n"},
		{"missing", "A=1", "A=1\nROUTER_POLICY_WRITES=false\n"},
		{"similar name kept", "X_ROUTER_POLICY_WRITES=true\nROUTER_POLICY_WRITES=true\n", "X_ROUTER_POLICY_WRITES=true\nROUTER_POLICY_WRITES=false\n"},
	}
	for _, c := range cases {
		file := filepath.Join(t.TempDir(), ".env")
		if err := os.WriteFile(file, []byte(c.before), 0o600); err != nil {
			t.Fatal(err)
		}
		if err := writesOff(file); err != nil {
			t.Fatalf("%s: %v", c.name, err)
		}
		got, _ := os.ReadFile(file)
		if string(got) != c.after {
			t.Errorf("%s: got %q, want %q", c.name, got, c.after)
		}
	}
}

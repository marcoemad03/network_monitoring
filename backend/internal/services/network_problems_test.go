package services

import "testing"

func problemFixture() problemTables {
	return problemTables{
		addresses: []map[string]string{{"address": "172.16.0.1/24", "interface": "ether5"}},
		pools:     []map[string]string{{"name": "hs-pool-6", "ranges": "172.16.0.71-172.16.0.254"}},
		dhcp:      []map[string]string{{"name": "dhcp1", "address-pool": "hs-pool-6"}},
		hosts: []map[string]string{
			// A computer with a manual address, and a phone that got the same one.
			{"mac-address": "40:A8:F0:49:76:F4", "address": "172.16.0.125", "to-address": "172.16.0.125", "authorized": "true", "idle-time": "2s", "uptime": "1h", "bytes-in": "900000", "bytes-out": "9000000"},
			{"mac-address": "6E:6B:16:86:66:65", "address": "172.16.0.125", "to-address": "172.16.0.125", "authorized": "false", "idle-time": "5s"},
			// Logged in, sends, gets nothing back.
			{"mac-address": "AA:00:00:00:00:01", "address": "172.16.0.90", "authorized": "true", "idle-time": "1s", "uptime": "20m", "bytes-in": "500000", "bytes-out": "2000"},
			// A manual address from another network.
			{"mac-address": "AA:00:00:00:00:02", "address": "192.168.1.20", "authorized": "false", "idle-time": "1s"},
		},
		leases: []map[string]string{
			{"mac-address": "6E:6B:16:86:66:65", "address": "172.16.0.125", "status": "bound", "dynamic": "true"},
			{"mac-address": "AA:00:00:00:00:01", "address": "172.16.0.90", "status": "bound", "dynamic": "true"},
			{"mac-address": "AA:00:00:00:00:09", "address": "172.16.0.140", "status": "waiting", "dynamic": "false"},
		},
		arps: []map[string]string{
			{"mac-address": "AA:00:00:00:00:03", "address": "172.16.0.140", "complete": "true"},
			{"mac-address": "AA:00:00:00:00:04", "address": "172.16.0.200", "complete": "true"},
		},
		nmsDrops: map[string]string{"172.16.0.200": ""},
	}
}

func TestFindNetworkProblems(t *testing.T) {
	issues, seen := findNetworkProblems(problemFixture(), map[string]ClientView{"40:A8:F0:49:76:F4": {DisplayName: "HP PC"}})
	if seen != 6 {
		t.Errorf("devices seen = %d, want 6", seen)
	}
	got := map[string]NetworkIssue{}
	for _, i := range issues {
		if _, dup := got[i.Kind+i.Address]; dup {
			t.Errorf("duplicate issue %s %s", i.Kind, i.Address)
		}
		got[i.Kind+i.Address] = i
	}
	c, ok := got[IssueIPConflict+"172.16.0.125"]
	if !ok || len(c.Devices) != 2 || c.Severity != "error" {
		t.Fatalf("conflict on .125 not found: %+v", issues)
	}
	if c.Devices[0].Name != "HP PC" && c.Devices[1].Name != "HP PC" {
		t.Errorf("device name missing: %+v", c.Devices)
	}
	for _, want := range []string{
		IssueReservedTaken + "172.16.0.140",
		IssueNoReply + "172.16.0.90",
		IssueWrongNetwork + "192.168.1.20",
		IssueStaticInPool + "172.16.0.200",
		IssueNMSBlocked,
		IssueNotLoggedIn,
	} {
		if _, ok := got[want]; !ok {
			t.Errorf("missing %s", want)
		}
	}
	if _, ok := got[IssueStaticInPool+"172.16.0.125"]; ok {
		t.Error("a conflict address is also reported as a manual address")
	}
	if issues[0].Severity != "error" || issues[len(issues)-1].Severity != "warning" && issues[len(issues)-1].Severity != "info" {
		t.Errorf("not sorted by severity")
	}
}

func TestParsePoolRanges(t *testing.T) {
	r := parsePoolRanges("172.16.0.71-172.16.0.254, 10.0.0.0/30")
	if len(r) != 2 || r[1].to.String() != "10.0.0.3" {
		t.Fatalf("got %+v", r)
	}
}

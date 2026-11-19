package services

import (
	"net"
	"testing"
)

func TestMemberAddressFollowsMAC(t *testing.T) {
	const me, other = "AA:AA:AA:AA:AA:01", "BB:BB:BB:BB:BB:02"
	saved := net.ParseIP("172.16.0.125")
	cases := []struct {
		name    string
		live    map[string]string
		holders map[string][]string
		want    string
	}{
		{"router not read yet keeps the saved address", nil, nil, "172.16.0.125"},
		{"online on a new address", map[string]string{me: "172.16.0.90"}, nil, "172.16.0.90"},
		{"away and nobody else on the address", map[string]string{}, map[string][]string{"172.16.0.125": {me}}, "172.16.0.125"},
		{"away and another device took the address", map[string]string{other: "172.16.0.125"}, map[string][]string{"172.16.0.125": {other}}, ""},
		{"away and the address is reserved for another device", map[string]string{}, map[string][]string{"172.16.0.125": {me, other}}, ""},
	}
	for _, c := range cases {
		got := memberAddress(me, saved, c.live, c.holders)
		if (got == nil && c.want != "") || (got != nil && got.String() != c.want) {
			t.Errorf("%s: got %v, want %q", c.name, got, c.want)
		}
	}
	if got := memberAddress(me, nil, map[string]string{}, nil); got != nil {
		t.Errorf("away with no saved address: got %v", got)
	}
}

func TestMergeClientTablesKeepsEveryAddress(t *testing.T) {
	out := mergeClientTables(
		[]map[string]string{{"mac-address": "aa:aa:aa:aa:aa:01", "address": "172.16.0.125", "idle-time": "1s"}},
		[]map[string]string{{"mac-address": "AA:AA:AA:AA:AA:01", "address": "172.16.0.80", "status": "waiting"}},
		nil,
	)
	if len(out) != 1 || len(out[0].Addresses) != 2 {
		t.Fatalf("got %+v", out)
	}
}

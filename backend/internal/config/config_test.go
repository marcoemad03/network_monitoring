package config

import "testing"

func TestParseKeyValueListKeepsSpacesInValues(t *testing.T) {
	got := parseKeyValueList("YouTube=collect all youtube ips; facebook = collect all  facebook ips ;broken;=x;y=")
	if got["youtube"] != "collect all youtube ips" {
		t.Fatalf("youtube = %q", got["youtube"])
	}
	if got["facebook"] != "collect all  facebook ips" {
		t.Fatalf("facebook = %q", got["facebook"])
	}
	if len(got) != 2 {
		t.Fatalf("malformed entries must be ignored: %v", got)
	}
}

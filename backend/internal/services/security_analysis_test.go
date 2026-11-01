package services

import (
	"fmt"
	"testing"
)

func TestParseFlowsReadsTheConnectionTable(t *testing.T) {
	flows := parseFlows([]map[string]string{
		{"protocol": "tcp", "src-address": "172.16.0.197:41506", "dst-address": "35.244.195.33:443", "orig-bytes": "681", "repl-bytes": "12464"},
		{"protocol": "udp", "src-address": "172.16.0.129:46932", "dst-address": "172.217.114.4:443", "orig-bytes": "6053", "repl-bytes": "5308"},
		{"protocol": "icmp", "src-address": "172.16.0.9", "dst-address": "8.8.8.8", "orig-bytes": "84", "repl-bytes": "84"},
		{"protocol": "tcp", "src-address": "", "dst-address": "1.2.3.4:80"},        // no source
		{"protocol": "tcp", "src-address": "garbage", "dst-address": "1.2.3.4:80"}, // not an address
	})
	if len(flows) != 3 {
		t.Fatalf("got %d flows, want 3: %+v", len(flows), flows)
	}
	f := flows[0]
	if f.SrcIP != "172.16.0.197" || f.DstIP != "35.244.195.33" || f.DstPort != 443 || f.Up != 681 || f.Down != 12464 || f.Proto != "tcp" {
		t.Fatalf("first flow: %+v", f)
	}
	if flows[2].DstPort != 0 || flows[2].DstIP != "8.8.8.8" {
		t.Fatalf("ICMP has no port: %+v", flows[2])
	}
}

func TestPrivateAddresses(t *testing.T) {
	for ip, want := range map[string]bool{
		"172.16.0.1": true, "172.31.255.1": true, "10.1.2.3": true, "192.168.1.1": true, "100.64.0.1": true, "224.0.0.251": true,
		"172.32.0.1": false, "8.8.8.8": false, "35.244.195.33": false, "not-an-ip": false,
	} {
		if got := isPrivateIP(ip); got != want {
			t.Errorf("isPrivateIP(%q) = %v, want %v", ip, got, want)
		}
	}
}

func TestPortsAreNamedByWhatTheyAreUsedFor(t *testing.T) {
	for port, want := range map[int]string{
		53: "DNS", 123: "Time sync (NTP)", 5228: "Google push notifications", 3478: "Calls and video (STUN/WebRTC)",
		445: "Windows file sharing (SMB)", 3389: "Remote Desktop (RDP)", 6881: "BitTorrent", 51820: "WireGuard VPN", 9001: "Tor",
		443: "", 80: "", 40000: "",
	} {
		if got := portApp("tcp", port); got != want {
			t.Errorf("portApp(%d) = %q, want %q", port, got, want)
		}
	}
}

func TestProviderFromReverseDNS(t *testing.T) {
	for host, want := range map[string]string{
		"fra16s50-in-f14.1e100.net.":                       "Google",
		"edge-star-mini-shv-01-fra3.facebook.com":          "Meta (Facebook, Instagram, WhatsApp)",
		"server-13-35-1-1.cai50.r.cloudfront.net":          "Amazon CloudFront",
		"ec2-3-120-1-1.eu-central-1.compute.amazonaws.com": "Amazon Web Services",
		"a23-45-1-1.deploy.static.akamaitechnologies.com":  "Akamai CDN",
		"host.unknown-isp.example.net":                     "example.net", // falls back to the registrable part
		"":                                                 "",
	} {
		if got := providerFromPTR(host); got != want {
			t.Errorf("providerFromPTR(%q) = %q, want %q", host, got, want)
		}
	}
}

func TestLabelingPrefersWhatTheRouterKnows(t *testing.T) {
	l := newLabeler([]string{"172.16.0.1"})
	l.addPlatform("YouTube", "142.250.185.78")
	l.addPlatform("TikTok", "161.117.0.0/16")
	l.owners["142.250.185.78"] = "Google" // reverse DNS says Google, but the router's list is more specific
	l.owners["13.35.1.1"] = "Amazon CloudFront"

	cases := []struct {
		flow Flow
		want Label
	}{
		{Flow{DstIP: "142.250.185.78", DstPort: 443, Proto: "tcp"}, Label{"YouTube", LabelPlatform}},
		{Flow{DstIP: "161.117.9.9", DstPort: 443, Proto: "tcp"}, Label{"TikTok", LabelPlatform}},
		{Flow{DstIP: "13.35.1.1", DstPort: 443, Proto: "tcp"}, Label{"Amazon CloudFront", LabelProvider}},
		{Flow{DstIP: "8.8.8.8", DstPort: 53, Proto: "udp"}, Label{"DNS", LabelApp}},
		{Flow{DstIP: "203.0.113.5", DstPort: 443, Proto: "tcp"}, Label{"203.0.113.5", LabelOther}},
		{Flow{DstIP: "172.16.0.1", DstPort: 80, Proto: "tcp"}, Label{"The router (172.16.0.1)", LabelInternal}},
		{Flow{DstIP: "172.16.0.77", DstPort: 445, Proto: "tcp"}, Label{"Other devices in the network", LabelInternal}},
	}
	for _, c := range cases {
		if got := l.label(c.flow); got != c.want {
			t.Errorf("label(%+v) = %+v, want %+v", c.flow, got, c.want)
		}
	}
}

func device(ip string) *deviceAgg {
	return newDeviceAgg(ip, DeviceIdentity{MAC: "AA:BB:CC:00:00:01", Name: "Reception PC", Kind: KindComputer})
}

func addFlows(a *deviceAgg, l *labeler, n int, mk func(i int) Flow) {
	for i := 0; i < n; i++ {
		f := mk(i)
		a.add(f, l.label(f))
	}
}

func codes(findings []Finding) map[string]string {
	out := map[string]string{}
	for _, f := range findings {
		out[f.Code] = f.Severity
	}
	return out
}

func TestAnOrdinaryDeviceHasNoFindings(t *testing.T) {
	l := newLabeler([]string{"172.16.0.1"})
	a := device("172.16.0.5")
	addFlows(a, l, 60, func(i int) Flow {
		return Flow{Proto: "tcp", SrcIP: "172.16.0.5", DstIP: fmt.Sprintf("142.250.%d.%d", i, i), DstPort: 443, Up: 1000, Down: 50000}
	})
	if got := findingsFor(a); len(got) != 0 {
		t.Fatalf("unexpected findings: %+v", got)
	}
}

func TestScanningAndExposedServicesAreHigh(t *testing.T) {
	l := newLabeler([]string{"172.16.0.1"})

	scanner := device("172.16.0.9")
	addFlows(scanner, l, 80, func(i int) Flow {
		return Flow{Proto: "tcp", SrcIP: "172.16.0.9", DstIP: fmt.Sprintf("203.0.%d.%d", i, i+1), DstPort: 445}
	})
	got := codes(findingsFor(scanner))
	if got["scan_like"] != SeverityHigh {
		t.Fatalf("SMB to 80 internet hosts must be flagged high as scanning: %v", got)
	}

	rdp := device("172.16.0.10")
	addFlows(rdp, l, 1, func(int) Flow { return Flow{Proto: "tcp", SrcIP: "172.16.0.10", DstIP: "198.51.100.7", DstPort: 3389} })
	if got := codes(findingsFor(rdp)); got["exposed_service"] != SeverityHigh {
		t.Fatalf("RDP to the internet must be flagged: %v", got)
	}
}

func TestVPNTorAndTorrentAreCalledOut(t *testing.T) {
	l := newLabeler([]string{"172.16.0.1"})
	a := device("172.16.0.11")
	for _, port := range []int{51820, 9001, 6881, 22} {
		port := port
		addFlows(a, l, 1, func(int) Flow { return Flow{Proto: "udp", SrcIP: "172.16.0.11", DstIP: "198.51.100.9", DstPort: port} })
	}
	got := codes(findingsFor(a))
	for code, sev := range map[string]string{"vpn_tunnel": SeverityMedium, "tor": SeverityHigh, "torrent": SeverityMedium, "ssh_outbound": SeverityMedium} {
		if got[code] != sev {
			t.Errorf("%s: got %q, want %q (all: %v)", code, got[code], sev, got)
		}
	}
}

func TestConnectionFloodsAndInternalSweepsAreFlagged(t *testing.T) {
	l := newLabeler([]string{"172.16.0.1"})

	flood := device("172.16.0.12")
	addFlows(flood, l, 1300, func(i int) Flow {
		return Flow{Proto: "tcp", SrcIP: "172.16.0.12", DstIP: "142.250.1.1", DstPort: 443}
	})
	if got := codes(findingsFor(flood)); got["many_connections"] != SeverityHigh {
		t.Fatalf("1300 connections must be high: %v", got)
	}

	medium := device("172.16.0.13")
	addFlows(medium, l, 600, func(i int) Flow { return Flow{Proto: "tcp", SrcIP: "172.16.0.13", DstIP: "142.250.1.1", DstPort: 443} })
	if got := codes(findingsFor(medium)); got["many_connections"] != SeverityMedium {
		t.Fatalf("600 connections must be medium: %v", got)
	}

	sweep := device("172.16.0.14")
	addFlows(sweep, l, 40, func(i int) Flow {
		return Flow{Proto: "tcp", SrcIP: "172.16.0.14", DstIP: fmt.Sprintf("172.16.1.%d", i+10), DstPort: 445}
	})
	if got := codes(findingsFor(sweep)); got["internal_sweep"] != SeverityHigh {
		t.Fatalf("reaching 40 neighbours must be flagged: %v", got)
	}
}

func TestFindingsAreSortedWorstFirst(t *testing.T) {
	l := newLabeler([]string{"172.16.0.1"})
	a := device("172.16.0.15")
	addFlows(a, l, 1, func(int) Flow { return Flow{Proto: "udp", SrcIP: "172.16.0.15", DstIP: "198.51.100.9", DstPort: 51820} })
	addFlows(a, l, 1, func(int) Flow { return Flow{Proto: "tcp", SrcIP: "172.16.0.15", DstIP: "198.51.100.9", DstPort: 3389} })
	got := findingsFor(a)
	if len(got) < 2 || got[0].Severity != SeverityHigh {
		t.Fatalf("the high finding must come first: %+v", got)
	}
}

func TestDeviceActivityRanksDestinationsByData(t *testing.T) {
	l := newLabeler([]string{"172.16.0.1"})
	l.addPlatform("YouTube", "142.250.185.78")
	a := device("172.16.0.16")
	a.add(Flow{Proto: "tcp", DstIP: "142.250.185.78", DstPort: 443, Down: 9_000_000, Up: 100_000}, l.label(Flow{DstIP: "142.250.185.78", DstPort: 443}))
	a.add(Flow{Proto: "udp", DstIP: "8.8.8.8", DstPort: 53, Down: 400, Up: 100}, l.label(Flow{DstIP: "8.8.8.8", DstPort: 53, Proto: "udp"}))

	act := a.activity()
	if act.Name != "Reception PC" || act.Connections != 2 || act.Destinations != 2 {
		t.Fatalf("activity: %+v", act)
	}
	if len(act.Top) != 2 || act.Top[0].Name != "YouTube" || act.Top[0].Down != 9_000_000 {
		t.Fatalf("top destinations: %+v", act.Top)
	}
	if len(act.Flows) != 2 || act.Flows[0].Label != "YouTube" || act.Flows[1].App != "DNS" {
		t.Fatalf("flows: %+v", act.Flows)
	}

	// A device nobody named is shown by its address.
	unnamed := newDeviceAgg("172.16.0.99", DeviceIdentity{})
	if got := unnamed.activity().Name; got != "172.16.0.99" {
		t.Fatalf("unnamed device shown as %q", got)
	}
}

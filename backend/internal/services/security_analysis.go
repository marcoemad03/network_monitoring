package services

import (
	"fmt"
	"net"
	"sort"
	"strconv"
	"strings"
)

// Destination label kinds.
const (
	LabelPlatform = "platform" // a service the hospital's own router lists identified (YouTube, Facebook...)
	LabelProvider = "provider" // the company that owns the address, from its reverse DNS name
	LabelApp      = "app"      // a protocol or application recognised by its port
	LabelInternal = "internal" // another device inside the network
	LabelOther    = "other"    // an internet host nothing is known about
)

// Finding severities.
const (
	SeverityHigh   = "high"
	SeverityMedium = "medium"
	SeverityLow    = "low"
	SeverityInfo   = "info"
)

// Flow is one connection from the router's connection table. Up is what the
// device sent (orig-bytes), Down what it received (repl-bytes).
type Flow struct {
	Proto   string
	SrcIP   string
	SrcPort int
	DstIP   string
	DstPort int
	Up      int64
	Down    int64
}

// splitHostPort reads RouterOS "1.2.3.4:443" (the port is missing for ICMP).
func splitHostPort(s string) (string, int) {
	s = strings.TrimSpace(s)
	i := strings.LastIndex(s, ":")
	if i < 0 || strings.Count(s, ":") > 1 {
		return s, 0
	}
	port, err := strconv.Atoi(s[i+1:])
	if err != nil {
		return s[:i], 0
	}
	return s[:i], port
}

// parseFlows turns connection-table rows into flows, dropping rows that do not
// name both ends.
func parseFlows(rows []map[string]string) []Flow {
	flows := make([]Flow, 0, len(rows))
	for _, r := range rows {
		srcIP, srcPort := splitHostPort(r["src-address"])
		dstIP, dstPort := splitHostPort(r["dst-address"])
		if net.ParseIP(srcIP) == nil || net.ParseIP(dstIP) == nil {
			continue
		}
		flows = append(flows, Flow{
			Proto: strings.ToLower(r["protocol"]), SrcIP: srcIP, SrcPort: srcPort, DstIP: dstIP, DstPort: dstPort,
			Up: parseCounter(r["orig-bytes"]), Down: parseCounter(r["repl-bytes"]),
		})
	}
	return flows
}

var privateNets = func() []*net.IPNet {
	var nets []*net.IPNet
	for _, c := range []string{"10.0.0.0/8", "172.16.0.0/12", "192.168.0.0/16", "169.254.0.0/16", "127.0.0.0/8", "100.64.0.0/10", "224.0.0.0/4", "255.255.255.255/32"} {
		_, n, _ := net.ParseCIDR(c)
		nets = append(nets, n)
	}
	return nets
}()

// isPrivateIP reports whether the address is inside a network rather than on the internet.
func isPrivateIP(ip string) bool {
	parsed := net.ParseIP(ip)
	if parsed == nil {
		return false
	}
	for _, n := range privateNets {
		if n.Contains(parsed) {
			return true
		}
	}
	return false
}

// portApp names what a port is usually used for. Ports 80 and 443 say nothing
// about the site, so they are not listed.
func portApp(proto string, port int) string {
	switch {
	case port == 53 || port == 5353:
		return "DNS"
	case port == 853:
		return "DNS over TLS"
	case port == 123:
		return "Time sync (NTP)"
	case port == 5228 || port == 5229 || port == 5230:
		return "Google push notifications"
	case port == 5223:
		return "Apple push notifications"
	case port >= 3478 && port <= 3481, port >= 19302 && port <= 19309:
		return "Calls and video (STUN/WebRTC)"
	case port >= 8801 && port <= 8810:
		return "Zoom"
	case port == 1935:
		return "Live streaming (RTMP)"
	case port == 554 || port == 8554:
		return "Camera stream (RTSP)"
	case port == 22:
		return "SSH"
	case port == 23:
		return "Telnet"
	case port == 21:
		return "FTP"
	case port == 25 || port == 465 || port == 587:
		return "Email sending (SMTP)"
	case port == 110 || port == 995 || port == 143 || port == 993:
		return "Email (POP/IMAP)"
	case port == 445 || port == 139:
		return "Windows file sharing (SMB)"
	case port == 3389:
		return "Remote Desktop (RDP)"
	case port == 5900 || port == 5901:
		return "Remote control (VNC)"
	case port == 1433 || port == 3306 || port == 5432 || port == 1521 || port == 27017:
		return "Database"
	case port >= 6881 && port <= 6889:
		return "BitTorrent"
	case port == 1194:
		return "OpenVPN"
	case port == 51820:
		return "WireGuard VPN"
	case port == 500 || port == 4500:
		return "IPsec VPN"
	case port == 1723:
		return "PPTP VPN"
	case port == 1701:
		return "L2TP VPN"
	case port == 9001 || port == 9030 || port == 9050 || port == 9150:
		return "Tor"
	case port == 1900:
		return "Device discovery (UPnP)"
	case port == 67 || port == 68:
		return "DHCP"
	}
	return ""
}

// providerSuffixes map the reverse-DNS name of an address to the company that
// owns it. The first matching suffix wins.
var providerSuffixes = []struct{ suffix, name string }{
	{"1e100.net", "Google"}, {"googleusercontent.com", "Google"}, {"googlevideo.com", "Google (YouTube)"},
	{"google.com", "Google"}, {"youtube.com", "Google (YouTube)"},
	{"facebook.com", "Meta (Facebook, Instagram, WhatsApp)"}, {"fbcdn.net", "Meta (Facebook, Instagram, WhatsApp)"},
	{"fbsv.net", "Meta (Facebook, Instagram, WhatsApp)"}, {"tfbnw.net", "Meta (Facebook, Instagram, WhatsApp)"},
	{"whatsapp.net", "WhatsApp"}, {"instagram.com", "Instagram"},
	{"tiktok.com", "TikTok"}, {"tiktokcdn.com", "TikTok"}, {"byteoversea.com", "TikTok"}, {"ibytedtos.com", "TikTok"},
	{"amazonaws.com", "Amazon Web Services"}, {"cloudfront.net", "Amazon CloudFront"}, {"awsglobalaccelerator.com", "Amazon Web Services"},
	{"akamaitechnologies.com", "Akamai CDN"}, {"akamai.net", "Akamai CDN"}, {"akamaiedge.net", "Akamai CDN"},
	{"cloudflare.com", "Cloudflare"}, {"cloudflare.net", "Cloudflare"},
	{"microsoft.com", "Microsoft"}, {"msedge.net", "Microsoft"}, {"windows.net", "Microsoft Azure"}, {"azure.com", "Microsoft Azure"},
	{"trafficmanager.net", "Microsoft Azure"}, {"office.net", "Microsoft 365"}, {"live.com", "Microsoft"}, {"skype.com", "Microsoft (Skype/Teams)"},
	{"apple.com", "Apple"}, {"aaplimg.com", "Apple"}, {"icloud.com", "Apple iCloud"},
	{"netflix.com", "Netflix"}, {"nflxvideo.net", "Netflix"},
	{"telegram.org", "Telegram"}, {"zoom.us", "Zoom"}, {"snapchat.com", "Snapchat"}, {"twitter.com", "X (Twitter)"}, {"twimg.com", "X (Twitter)"},
	{"fastly.net", "Fastly CDN"}, {"edgecastcdn.net", "Edgecast CDN"}, {"llnwd.net", "Limelight CDN"},
	{"digitalocean.com", "DigitalOcean"}, {"linode.com", "Linode"}, {"hetzner.com", "Hetzner"}, {"ovh.net", "OVH"},
	{"alibabacloud.com", "Alibaba Cloud"}, {"aliyuncs.com", "Alibaba Cloud"}, {"tencent.com", "Tencent"}, {"qcloud.com", "Tencent Cloud"},
	{"steamcontent.com", "Steam"}, {"valve.net", "Steam"}, {"epicgames.com", "Epic Games"},
	{"spotify.com", "Spotify"}, {"scdn.co", "Spotify"}, {"anghami.com", "Anghami"},
}

// providerFromPTR names the owner of an address from its reverse DNS name, or
// falls back to the name's registrable part ("example.net").
func providerFromPTR(host string) string {
	host = strings.ToLower(strings.TrimSuffix(strings.TrimSpace(host), "."))
	if host == "" {
		return ""
	}
	for _, p := range providerSuffixes {
		if host == p.suffix || strings.HasSuffix(host, "."+p.suffix) {
			return p.name
		}
	}
	parts := strings.Split(host, ".")
	if len(parts) >= 2 {
		return strings.Join(parts[len(parts)-2:], ".")
	}
	return host
}

// Label says where a flow goes.
type Label struct {
	Name string
	Kind string
}

// labeler decides the destination label of flows.
type labeler struct {
	routerIPs map[string]bool
	hosts     map[string]string // IP -> platform
	cidrs     []platformNet
	owners    map[string]string // IP -> provider, from reverse DNS
}

type platformNet struct {
	net  *net.IPNet
	name string
}

func newLabeler(routerIPs []string) *labeler {
	l := &labeler{routerIPs: map[string]bool{}, hosts: map[string]string{}, owners: map[string]string{}}
	for _, ip := range routerIPs {
		l.routerIPs[ip] = true
	}
	return l
}

// addPlatform records addresses that the router itself attributed to a platform.
func (l *labeler) addPlatform(name, address string) {
	address = strings.TrimSpace(address)
	if strings.Contains(address, "/") {
		if _, n, err := net.ParseCIDR(address); err == nil {
			l.cidrs = append(l.cidrs, platformNet{net: n, name: name})
		}
		return
	}
	if net.ParseIP(address) != nil {
		l.hosts[address] = name
	}
}

func (l *labeler) platformOf(ip string) string {
	if name, ok := l.hosts[ip]; ok {
		return name
	}
	parsed := net.ParseIP(ip)
	for _, c := range l.cidrs {
		if parsed != nil && c.net.Contains(parsed) {
			return c.name
		}
	}
	return ""
}

// label names the destination of a flow. Platforms the router identified win,
// then the owner from reverse DNS, then a recognised application port.
func (l *labeler) label(f Flow) Label {
	if isPrivateIP(f.DstIP) {
		if l.routerIPs[f.DstIP] {
			return Label{Name: "The router (" + f.DstIP + ")", Kind: LabelInternal}
		}
		return Label{Name: "Other devices in the network", Kind: LabelInternal}
	}
	if name := l.platformOf(f.DstIP); name != "" {
		return Label{Name: name, Kind: LabelPlatform}
	}
	if owner := l.owners[f.DstIP]; owner != "" {
		return Label{Name: owner, Kind: LabelProvider}
	}
	if f.DstPort != 80 && f.DstPort != 443 {
		if app := portApp(f.Proto, f.DstPort); app != "" {
			return Label{Name: app, Kind: LabelApp}
		}
	}
	return Label{Name: f.DstIP, Kind: LabelOther}
}

// ---------------------------------------------------------------------------
// Per-device aggregation

// LabelStat is what one device exchanged with one destination.
type LabelStat struct {
	Name        string `json:"name"`
	Kind        string `json:"kind"`
	Connections int    `json:"connections"`
	Down        int64  `json:"download_bytes"`
	Up          int64  `json:"upload_bytes"`
}

// FlowView is one connection as shown to an analyst.
type FlowView struct {
	Proto string `json:"protocol"`
	Dst   string `json:"destination"`
	Port  int    `json:"port"`
	Label string `json:"label"`
	Kind  string `json:"kind"`
	App   string `json:"app,omitempty"`
	Down  int64  `json:"download_bytes"`
	Up    int64  `json:"upload_bytes"`
}

// Finding is something a security officer may want to look at.
type Finding struct {
	Severity string `json:"severity"`
	Code     string `json:"code"`
	Title    string `json:"title"`
	Detail   string `json:"detail"`
	Action   string `json:"action,omitempty"`
	MAC      string `json:"mac"`
	IP       string `json:"ip"`
	Device   string `json:"device"`
}

// DeviceActivity is everything a scan saw one device do.
type DeviceActivity struct {
	MAC          string      `json:"mac"`
	IP           string      `json:"ip"`
	Name         string      `json:"name"`
	Kind         string      `json:"kind"`
	Connections  int         `json:"connections"`
	Down         int64       `json:"download_bytes"`
	Up           int64       `json:"upload_bytes"`
	Destinations int         `json:"destinations"`
	Top          []LabelStat `json:"top"`
	Flows        []FlowView  `json:"flows"`
	High         int         `json:"findings_high"`
	Medium       int         `json:"findings_medium"`
}

// DeviceIdentity says who an IP address belongs to.
type DeviceIdentity struct {
	MAC  string
	Name string
	Kind string
}

type deviceAgg struct {
	ident     DeviceIdentity
	ip        string
	flows     int
	down, up  int64
	dsts      map[string]bool
	labels    map[string]*LabelStat
	portDsts  map[int]map[string]bool // public destinations per port
	udpDsts   map[string]bool
	internal  map[string]bool // other devices inside the network
	flowViews []FlowView
}

func newDeviceAgg(ip string, ident DeviceIdentity) *deviceAgg {
	return &deviceAgg{
		ident: ident, ip: ip, dsts: map[string]bool{}, labels: map[string]*LabelStat{},
		portDsts: map[int]map[string]bool{}, udpDsts: map[string]bool{}, internal: map[string]bool{},
	}
}

const (
	maxTopLabels = 25
	maxFlowViews = 40
)

func (a *deviceAgg) add(f Flow, lb Label) {
	a.flows++
	a.down += f.Down
	a.up += f.Up
	a.dsts[f.DstIP] = true

	s := a.labels[lb.Name]
	if s == nil {
		s = &LabelStat{Name: lb.Name, Kind: lb.Kind}
		a.labels[lb.Name] = s
	}
	s.Connections++
	s.Down += f.Down
	s.Up += f.Up

	if lb.Kind == LabelInternal {
		a.internal[f.DstIP] = true
	} else {
		if a.portDsts[f.DstPort] == nil {
			a.portDsts[f.DstPort] = map[string]bool{}
		}
		a.portDsts[f.DstPort][f.DstIP] = true
		if f.Proto == "udp" {
			a.udpDsts[f.DstIP] = true
		}
	}
	a.flowViews = append(a.flowViews, FlowView{
		Proto: f.Proto, Dst: f.DstIP, Port: f.DstPort, Label: lb.Name, Kind: lb.Kind, App: portApp(f.Proto, f.DstPort), Down: f.Down, Up: f.Up,
	})
}

// activity finishes the aggregate.
func (a *deviceAgg) activity() DeviceActivity {
	top := make([]LabelStat, 0, len(a.labels))
	for _, s := range a.labels {
		top = append(top, *s)
	}
	sort.Slice(top, func(i, j int) bool {
		bi, bj := top[i].Down+top[i].Up, top[j].Down+top[j].Up
		if bi != bj {
			return bi > bj
		}
		return top[i].Connections > top[j].Connections
	})
	if len(top) > maxTopLabels {
		top = top[:maxTopLabels]
	}
	sort.Slice(a.flowViews, func(i, j int) bool {
		return a.flowViews[i].Down+a.flowViews[i].Up > a.flowViews[j].Down+a.flowViews[j].Up
	})
	views := a.flowViews
	if len(views) > maxFlowViews {
		views = views[:maxFlowViews]
	}
	name := a.ident.Name
	if name == "" {
		name = a.ip
	}
	return DeviceActivity{
		MAC: a.ident.MAC, IP: a.ip, Name: name, Kind: a.ident.Kind, Connections: a.flows,
		Down: a.down, Up: a.up, Destinations: len(a.dsts), Top: top, Flows: views,
	}
}

// ---------------------------------------------------------------------------
// Findings

// Thresholds, chosen to flag the unusual without flagging a busy phone.
const (
	manyConnections     = 500
	veryManyConnections = 1200
	scanLikeTargets     = 40  // distinct hosts on the same sensitive port
	internalSweep       = 25  // distinct other devices reached
	p2pPeers            = 150 // distinct UDP peers
)

var (
	exposedPorts = map[int]string{
		445: "Windows file sharing (SMB)", 139: "Windows file sharing (NetBIOS)", 3389: "Remote Desktop (RDP)",
		23: "Telnet", 5900: "VNC remote control", 1433: "SQL Server", 3306: "MySQL", 5432: "PostgreSQL", 27017: "MongoDB", 21: "FTP",
	}
	tunnelPorts = map[int]string{1194: "OpenVPN", 51820: "WireGuard", 500: "IPsec", 4500: "IPsec", 1723: "PPTP", 1701: "L2TP"}
	torPorts    = map[int]bool{9001: true, 9030: true, 9050: true, 9150: true}
)

// findingsFor looks over one device's connections for behaviour worth a look.
func findingsFor(a *deviceAgg) []Finding {
	var out []Finding
	add := func(sev, code, title, detail, action string) {
		name := a.ident.Name
		if name == "" {
			name = a.ip
		}
		out = append(out, Finding{Severity: sev, Code: code, Title: title, Detail: detail, Action: action, MAC: a.ident.MAC, IP: a.ip, Device: name})
	}

	switch {
	case a.flows >= veryManyConnections:
		add(SeverityHigh, "many_connections", fmt.Sprintf("%d open connections", a.flows),
			"A normal phone or PC keeps tens to a few hundred. Thousands often mean malware, a scanner or a torrent client.",
			"Check what is installed on the device and disconnect it if it is not expected.")
	case a.flows >= manyConnections:
		add(SeverityMedium, "many_connections", fmt.Sprintf("%d open connections", a.flows),
			"Far more than a typical device keeps open.", "Look at its destinations below and ask the user what is running.")
	}

	for port, dsts := range a.portDsts {
		app, exposed := exposedPorts[port]
		switch {
		case exposed && len(dsts) >= scanLikeTargets:
			add(SeverityHigh, "scan_like", fmt.Sprintf("Reaching %d different internet hosts on %s (port %d)", len(dsts), app, port),
				"Contacting many hosts on the same sensitive port is what a scanner or worm does.",
				"Isolate the device and scan it for malware.")
		case exposed && port != 21:
			add(SeverityHigh, "exposed_service", fmt.Sprintf("%s traffic to the internet (port %d)", app, port),
				fmt.Sprintf("%d internet host(s) contacted. This service should never leave the hospital network.", len(dsts)),
				"Block the port at the firewall and find out why the device uses it.")
		case port == 22:
			add(SeverityMedium, "ssh_outbound", "SSH connections to the internet",
				fmt.Sprintf("%d host(s) contacted. Normal for an administrator, unusual for anyone else.", len(dsts)), "Confirm the user is expected to use SSH.")
		case torPorts[port]:
			add(SeverityHigh, "tor", "Tor traffic", "Tor hides where traffic goes and bypasses every control on the network.", "Find the program and remove it.")
		case port >= 6881 && port <= 6889:
			add(SeverityMedium, "torrent", "BitTorrent traffic", "File sharing takes bandwidth and often carries pirated or infected files.", "Remove the client and block the ports.")
		}
		if name, ok := tunnelPorts[port]; ok {
			add(SeverityMedium, "vpn_tunnel", name+" tunnel to the internet",
				"An encrypted tunnel hides everything the device does from the hospital's controls.", "Confirm the VPN is approved.")
		}
	}

	if len(a.udpDsts) >= p2pPeers {
		add(SeverityMedium, "p2p_peers", fmt.Sprintf("UDP traffic with %d different internet hosts", len(a.udpDsts)),
			"Many UDP peers look like peer-to-peer sharing or a streaming client.", "Check what the device is running.")
	}
	if len(a.internal) >= internalSweep {
		add(SeverityHigh, "internal_sweep", fmt.Sprintf("Connected to %d other devices inside the network", len(a.internal)),
			"Reaching many neighbours at once is how malware looks for the next device to infect.", "Isolate the device and scan it.")
	}

	order := map[string]int{SeverityHigh: 0, SeverityMedium: 1, SeverityLow: 2, SeverityInfo: 3}
	sort.SliceStable(out, func(i, j int) bool { return order[out[i].Severity] < order[out[j].Severity] })
	return out
}

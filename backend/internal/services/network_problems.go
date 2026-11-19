package services

import (
	"context"
	"fmt"
	"net/netip"
	"sort"
	"strings"
	"time"

	"github.com/google/uuid"
)

// Network problems: devices that are connected but cannot use the internet, and
// addresses that two devices use at once. Everything here is read from the router
// (hotspot hosts and IP bindings, DHCP leases and pools, ARP, the router's own
// addresses and the NMS's drop rules); nothing is written.

// Issue kinds.
const (
	IssueIPConflict    = "ip_conflict"
	IssueReservedTaken = "reserved_taken"
	IssueNotLoggedIn   = "not_logged_in"
	IssueNoReply       = "no_reply"
	IssueWrongNetwork  = "wrong_network"
	IssueStaticInPool  = "static_in_pool"
	IssueRouterBlocked = "router_blocked"
	IssueNMSBlocked    = "nms_blocked"
)

const (
	noReplyMinUptime = 300        // seconds logged in before "no reply" is judged
	noReplyMinSent   = 100 * 1024 // bytes the device sent
	noReplyMaxGot    = 64 * 1024  // bytes it got back
)

// IssueDevice is one device in an issue.
type IssueDevice struct {
	MAC    string `json:"mac"`
	IP     string `json:"ip,omitempty"`
	Name   string `json:"name,omitempty"`
	Kind   string `json:"kind,omitempty"`
	Seen   string `json:"seen,omitempty"` // where the router lists it
	Online bool   `json:"online"`
}

// NetworkIssue is one problem found.
type NetworkIssue struct {
	Kind     string        `json:"kind"`
	Severity string        `json:"severity"` // error | warning | info
	Title    string        `json:"title"`
	Detail   string        `json:"detail"`
	Fix      string        `json:"fix"`
	Address  string        `json:"address,omitempty"`
	Devices  []IssueDevice `json:"devices"`
}

// NetworkProblems is the answer of the check.
type NetworkProblems struct {
	Available   bool           `json:"available"`
	Error       string         `json:"error,omitempty"`
	CheckedAt   time.Time      `json:"checked_at"`
	DevicesSeen int            `json:"devices_seen"`
	Issues      []NetworkIssue `json:"issues"`
}

// problemTables are the router tables the check reads.
type problemTables struct {
	hosts, leases, arps, bindings []map[string]string
	addresses, pools, dhcp        []map[string]string
	// nmsDrops maps each address the NMS cuts off completely to the rule's time
	// window ("" when always).
	nmsDrops map[string]string
}

// Problems reads the router and lists what is wrong.
func (s *ClientInventoryService) Problems(ctx context.Context, orgID uuid.UUID) (NetworkProblems, error) {
	out := NetworkProblems{CheckedAt: time.Now(), Issues: []NetworkIssue{}}
	vendor, err := s.internetRepo.GetActiveMikroTikIntegration(ctx, orgID)
	if err != nil {
		out.Error = "No router is set up."
		return out, nil
	}
	sess, err := openRouterSessionWith(ctx, vendor, s.cfg, s.dial, true, false)
	if err != nil || sess == nil {
		out.Error = "The router could not be reached."
		return out, nil
	}
	t, err := readProblemTables(sess)
	sess.Close()
	if err != nil {
		out.Error = err.Error()
		return out, nil
	}

	names := map[string]ClientView{}
	if list, err := s.List(ctx, orgID); err == nil {
		for _, c := range list.Clients {
			names[c.MAC] = c
		}
	}
	out.Available = true
	out.Issues, out.DevicesSeen = findNetworkProblems(t, names)
	return out, nil
}

func readProblemTables(conn routerCommander) (problemTables, error) {
	var t problemTables
	var errs []string
	read := func(path, props string, query ...string) []map[string]string {
		rows, err := conn.Command(path, append([]string{"=.proplist=" + props}, query...)...)
		if err != nil {
			errs = append(errs, fmt.Sprintf("%s: %v", path, err))
		}
		return rows
	}
	t.hosts = read("/ip/hotspot/host/print", "mac-address,address,to-address,authorized,bypassed,bytes-in,bytes-out,uptime,idle-time")
	t.leases = read("/ip/dhcp-server/lease/print", "mac-address,address,status,dynamic,disabled,blocked,host-name")
	t.arps = read("/ip/arp/print", "address,mac-address,interface,complete,invalid")
	t.bindings = read("/ip/hotspot/ip-binding/print", "mac-address,address,type,disabled,comment")
	t.addresses = read("/ip/address/print", "address,interface,disabled")
	t.pools = read("/ip/pool/print", "name,ranges")
	t.dhcp = read("/ip/dhcp-server/print", "name,address-pool,disabled")
	if len(t.hosts) == 0 && len(t.leases) == 0 && len(t.arps) == 0 && len(errs) > 0 {
		return t, fmt.Errorf("the router's device tables could not be read: %s", strings.Join(errs, "; "))
	}

	// The NMS's own drop rules that cut a device off completely (no destination).
	t.nmsDrops = map[string]string{}
	rules := read("/ip/firewall/filter/print", "chain,action,src-address,src-address-list,dst-address,dst-address-list,time,disabled,comment")
	lists := map[string]string{}
	for _, r := range rules {
		if !strings.HasPrefix(r["comment"], marcoManagedPrefix) || r["chain"] != "forward" || r["action"] != "drop" ||
			isRouterTrue(r["disabled"]) || r["dst-address"] != "" || r["dst-address-list"] != "" {
			continue
		}
		if a := strings.TrimSuffix(r["src-address"], "/32"); a != "" {
			t.nmsDrops[a] = r["time"]
		}
		if l := r["src-address-list"]; l != "" {
			lists[l] = r["time"]
		}
	}
	for l, when := range lists {
		for _, e := range read("/ip/firewall/address-list/print", "list,address,disabled", "?list="+l) {
			if !isRouterTrue(e["disabled"]) {
				t.nmsDrops[strings.TrimSuffix(e["address"], "/32")] = when
			}
		}
	}
	return t, nil
}

type addrRange struct{ from, to netip.Addr }

func (r addrRange) contains(a netip.Addr) bool { return a.Compare(r.from) >= 0 && a.Compare(r.to) <= 0 }

// parsePoolRanges reads "172.16.0.71-172.16.0.254,10.0.0.0/24".
func parsePoolRanges(v string) []addrRange {
	var out []addrRange
	for _, part := range strings.Split(v, ",") {
		part = strings.TrimSpace(part)
		if from, to, ok := strings.Cut(part, "-"); ok {
			a, err1 := netip.ParseAddr(strings.TrimSpace(from))
			b, err2 := netip.ParseAddr(strings.TrimSpace(to))
			if err1 == nil && err2 == nil {
				out = append(out, addrRange{a, b})
			}
			continue
		}
		if p, err := netip.ParsePrefix(part); err == nil {
			p = p.Masked()
			out = append(out, addrRange{p.Addr(), lastAddr(p)})
		} else if a, err := netip.ParseAddr(part); err == nil {
			out = append(out, addrRange{a, a})
		}
	}
	return out
}

func lastAddr(p netip.Prefix) netip.Addr {
	b := p.Addr().As4()
	host := 32 - p.Bits()
	for i := 3; i >= 0 && host > 0; i-- {
		n := min(host, 8)
		b[i] |= byte(1<<n - 1)
		host -= n
	}
	return netip.AddrFrom4(b)
}

// findNetworkProblems is the check itself, on tables already read.
func findNetworkProblems(t problemTables, names map[string]ClientView) ([]NetworkIssue, int) {
	var subnets []netip.Prefix
	for _, r := range t.addresses {
		if p, err := netip.ParsePrefix(r["address"]); err == nil && !isRouterTrue(r["disabled"]) {
			subnets = append(subnets, p.Masked())
		}
	}
	poolByName := map[string][]addrRange{}
	for _, r := range t.pools {
		poolByName[r["name"]] = parsePoolRanges(r["ranges"])
	}
	var dhcpRanges []addrRange
	for _, r := range t.dhcp {
		if !isRouterTrue(r["disabled"]) {
			dhcpRanges = append(dhcpRanges, poolByName[r["address-pool"]]...)
		}
	}
	inSubnet := func(a netip.Addr) bool {
		for _, p := range subnets {
			if p.Contains(a) {
				return true
			}
		}
		return len(subnets) == 0
	}
	inPool := func(a netip.Addr) bool {
		for _, r := range dhcpRanges {
			if r.contains(a) {
				return true
			}
		}
		return false
	}

	device := func(mac, ip, seen string, online bool) IssueDevice {
		d := IssueDevice{MAC: mac, IP: ip, Seen: seen, Online: online}
		if c, ok := names[mac]; ok {
			d.Name, d.Kind = c.DisplayName, c.Kind
		}
		return d
	}

	// Who claims each address, and from where.
	type claim struct {
		mac, seen string
		active    bool
	}
	claims := map[string][]claim{}
	addClaim := func(ip, mac, seen string, active bool) {
		for i, c := range claims[ip] {
			if c.mac == mac {
				if active && !c.active {
					claims[ip][i] = claim{mac, seen, true}
				}
				return
			}
		}
		claims[ip] = append(claims[ip], claim{mac, seen, active})
	}
	// Devices connected now, with the address they use.
	type present struct {
		ip, seen string
	}
	connected := map[string]present{}
	hostByMAC := map[string]map[string]string{}

	for _, h := range t.hosts {
		mac := normalizeMAC(h["mac-address"])
		ip := strings.TrimSpace(h["address"])
		if mac == "" || ip == "" || parseRouterUptime(h["idle-time"]) > clientOnlineIdle {
			continue
		}
		hostByMAC[mac] = h
		connected[mac] = present{ip, "Wi-Fi page (hotspot)"}
		addClaim(ip, mac, "Wi-Fi page (hotspot)", true)
	}
	for _, a := range t.arps {
		mac := normalizeMAC(a["mac-address"])
		ip := strings.TrimSpace(a["address"])
		if mac == "" || ip == "" || !isRouterTrue(a["complete"]) || isRouterTrue(a["invalid"]) {
			continue
		}
		if _, ok := connected[mac]; !ok {
			connected[mac] = present{ip, "ARP"}
		}
		addClaim(ip, mac, "ARP", true)
	}
	leaseFor := map[string]bool{} // mac|ip
	for _, l := range t.leases {
		mac := normalizeMAC(l["mac-address"])
		ip := strings.TrimSpace(l["address"])
		if mac == "" || ip == "" || isRouterTrue(l["disabled"]) {
			continue
		}
		leaseFor[mac+"|"+ip] = true
		switch {
		case strings.EqualFold(l["status"], "bound"):
			addClaim(ip, mac, "DHCP lease", true)
		case !isRouterTrue(l["dynamic"]):
			addClaim(ip, mac, "reserved in DHCP", false)
		}
	}

	var issues []NetworkIssue
	inConflict := map[string]bool{}

	ips := make([]string, 0, len(claims))
	for ip := range claims {
		ips = append(ips, ip)
	}
	sort.Strings(ips)
	for _, ip := range ips {
		cs := claims[ip]
		if len(cs) < 2 {
			continue
		}
		a, err := netip.ParseAddr(ip)
		if err != nil || !inSubnet(a) {
			continue
		}
		var active, reserved []claim
		for _, c := range cs {
			if c.active {
				active = append(active, c)
			} else {
				reserved = append(reserved, c)
			}
		}
		var devs []IssueDevice
		for _, c := range cs {
			_, on := connected[c.mac]
			devs = append(devs, device(c.mac, ip, c.seen, on))
		}
		switch {
		case len(active) >= 2:
			inConflict[ip] = true
			issues = append(issues, NetworkIssue{
				Kind: IssueIPConflict, Severity: "error", Address: ip, Devices: devs,
				Title:  fmt.Sprintf("%d devices are using %s", len(active), ip),
				Detail: "Two devices on one address keep cutting each other off: the internet works on one, then the other, or on neither.",
				Fix:    "Set the device with a manual address to automatic (DHCP), or give it an address outside the DHCP range.",
			})
		case len(active) == 1 && len(reserved) > 0:
			inConflict[ip] = true
			issues = append(issues, NetworkIssue{
				Kind: IssueReservedTaken, Severity: "warning", Address: ip, Devices: devs,
				Title:  fmt.Sprintf("%s is reserved for one device but another is using it", ip),
				Detail: "When the device the address is reserved for connects, both will lose the internet.",
				Fix:    "Set the device using it to automatic (DHCP), or move the reservation.",
			})
		}
	}

	macs := make([]string, 0, len(connected))
	for mac := range connected {
		macs = append(macs, mac)
	}
	sort.Strings(macs)

	var notLogged, nmsCut []IssueDevice
	nmsWhen := map[string]bool{}
	for _, mac := range macs {
		p := connected[mac]
		a, err := netip.ParseAddr(p.ip)
		if err != nil {
			continue
		}
		h := hostByMAC[mac]
		translated := h != nil && h["to-address"] != "" && h["to-address"] != p.ip

		switch {
		case !inSubnet(a) && !translated:
			issues = append(issues, NetworkIssue{
				Kind: IssueWrongNetwork, Severity: "error", Address: p.ip, Devices: []IssueDevice{device(mac, p.ip, p.seen, true)},
				Title:  fmt.Sprintf("%s is outside the hospital network", p.ip),
				Detail: "The device has a manual address from another network, so the router cannot send its traffic out.",
				Fix:    "Set its network settings to automatic (DHCP).",
			})
		case inPool(a) && !leaseFor[mac+"|"+p.ip] && !inConflict[p.ip] && !translated:
			issues = append(issues, NetworkIssue{
				Kind: IssueStaticInPool, Severity: "warning", Address: p.ip, Devices: []IssueDevice{device(mac, p.ip, p.seen, true)},
				Title:  fmt.Sprintf("Manual address %s inside the DHCP range", p.ip),
				Detail: "DHCP does not know this device uses the address and can give it to another device, which cuts both off.",
				Fix:    "Set the device to automatic (DHCP), or reserve the address for it.",
			})
		}

		if h != nil && !isRouterTrue(h["authorized"]) && !isRouterTrue(h["bypassed"]) {
			notLogged = append(notLogged, device(mac, p.ip, p.seen, true))
		}
		if h != nil && isRouterTrue(h["authorized"]) && parseRouterUptime(h["uptime"]) >= noReplyMinUptime &&
			parseCounter(h["bytes-in"]) >= noReplyMinSent && parseCounter(h["bytes-out"]) < noReplyMaxGot {
			issues = append(issues, NetworkIssue{
				Kind: IssueNoReply, Severity: "warning", Address: p.ip, Devices: []IssueDevice{device(mac, p.ip, p.seen, true)},
				Title:  "Sends data but gets almost nothing back",
				Detail: fmt.Sprintf("Since it logged in it sent %s and got %s. Its internet is probably not working.", formatBytes(parseCounter(h["bytes-in"])), formatBytes(parseCounter(h["bytes-out"]))),
				Fix:    "Check the device's DNS and proxy settings, its date and time, and any VPN on it. Forget the Wi-Fi and join again.",
			})
		}
		if when, ok := t.nmsDrops[p.ip]; ok {
			nmsCut = append(nmsCut, device(mac, p.ip, p.seen, true))
			nmsWhen[when] = true
		}
	}

	for _, b := range t.bindings {
		if b["type"] != "blocked" || isRouterTrue(b["disabled"]) {
			continue
		}
		mac := normalizeMAC(b["mac-address"])
		ip := strings.TrimSpace(b["address"])
		_, on := connected[mac]
		issues = append(issues, NetworkIssue{
			Kind: IssueRouterBlocked, Severity: "info", Address: ip, Devices: []IssueDevice{device(mac, ip, "hotspot IP binding", on)},
			Title:  "Blocked on the router",
			Detail: strings.TrimSpace("A hotspot IP binding blocks this device. " + decodeRouterText(b["comment"])),
			Fix:    "If it should have internet, remove the binding in IP > Hotspot > IP Bindings.",
		})
	}
	for _, l := range t.leases {
		if !isRouterTrue(l["blocked"]) || isRouterTrue(l["disabled"]) {
			continue
		}
		mac := normalizeMAC(l["mac-address"])
		_, on := connected[mac]
		issues = append(issues, NetworkIssue{
			Kind: IssueRouterBlocked, Severity: "info", Address: l["address"], Devices: []IssueDevice{device(mac, l["address"], "DHCP lease", on)},
			Title:  "Blocked in DHCP",
			Detail: "The device's DHCP lease is set to blocked, so the router does not pass its traffic.",
			Fix:    "If it should have internet, untick Block Access on its lease in IP > DHCP Server > Leases.",
		})
	}

	if len(nmsCut) > 0 {
		detail := "An NMS group or device block has turned the internet off for these devices."
		for when := range nmsWhen {
			if when != "" {
				detail += " Some only during a schedule (" + when + ")."
				break
			}
		}
		issues = append(issues, NetworkIssue{
			Kind: IssueNMSBlocked, Severity: "info", Devices: nmsCut,
			Title:  fmt.Sprintf("%d device%s with the internet turned off by the NMS", len(nmsCut), plural(len(nmsCut))),
			Detail: detail,
			Fix:    "This is on purpose. Change it in Marco groups if it should not be.",
		})
	}
	if len(notLogged) > 0 {
		issues = append(issues, NetworkIssue{
			Kind: IssueNotLoggedIn, Severity: "warning", Devices: notLogged,
			Title:  fmt.Sprintf("%d device%s on the Wi-Fi but not logged in", len(notLogged), plural(len(notLogged))),
			Detail: "They are connected but have not passed the Wi-Fi page, so they have no internet yet. Phones left in a pocket are often here.",
			Fix:    "Open any website on the device to get the Wi-Fi page. A computer or printer that cannot open the page needs a bypassed IP binding.",
		})
	}

	rank := map[string]int{"error": 0, "warning": 1, "info": 2}
	sort.SliceStable(issues, func(i, j int) bool { return rank[issues[i].Severity] < rank[issues[j].Severity] })
	return issues, len(connected)
}

func formatBytes(n int64) string {
	switch {
	case n >= 1<<20:
		return fmt.Sprintf("%.1f MB", float64(n)/(1<<20))
	case n >= 1<<10:
		return fmt.Sprintf("%d KB", n/(1<<10))
	}
	return fmt.Sprintf("%d bytes", n)
}

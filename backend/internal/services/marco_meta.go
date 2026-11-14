package services

import (
	"context"
	"fmt"
	"net"
	"sort"
	"strconv"
	"strings"
	"sync"
	"time"
)

// Meta speed limit: Facebook and Instagram cannot be blocked without WhatsApp, which
// runs on the same servers, but they need speed and WhatsApp messages do not. A
// group's devices get their download from Meta's addresses capped per device.
//
// Hotspot users have dynamic simple queues that catch all of a device's traffic
// first, so the cap is a queue tree on the LAN interface: packets go through both.
// Upload is not capped: after NAT every device has the router's address, and video
// is download.
const (
	marcoMetaList      = "nms-marco-meta"
	marcoMetaTypeStart = "nms-marco-meta-"
	// marcoLANParent stands for the LAN interface until the sync has read it.
	marcoLANParent = "lan"
)

// metaIPRanges is address space Meta (AS32934) runs itself. Video Meta serves from
// caches inside the internet provider's network is not in it, so part of Facebook's
// video can still come at full speed.
var metaIPRanges = []string{
	"31.13.24.0/21", "31.13.64.0/18", "45.64.40.0/22", "57.144.0.0/14", "66.220.144.0/20",
	"69.63.176.0/20", "69.171.192.0/18", "102.132.96.0/20", "103.4.96.0/22", "129.134.0.0/16",
	"157.240.0.0/16", "163.70.128.0/17", "173.252.64.0/18", "179.60.192.0/22", "185.60.216.0/22",
	"185.89.216.0/22", "199.201.64.0/22", "204.15.20.0/22",
}

func metaTypeName(kbps int) string { return fmt.Sprintf("%s%dk", marcoMetaTypeStart, kbps) }

// addMetaLimit marks the downloads from Meta to the group's devices and caps them
// with a per-device PCQ queue.
func (d *marcoDesiredState) addMetaLimit(g8, srcList string, kbps int) {
	if d.mangle == nil {
		d.mangle = map[string]desiredRouterEntry{}
	}
	if d.trees == nil {
		d.trees = map[string]desiredRouterEntry{}
	}
	if d.queueTypes == nil {
		d.queueTypes = map[string]string{}
	}
	mark := fmt.Sprintf("%smeta-%s", marcoManagedPrefix, g8)
	comment := fmt.Sprintf("%s%s-meta", marcoManagedPrefix, g8)
	d.mangle[comment] = desiredRouterEntry{path: "/ip/firewall/mangle", attrs: map[string]string{
		"chain": "forward", "action": "mark-packet", "new-packet-mark": mark, "passthrough": "no",
		"src-address-list": marcoMetaList, "dst-address-list": srcList, "comment": comment, "disabled": "no",
	}}
	typeName := metaTypeName(kbps)
	d.queueTypes[typeName] = strconv.Itoa(kbps * 1000)
	d.trees[comment] = desiredRouterEntry{path: "/queue/tree", attrs: map[string]string{
		"name": comment, "parent": marcoLANParent, "packet-mark": mark, "queue": typeName,
		"comment": comment, "disabled": "no",
	}}
}

// setLANParent puts the LAN interface into the trees, or drops the Meta limit with
// a warning when there is none to put them on.
func (d *marcoDesiredState) setLANParent(iface string) {
	if len(d.trees) == 0 {
		return
	}
	if iface == "" {
		d.warnings = append(d.warnings, "Meta speed limit: the LAN interface was not found (set ROUTER_LAN_INTERFACE), so it is not applied")
		d.trees, d.mangle, d.queueTypes = nil, nil, nil
		return
	}
	for _, e := range d.trees {
		e.attrs["parent"] = iface
	}
}

// lanInterface is the configured LAN interface, or the hotspot's when none is set.
func lanInterface(conn routerCommander, configured string) (string, error) {
	if configured != "" {
		return configured, nil
	}
	rows, err := conn.Command("/ip/hotspot/print")
	if err != nil {
		return "", fmt.Errorf("read the hotspot interface: %w", err)
	}
	for _, r := range rows {
		if r["interface"] != "" && r["disabled"] != "true" {
			return r["interface"], nil
		}
	}
	return "", nil
}

// syncQueueTypes adds or updates the PCQ types the trees use. Queue types have no
// comment, so they are known by their name.
func syncQueueTypes(conn routerCommander, want map[string]string, journal *changeJournal) error {
	if len(want) == 0 {
		return nil
	}
	rows, err := conn.Command("/queue/type/print")
	if err != nil {
		return fmt.Errorf("print /queue/type: %w", err)
	}
	have := map[string]map[string]string{}
	for _, r := range rows {
		if strings.HasPrefix(r["name"], marcoMetaTypeStart) {
			have[r["name"]] = r
		}
	}
	names := make([]string, 0, len(want))
	for name := range want {
		names = append(names, name)
	}
	sort.Strings(names)
	for _, name := range names {
		attrs := map[string]string{"pcq-rate": want[name], "pcq-classifier": "dst-address"}
		cur, ok := have[name]
		if !ok {
			if _, err := conn.Command("/queue/type/add", append([]string{"=name=" + name, "=kind=pcq"}, attributeWords(attrs)...)...); err != nil {
				return fmt.Errorf("add queue type %q: %w", name, err)
			}
			journal.added = append(journal.added, journalAdded{path: "/queue/type", comment: name})
			continue
		}
		if cur["pcq-rate"] == attrs["pcq-rate"] && cur["pcq-classifier"] == attrs["pcq-classifier"] {
			continue
		}
		old := map[string]string{"pcq-rate": cur["pcq-rate"], "pcq-classifier": cur["pcq-classifier"]}
		if _, err := conn.Command("/queue/type/set", append([]string{"=.id=" + cur[".id"]}, attributeWords(attrs)...)...); err != nil {
			return fmt.Errorf("update queue type %q: %w", name, err)
		}
		journal.modified = append(journal.modified, journalModified{path: "/queue/type", id: cur[".id"], old: old})
	}
	return nil
}

// removeUnusedQueueTypes removes the Meta PCQ types no tree uses any more. It runs
// after the trees that used them are gone.
func removeUnusedQueueTypes(conn routerCommander, want map[string]string) error {
	rows, err := conn.Command("/queue/type/print")
	if err != nil {
		return fmt.Errorf("print /queue/type: %w", err)
	}
	for _, r := range rows {
		if !strings.HasPrefix(r["name"], marcoMetaTypeStart) {
			continue
		}
		if _, ok := want[r["name"]]; ok {
			continue
		}
		if _, err := conn.Command("/queue/type/remove", "=.id="+r[".id"]); err != nil {
			return fmt.Errorf("remove queue type %q: %w", r["name"], err)
		}
	}
	return nil
}

// Most Facebook and Instagram video does not come from Meta's ranges but from
// Meta's caches inside the Egyptian internet providers (names like
// scontent.fcai30-1.fna.fbcdn.net). Their addresses are found by asking the same
// public DNS the phones use for the Cairo cache names, and their networks join the
// Meta list. A cache network found once is kept for a month, because a name may
// not answer every time.
const (
	metaCacheSites   = 40
	metaCacheNodes   = 4
	metaCacheRefresh = 6 * time.Hour
	metaCacheKeep    = 30 * 24 * time.Hour
	metaCacheDNS     = "8.8.8.8:53"
)

type metaCacheFinder struct {
	mu       sync.Mutex
	seen     map[string]time.Time // network -> last time a cache name pointed into it
	lastRun  time.Time
	running  bool
	lookupIP func(ctx context.Context, host string) ([]net.IP, error)
}

func newMetaCacheFinder() *metaCacheFinder {
	r := &net.Resolver{PreferGo: true, Dial: func(ctx context.Context, network, _ string) (net.Conn, error) {
		var d net.Dialer
		return d.DialContext(ctx, network, metaCacheDNS)
	}}
	return &metaCacheFinder{seen: map[string]time.Time{}, lookupIP: func(ctx context.Context, host string) ([]net.IP, error) {
		return r.LookupIP(ctx, "ip4", host)
	}}
}

// networks returns the cache networks known now. The first call looks them up and
// waits; later ones start a new look in the background when the last is old.
func (f *metaCacheFinder) networks(now time.Time) []string {
	f.mu.Lock()
	first := f.lastRun.IsZero() && !f.running
	stale := !f.running && now.Sub(f.lastRun) >= metaCacheRefresh
	if stale {
		f.running = true
	}
	f.mu.Unlock()
	if first {
		f.find(now)
	} else if stale {
		go f.find(now)
	}
	f.mu.Lock()
	defer f.mu.Unlock()
	out := make([]string, 0, len(f.seen))
	for n, at := range f.seen {
		if now.Sub(at) <= metaCacheKeep {
			out = append(out, n)
		}
	}
	sort.Strings(out)
	return out
}

func (f *metaCacheFinder) find(now time.Time) {
	ctx, cancel := context.WithTimeout(context.Background(), 60*time.Second)
	defer cancel()
	var mu sync.Mutex
	found := map[string]bool{}
	names := make(chan string)
	var wg sync.WaitGroup
	for w := 0; w < 8; w++ {
		wg.Add(1)
		go func() {
			defer wg.Done()
			for name := range names {
				lctx, lcancel := context.WithTimeout(ctx, 3*time.Second)
				ips, err := f.lookupIP(lctx, name)
				lcancel()
				if err != nil {
					continue
				}
				for _, ip := range ips {
					if n := metaCacheNetwork(ip); n != "" {
						mu.Lock()
						found[n] = true
						mu.Unlock()
					}
				}
			}
		}()
	}
	for site := 1; site <= metaCacheSites; site++ {
		for node := 1; node <= metaCacheNodes; node++ {
			names <- fmt.Sprintf("scontent.fcai%d-%d.fna.fbcdn.net", site, node)
		}
	}
	close(names)
	wg.Wait()

	f.mu.Lock()
	defer f.mu.Unlock()
	for n := range found {
		f.seen[n] = now
	}
	f.lastRun, f.running = now, false
}

// metaCacheNetwork is the /24 a cache address is in, unless it is already in Meta's
// own ranges or is not a public address.
func metaCacheNetwork(ip net.IP) string {
	v4 := ip.To4()
	if v4 == nil || v4.IsPrivate() || v4.IsLoopback() || v4.IsUnspecified() {
		return ""
	}
	for _, c := range metaIPRanges {
		if _, n, err := net.ParseCIDR(c); err == nil && n.Contains(v4) {
			return ""
		}
	}
	return fmt.Sprintf("%d.%d.%d.0/24", v4[0], v4[1], v4[2])
}

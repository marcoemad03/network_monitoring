package services

import (
	"context"
	"fmt"
	"net"
	"sort"
	"strconv"
	"strings"
	"sync"

	"github.com/hospital/nms-backend/internal/config"
	"github.com/hospital/nms-backend/internal/models"
	"github.com/hospital/nms-backend/pkg/mikrotik"
)

// routerGate serializes every RouterOS policy session (group sync, quota loop,
// legacy policy sync) so two goroutines never edit the same tables at once.
var routerGate = make(chan struct{}, 1)

func acquireRouterGate(ctx context.Context) (func(), error) {
	select {
	case routerGate <- struct{}{}:
		return func() { <-routerGate }, nil
	case <-ctx.Done():
		return nil, fmt.Errorf("another router sync is still running: %w", ctx.Err())
	}
}

func tryAcquireRouterGate() (func(), bool) {
	select {
	case routerGate <- struct{}{}:
		return func() { <-routerGate }, true
	default:
		return nil, false
	}
}

// routerSession wraps a RouterOS connection. Read commands (print) always pass
// through; every mutating command is either forwarded (writes enabled) or only
// recorded (dry-run), so no code path can modify the router by accident.
type routerSession struct {
	inner   routerCommander
	ctx     context.Context
	write   bool
	release func()
	once    sync.Once

	mu      sync.Mutex
	planned []string
}

func newRouterSession(ctx context.Context, inner routerCommander, write bool, release func()) *routerSession {
	return &routerSession{inner: inner, ctx: ctx, write: write, release: release}
}

func (s *routerSession) DryRun() bool { return !s.write }

func (s *routerSession) Planned() []string {
	s.mu.Lock()
	defer s.mu.Unlock()
	return append([]string(nil), s.planned...)
}

func (s *routerSession) Command(path string, attrs ...string) ([]map[string]string, error) {
	if err := s.ctx.Err(); err != nil {
		return nil, fmt.Errorf("router session cancelled: %w", err)
	}
	if !strings.HasSuffix(path, "/print") && !s.write {
		s.mu.Lock()
		s.planned = append(s.planned, path+" "+strings.Join(attrs, " "))
		s.mu.Unlock()
		return nil, nil
	}
	return s.inner.Command(path, attrs...)
}

func (s *routerSession) Close() error {
	err := s.inner.Close()
	s.once.Do(func() {
		if s.release != nil {
			s.release()
		}
	})
	return err
}

// openRouterSession acquires the global gate, dials the router and wraps the
// connection. wait=false returns (nil, nil) when another session is running.
func openRouterSession(ctx context.Context, vendor *models.VendorIntegration, cfg *config.Config, dial func(*models.VendorIntegration, *config.Config) (routerCommander, error), wait bool) (*routerSession, error) {
	return openRouterSessionWith(ctx, vendor, cfg, dial, wait, cfg.RouterPolicyWrites)
}

// openRouterSessionWith is openRouterSession with an explicit write permission,
// for engines that need a stricter switch than ROUTER_POLICY_WRITES.
func openRouterSessionWith(ctx context.Context, vendor *models.VendorIntegration, cfg *config.Config, dial func(*models.VendorIntegration, *config.Config) (routerCommander, error), wait bool, write bool) (*routerSession, error) {
	var release func()
	if wait {
		r, err := acquireRouterGate(ctx)
		if err != nil {
			return nil, err
		}
		release = r
	} else {
		r, ok := tryAcquireRouterGate()
		if !ok {
			return nil, nil
		}
		release = r
	}
	conn, err := dial(vendor, cfg)
	if err != nil {
		release()
		return nil, err
	}
	return newRouterSession(ctx, conn, write, release), nil
}

// ---------------------------------------------------------------------------
// Protected addresses and plan validation

// protectedNetworks returns the networks that policy rules must never target:
// the router itself plus anything listed in ROUTER_PROTECTED_IPS.
func protectedNetworks(vendor *models.VendorIntegration, cfg *config.Config) []*net.IPNet {
	var nets []*net.IPNet
	add := func(value string) {
		value = strings.TrimSpace(value)
		if value == "" {
			return
		}
		if _, n, err := net.ParseCIDR(value); err == nil {
			nets = append(nets, n)
			return
		}
		if ip := net.ParseIP(value); ip != nil {
			bits := 128
			if ip.To4() != nil {
				bits = 32
				ip = ip.To4()
			}
			nets = append(nets, &net.IPNet{IP: ip, Mask: net.CIDRMask(bits, bits)})
		}
	}
	for _, v := range cfg.RouterProtectedIPs {
		add(v)
	}
	if vendor != nil {
		if host, _, err := mikrotik.ParseEndpoint(vendor.BaseURL); err == nil {
			add(host)
		}
	}
	return nets
}

func isProtectedIP(ip net.IP, nets []*net.IPNet) bool {
	for _, n := range nets {
		if n.Contains(ip) {
			return true
		}
	}
	return false
}

// validateFirewallScope refuses any drop/reject rule that is not limited to a
// specific source, so a malformed policy can never cut the whole hospital off.
func validateFirewallScope(rules map[string]desiredRouterEntry) error {
	for comment, rule := range rules {
		action := rule.attrs["action"]
		if action != "drop" && action != "reject" {
			continue
		}
		if rule.attrs["src-address-list"] == "" && rule.attrs["src-address"] == "" && rule.attrs["src-mac-address"] == "" {
			return fmt.Errorf("refusing unscoped %s rule %q: it would affect every device", action, comment)
		}
		if a := rule.attrs["src-address"]; a == "0.0.0.0/0" || a == "0.0.0.0/32" {
			return fmt.Errorf("refusing %s rule %q scoped to all addresses", action, comment)
		}
	}
	return nil
}

func validateEntryCount(cfg *config.Config, counts ...int) error {
	total := 0
	for _, c := range counts {
		total += c
	}
	if cfg.RouterMaxManagedEntries > 0 && total > cfg.RouterMaxManagedEntries {
		return fmt.Errorf("plan has %d managed entries, above the safety limit of %d (ROUTER_MAX_MANAGED_ENTRIES)", total, cfg.RouterMaxManagedEntries)
	}
	return nil
}

// ---------------------------------------------------------------------------
// Prefix aware listing (RouterOS API "?comment=x" is an exact match, not a prefix)

// listManaged prints a RouterOS table and keeps entries whose comment starts
// with prefix. Duplicate comments (left over from earlier faulty syncs) are
// returned in dups so they can be cleaned up.
func listManaged(conn routerCommander, path, prefix string, exclude func(string) bool) (byComment map[string]map[string]string, dups []map[string]string, err error) {
	var args []string
	if path == "/ip/firewall/address-list" {
		args = []string{"=.proplist=.id,list,address,comment,disabled"}
	}
	entries, err := conn.Command(path+"/print", args...)
	if err != nil {
		return nil, nil, fmt.Errorf("print %s: %w", path, err)
	}
	byComment = make(map[string]map[string]string)
	for _, e := range entries {
		c := e["comment"]
		if !strings.HasPrefix(c, prefix) || (exclude != nil && exclude(c)) {
			continue
		}
		if _, exists := byComment[c]; exists {
			dups = append(dups, e)
			continue
		}
		byComment[c] = e
	}
	return byComment, dups, nil
}

// ---------------------------------------------------------------------------
// Attribute comparison tolerant of RouterOS value normalization

func attrMatches(key, got, want string) bool {
	if got == want {
		return true
	}
	switch key {
	case "address", "target", "src-address", "dst-address":
		return trimHostMask(got) == trimHostMask(want)
	case "src-mac-address":
		return strings.EqualFold(got, want)
	case "time":
		return normalizeTimeRange(got) == normalizeTimeRange(want)
	case "days":
		return normalizeDaysList(got) == normalizeDaysList(want)
	case "disabled":
		return normalizeBool(got) == normalizeBool(want)
	case "max-limit", "burst-limit", "burst-threshold":
		return normalizeRatePair(got) == normalizeRatePair(want)
	case "burst-time":
		return normalizeSecondsPair(got) == normalizeSecondsPair(want)
	}
	return false
}

func trimHostMask(v string) string {
	v = strings.TrimSuffix(v, "/32")
	return strings.TrimSuffix(v, "/128")
}

func normalizeBool(v string) string {
	switch strings.ToLower(strings.TrimSpace(v)) {
	case "yes", "true":
		return "yes"
	default:
		return "no"
	}
}

func normalizeTimeRange(v string) string {
	parts := strings.SplitN(v, "-", 2)
	if len(parts) != 2 {
		return v
	}
	fix := func(t string) string {
		t = strings.TrimSpace(t)
		if strings.Count(t, ":") == 1 {
			return t + ":00"
		}
		return t
	}
	return fix(parts[0]) + "-" + fix(parts[1])
}

func normalizeDaysList(v string) string {
	var out []string
	for _, d := range strings.Split(v, ",") {
		if d = strings.ToLower(strings.TrimSpace(d)); d != "" {
			out = append(out, d)
		}
	}
	sort.Strings(out)
	return strings.Join(out, ",")
}

func parseRate(v string) int64 {
	v = strings.TrimSpace(strings.ToLower(v))
	if v == "" {
		return 0
	}
	mult := int64(1)
	switch {
	case strings.HasSuffix(v, "g"):
		mult, v = 1_000_000_000, strings.TrimSuffix(v, "g")
	case strings.HasSuffix(v, "m"):
		mult, v = 1_000_000, strings.TrimSuffix(v, "m")
	case strings.HasSuffix(v, "k"):
		mult, v = 1_000, strings.TrimSuffix(v, "k")
	}
	f, err := strconv.ParseFloat(v, 64)
	if err != nil {
		return 0
	}
	return int64(f * float64(mult))
}

func normalizeRatePair(v string) string {
	parts := strings.SplitN(v, "/", 2)
	if len(parts) != 2 {
		return fmt.Sprintf("%d", parseRate(v))
	}
	return fmt.Sprintf("%d/%d", parseRate(parts[0]), parseRate(parts[1]))
}

func normalizeSecondsPair(v string) string {
	parts := strings.SplitN(v, "/", 2)
	clean := func(s string) string { return strings.TrimSuffix(strings.TrimSpace(s), "s") }
	if len(parts) != 2 {
		return clean(v)
	}
	return clean(parts[0]) + "/" + clean(parts[1])
}

// entryMatches reports whether every desired attribute is already present.
func entryMatches(current map[string]string, want map[string]string) bool {
	for key, value := range want {
		if !attrMatches(key, current[key], value) {
			return false
		}
	}
	return true
}

// ---------------------------------------------------------------------------
// Change journal: undo only what this run changed

type journalAdded struct{ path, comment string }
type journalRemoved struct {
	path  string
	attrs map[string]string
	top   bool
}
type journalModified struct {
	path string
	id   string
	old  map[string]string
}

type changeJournal struct {
	added    []journalAdded
	removed  []journalRemoved
	modified []journalModified
}

func (j *changeJournal) empty() bool {
	return len(j.added) == 0 && len(j.removed) == 0 && len(j.modified) == 0
}

// rollback reverts the journal in reverse order. It is best effort and returns
// the first error encountered.
func (j *changeJournal) rollback(conn routerCommander) error {
	var first error
	keep := func(err error) {
		if err != nil && first == nil {
			first = err
		}
	}
	for i := len(j.modified) - 1; i >= 0; i-- {
		m := j.modified[i]
		_, err := conn.Command(m.path+"/set", append([]string{"=.id=" + m.id}, attributeWords(m.old)...)...)
		keep(err)
	}
	for i := len(j.added) - 1; i >= 0; i-- {
		a := j.added[i]
		entries, err := conn.Command(a.path + "/print")
		if err != nil {
			keep(err)
			continue
		}
		for _, e := range entries {
			if e["comment"] == a.comment {
				_, err := conn.Command(a.path+"/remove", "=.id="+e[".id"])
				keep(err)
			}
		}
	}
	for i := len(j.removed) - 1; i >= 0; i-- {
		r := j.removed[i]
		keep(addRouterEntry(conn, r.path, r.attrs, r.top))
	}
	return first
}

// addRouterEntry adds an entry; filter rules are placed at the top of the chain
// so a preceding accept rule cannot shadow them. Falls back to a plain add if
// the router rejects the placement.
func addRouterEntry(conn routerCommander, path string, attrs map[string]string, top bool) error {
	words := attributeWords(attrs)
	if top {
		if _, err := conn.Command(path+"/add", append(append([]string(nil), words...), "=place-before=0")...); err == nil {
			return nil
		}
	}
	_, err := conn.Command(path+"/add", words...)
	return err
}

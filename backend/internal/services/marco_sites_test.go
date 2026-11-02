package services

import (
	"context"
	"errors"
	"net"
	"strings"
	"testing"
	"time"

	"github.com/google/uuid"
	"github.com/hospital/nms-backend/internal/models"
)

func TestNormalizeSite(t *testing.T) {
	good := map[string][2]string{
		"https://www.Example.com/path?x=1": {"example.com", "domain"},
		"  EXAMPLE.com  ":                  {"example.com", "domain"},
		"m.example.com:8080":               {"m.example.com", "domain"},
		"example.com.":                     {"example.com", "domain"},
		"203.0.113.7":                      {"203.0.113.7", "ip"},
		"198.51.100.77/24":                 {"198.51.100.0/24", "cidr"},
		"http://203.0.113.7:81/x":          {"203.0.113.7", "ip"},
		"example.co.uk":                    {"example.co.uk", "domain"},
		"موقع.مصر":                         {"xn--4gbrim.xn--wgbh1c", "domain"},
	}
	for in, want := range good {
		got, kind, err := NormalizeSite(in)
		if err != nil || got != want[0] || string(kind) != want[1] {
			t.Errorf("NormalizeSite(%q) = %q %q %v, want %v", in, got, kind, err, want)
		}
	}
	bad := []string{"", "   ", "com", "co.uk", "not a site", "exa mple.com", "-bad.com", "10.0.0.5", "192.168.1.1", "127.0.0.1", "0.0.0.0", "8.0.0.0/8", "2001:db8::1", "a..com"}
	for _, in := range bad {
		if v, _, err := NormalizeSite(in); err == nil {
			t.Errorf("NormalizeSite(%q) = %q, want an error", in, v)
		} else if _, ok := err.(*SiteInputError); !ok {
			t.Errorf("NormalizeSite(%q) error type %T", in, err)
		}
	}
}

func TestGroupBlockTargetsExpandsPacks(t *testing.T) {
	domains, ips, platforms := groupBlockTargets([]string{"games", "nope", "GAMES"}, []string{"Roblox.com", "https://my-site.example/x", "203.0.113.9", "bad site"})
	if !contains(platforms, "steam") || !contains(platforms, "epicgames") {
		t.Errorf("platforms = %v", platforms)
	}
	if !contains(domains, "roblox.com") || !contains(domains, "my-site.example") || !contains(domains, "garena.com") {
		t.Errorf("domains = %v", domains)
	}
	count := 0
	for _, d := range domains {
		if d == "roblox.com" {
			count++
		}
	}
	if count != 1 {
		t.Errorf("roblox.com listed %d times", count)
	}
	if len(ips) != 1 || ips[0] != "203.0.113.9" {
		t.Errorf("ips = %v", ips)
	}
	for _, pack := range MarcoSitePacks {
		for _, d := range pack.Domains {
			if v, kind, err := NormalizeSite(d); err != nil || v != d || kind != SiteDomain {
				t.Errorf("pack %s: %q is not a clean domain (%q %v)", pack.Key, d, v, err)
			}
		}
		for _, p := range pack.Platforms {
			if _, ok := marcoPlatformByKey[p]; !ok {
				t.Errorf("pack %s: unknown platform %q", pack.Key, p)
			}
		}
	}
	for _, d := range DefaultAllowedDomains {
		if v, _, err := NormalizeSite(d); err != nil || v != strings.TrimPrefix(d, "www.") {
			t.Errorf("always-allowed %q is not a clean domain", d)
		}
	}
}

func contains(list []string, v string) bool {
	for _, x := range list {
		if x == v {
			return true
		}
	}
	return false
}

func fakeResolver(table map[string][]string) *SiteResolver {
	r := NewSiteResolver()
	calls := 0
	_ = calls
	r.lookup = func(ctx context.Context, host string) ([]net.IP, error) {
		ips, ok := table[host]
		if !ok {
			return nil, &net.DNSError{Err: "no such host", Name: host, IsNotFound: true}
		}
		var out []net.IP
		for _, s := range ips {
			out = append(out, net.ParseIP(s))
		}
		return out, nil
	}
	return r
}

func TestResolverSeparatesSharedAndBlockableAddresses(t *testing.T) {
	r := fakeResolver(map[string][]string{
		"games.example":           {"203.0.113.10", "203.0.113.11"},
		"www.games.example":       {"203.0.113.11", "203.0.113.12"},
		"cf.example":              {"104.16.1.1", "104.16.1.2"},
		"www.cf.example":          {"104.16.1.1"},
		"mixed.example":           {"203.0.113.50", "151.101.1.1"},
		"www.mixed.example":       {"203.0.113.50"},
		"google-only.example":     {"142.250.1.1"},
		"www.google-only.example": {"142.250.1.1"},
		"filtered.example":        {"0.0.0.0"},
		"www.filtered.example":    {"0.0.0.0"},
	})
	ctx := context.Background()

	g := r.Resolve(ctx, "https://www.games.example/")
	if len(g.IPs) != 3 || g.Error != "" || g.Target != "games.example" {
		t.Errorf("games = %+v", g)
	}
	cf := r.Resolve(ctx, "cf.example")
	if cf.Blockable() || cf.SharedProvider != "Cloudflare" || !strings.Contains(cf.Error, "Cloudflare") {
		t.Errorf("cloudflare site = %+v", cf)
	}
	mixed := r.Resolve(ctx, "mixed.example")
	if len(mixed.IPs) != 1 || mixed.IPs[0] != "203.0.113.50" || len(mixed.Shared) != 1 || mixed.Error != "" {
		t.Errorf("mixed = %+v", mixed)
	}
	if g := r.Resolve(ctx, "google-only.example"); g.Blockable() || g.SharedProvider != "Google" {
		t.Errorf("google = %+v", g)
	}
	if f := r.Resolve(ctx, "filtered.example"); f.Blockable() || !strings.Contains(f.Error, "private") {
		t.Errorf("filtered = %+v", f)
	}
	if m := r.Resolve(ctx, "missing.example"); m.Blockable() || !strings.Contains(m.Error, "does not exist") {
		t.Errorf("missing = %+v", m)
	}
	ip := r.Resolve(ctx, "203.0.113.9")
	if !ip.Blockable() || ip.Kind != SiteIP || ip.IPs[0] != "203.0.113.9" {
		t.Errorf("ip = %+v", ip)
	}
	if bad := r.Resolve(ctx, "10.1.1.1"); bad.Error == "" {
		t.Errorf("private literal accepted: %+v", bad)
	}
}

func TestResolverKeepsLastGoodAnswerWhenLookupsFail(t *testing.T) {
	r := NewSiteResolver()
	now := time.Now()
	r.now = func() time.Time { return now }
	fail := false
	r.lookup = func(ctx context.Context, host string) ([]net.IP, error) {
		if fail {
			return nil, errors.New("i/o timeout")
		}
		return []net.IP{net.ParseIP("203.0.113.5")}, nil
	}
	if res := r.Resolve(context.Background(), "site.example"); len(res.IPs) != 1 {
		t.Fatalf("first = %+v", res)
	}
	fail = true
	now = now.Add(2 * resolverTTL)
	res := r.Resolve(context.Background(), "site.example")
	if len(res.IPs) != 1 || res.Error != "" {
		t.Errorf("an old answer should be used when the name server is down: %+v", res)
	}
	if res := r.Resolve(context.Background(), "other.example"); res.Blockable() || !strings.Contains(res.Error, "in time") {
		t.Errorf("never-seen name = %+v", res)
	}
}

func TestAllowedAddressesKeepSharedRanges(t *testing.T) {
	r := fakeResolver(map[string][]string{"www.googleapis.com": {"172.217.112.4", "172.217.113.4"}, "a.example": {"10.0.0.1", "203.0.113.1"}})
	got := r.AllowedAddresses(context.Background(), []string{"www.googleapis.com", "a.example", "gone.example"})
	want := []string{"172.217.112.4", "172.217.113.4", "203.0.113.1"}
	if strings.Join(got, ",") != strings.Join(want, ",") {
		t.Errorf("allowed = %v, want %v", got, want)
	}
}

// ---------------------------------------------------------------------------
// Desired state

var (
	gA = uuid.MustParse("aaaaaaaa-0000-0000-0000-000000000001")
	d1 = uuid.MustParse("d1d1d1d1-0000-0000-0000-000000000001")
	d2 = uuid.MustParse("d2d2d2d2-0000-0000-0000-000000000002")
)

func member(id uuid.UUID, mac, ip string) models.MarcoGroupMember {
	m := mac
	return models.MarcoGroupMember{ID: uuid.New(), GroupID: gA, DeviceID: id, DeviceName: mac, MACAddress: &m, IPAddress: net.ParseIP(ip)}
}

func boolp(v bool) *bool        { return &v }
func floatp(v float64) *float64 { return &v }
func strp(v string) *string     { return &v }

func groupWith(p models.MarcoGroupPolicy) []models.MarcoGroup {
	return []models.MarcoGroup{{ID: gA, Name: "Wards", Policy: NormalizeMarcoPolicy(p)}}
}

func membersOf(ms ...models.MarcoGroupMember) map[uuid.UUID][]models.MarcoGroupMember {
	return map[uuid.UUID][]models.MarcoGroupMember{gA: ms}
}

func TestSiteBlockingBuildsListRuleAndAllowRule(t *testing.T) {
	groups := groupWith(models.MarcoGroupPolicy{BlockedDomains: []string{"games.example", "cf.example", "nowhere.example"}})
	opts := marcoBuildOptions{
		siteIPs: map[string]ResolvedSite{
			"games.example":   {Target: "games.example", IPs: []string{"203.0.113.10", "172.217.112.4"}},
			"cf.example":      {Target: "cf.example", Error: describeShared("Cloudflare"), SharedProvider: "Cloudflare"},
			"nowhere.example": {Target: "nowhere.example", Error: "the name does not exist"},
		},
		allowIPs: []string{"172.217.112.4"},
	}
	d := buildMarcoDesiredState(groups, membersOf(member(d1, "AA:AA:AA:00:00:01", "172.16.0.10")), opts)

	list := "nms-marco-site-aaaaaaaa"
	var sites []string
	for _, e := range d.addrLists {
		if e.attrs["list"] == list {
			sites = append(sites, e.attrs["address"])
		}
	}
	if len(sites) != 1 || sites[0] != "203.0.113.10" {
		t.Errorf("site list = %v (the address shared with always-allowed services must be left out)", sites)
	}
	rule := d.firewall["nms-marco-aaaaaaaa-sites"]
	if rule.attrs["action"] != "drop" || rule.attrs["src-address-list"] != "nms-marco-src-aaaaaaaa" || rule.attrs["dst-address-list"] != list || !rule.top {
		t.Errorf("sites rule = %+v", rule)
	}
	allow := d.firewall["nms-marco-aaaaaaaa-allow"]
	if allow.attrs["action"] != "accept" || allow.attrs["dst-address-list"] != marcoAllowList || allow.attrs["src-address-list"] != "nms-marco-src-aaaaaaaa" {
		t.Errorf("allow rule = %+v", allow)
	}
	foundAllow := false
	for _, e := range d.addrLists {
		if e.attrs["list"] == marcoAllowList && e.attrs["address"] == "172.217.112.4" {
			foundAllow = true
		}
	}
	if !foundAllow {
		t.Error("the always-allowed address is not in the allow list")
	}
	warn := strings.Join(d.warnings, "\n")
	if !strings.Contains(warn, "cf.example cannot be blocked: hosted on Cloudflare") || !strings.Contains(warn, "nowhere.example cannot be blocked: the name does not exist") {
		t.Errorf("warnings = %v", d.warnings)
	}
	if err := validateFirewallScope(d.firewall); err != nil {
		t.Errorf("rules are not scoped: %v", err)
	}
}

func TestPlatformBlockedByRouterListGetsAllowRuleToo(t *testing.T) {
	groups := groupWith(models.MarcoGroupPolicy{BlockedWebsites: []string{"youtube"}})
	opts := marcoBuildOptions{platformLists: map[string]string{"youtube": "collect all youtube ips"}, allowIPs: []string{"172.217.115.4"}}
	d := buildMarcoDesiredState(groups, membersOf(member(d1, "AA:AA:AA:00:00:01", "172.16.0.10")), opts)
	if d.firewall["nms-marco-aaaaaaaa-plat-youtube"].attrs["dst-address-list"] != "collect all youtube ips" {
		t.Errorf("youtube rule missing: %+v", d.firewall)
	}
	if d.firewall["nms-marco-aaaaaaaa-allow"].attrs["action"] != "accept" {
		t.Errorf("Firebase and Translate need an allow rule: %+v", d.firewall)
	}
}

func TestNoAllowRuleWithoutAddressBlocks(t *testing.T) {
	groups := groupWith(models.MarcoGroupPolicy{InternetEnabled: boolp(false)})
	d := buildMarcoDesiredState(groups, membersOf(member(d1, "AA:AA:AA:00:00:01", "172.16.0.10")), marcoBuildOptions{allowIPs: []string{"172.217.115.4"}})
	if _, ok := d.firewall["nms-marco-aaaaaaaa-allow"]; ok {
		t.Error("an internet-off group must not get a rule that lets anything through")
	}
	if d.firewall["nms-marco-aaaaaaaa-net-off"].attrs["action"] != "drop" {
		t.Errorf("rules = %+v", d.firewall)
	}
}

func TestDeviceOverridesBlockAndLimitAnyDevice(t *testing.T) {
	groups := groupWith(models.MarcoGroupPolicy{UnlimitedSpeed: boolp(false), DownloadLimitMbps: floatp(10), UploadLimitMbps: floatp(5)})
	members := membersOf(member(d1, "AA:AA:AA:00:00:01", "172.16.0.10"), member(d2, "AA:AA:AA:00:00:02", "172.16.0.11"))
	opts := marcoBuildOptions{overrides: []marcoOverrideTarget{
		{MAC: "AA:AA:AA:00:00:01", IP: net.ParseIP("172.16.0.10"), DownMbps: floatp(2), UpMbps: floatp(1)},
		{MAC: "BB:BB:BB:00:00:09", IP: net.ParseIP("172.16.0.99"), Blocked: true},
		{MAC: "BB:BB:BB:00:00:0A", IP: nil, Blocked: true},
	}}
	d := buildMarcoDesiredState(groups, members, opts)

	own := d.queues["nms-marco-q-dev-aaaaaa000001"]
	if own.attrs["target"] != "172.16.0.10/32" || own.attrs["max-limit"] != "1000000/2000000" {
		t.Errorf("device queue = %+v", own)
	}
	if _, dup := d.queues["nms-marco-q-d1d1d1d1"]; dup {
		t.Error("a device with its own limit must not also get its group's queue")
	}
	if q := d.queues["nms-marco-q-d2d2d2d2"]; q.attrs["max-limit"] != "5000000/10000000" {
		t.Errorf("the other member keeps the group limit: %+v", q)
	}
	rule := d.firewall["nms-marco-device-block"]
	if rule.attrs["src-address-list"] != marcoBlockedList || rule.attrs["action"] != "drop" {
		t.Errorf("block rule = %+v", rule)
	}
	if e := d.addrLists["nms-marco-blocked-bbbbbb000009"]; e.attrs["address"] != "172.16.0.99/32" {
		t.Errorf("blocked device entry = %+v", e)
	}
	if !strings.Contains(strings.Join(d.warnings, "\n"), "BB:BB:BB:00:00:0A: the router has not seen this device") {
		t.Errorf("a device with no address must be reported: %v", d.warnings)
	}
	if err := validateFirewallScope(d.firewall); err != nil {
		t.Error(err)
	}
}

func TestOverridesRespectProtectedAddresses(t *testing.T) {
	_, n, _ := net.ParseCIDR("172.16.0.1/32")
	opts := marcoBuildOptions{protected: []*net.IPNet{n}, overrides: []marcoOverrideTarget{{MAC: "AA:AA:AA:00:00:01", IP: net.ParseIP("172.16.0.1"), Blocked: true}}}
	d := buildMarcoDesiredState(nil, nil, opts)
	if len(d.firewall) != 0 || len(d.addrLists) != 0 || len(d.warnings) != 1 {
		t.Errorf("the router must never be blocked: %+v %v", d.firewall, d.warnings)
	}
}

func TestSiteAddressesAreCapped(t *testing.T) {
	var ips []string
	for i := 0; i < 200; i++ {
		ips = append(ips, net.IPv4(203, 0, byte(i/250), byte(i%250+1)).String())
	}
	groups := groupWith(models.MarcoGroupPolicy{BlockedDomains: []string{"big.example"}})
	d := buildMarcoDesiredState(groups, membersOf(member(d1, "AA:AA:AA:00:00:01", "172.16.0.10")), marcoBuildOptions{siteIPs: map[string]ResolvedSite{"big.example": {IPs: ips, Many: true}}})
	n := 0
	for _, e := range d.addrLists {
		if strings.HasPrefix(e.attrs["list"], marcoSitePrefix) {
			n++
		}
	}
	if n != maxSiteAddrsPerGroup || !strings.Contains(strings.Join(d.warnings, "\n"), "only the first") {
		t.Errorf("addresses = %d, warnings = %v", n, d.warnings)
	}
}

// ---------------------------------------------------------------------------
// Rule order and pruning

type rowRouter struct {
	rows     map[string][]map[string]string
	commands []recordedCommand
}

func (f *rowRouter) Command(path string, attrs ...string) ([]map[string]string, error) {
	f.commands = append(f.commands, recordedCommand{path: path, attrs: attrs})
	if strings.HasSuffix(path, "/print") {
		return f.rows[strings.TrimSuffix(path, "/print")], nil
	}
	return nil, nil
}
func (f *rowRouter) Close() error { return nil }

func routerRule(id, comment, action, dst string) map[string]string {
	return map[string]string{".id": id, "comment": comment, "action": action, "dst-address-list": dst}
}

func moves(f *rowRouter) []string {
	var out []string
	for _, c := range f.commands {
		if strings.HasSuffix(c.path, "/move") {
			out = append(out, strings.Join(c.attrs, " "))
		}
	}
	return out
}

func TestRuleOrderPutsAcceptsBetweenHardAndSoftBlocks(t *testing.T) {
	// Router order (top first): a soft block, then the accept, then a hard block.
	f := &rowRouter{rows: map[string][]map[string]string{"/ip/firewall/filter": {
		routerRule("*1", "other rule", "accept", ""),
		routerRule("*2", "nms-marco-aaaaaaaa-plat-youtube", "drop", "yt"),
		routerRule("*3", "nms-marco-aaaaaaaa-allow", "accept", marcoAllowList),
		routerRule("*4", "nms-marco-aaaaaaaa-net-off", "drop", ""),
	}}}
	if err := orderMarcoRules(f); err != nil {
		t.Fatal(err)
	}
	got := moves(f)
	// Hard block goes above the first later-class rule (the soft block), then the accept goes above it.
	if len(got) != 2 || got[0] != "=numbers=*4 =destination=*2" || got[1] != "=numbers=*3 =destination=*2" {
		t.Errorf("moves = %v", got)
	}
	for _, c := range f.commands {
		if strings.Contains(c.path, "*1") || strings.Contains(strings.Join(c.attrs, " "), "numbers=*1") {
			t.Error("a rule the NMS did not create was moved")
		}
	}

	ok := &rowRouter{rows: map[string][]map[string]string{"/ip/firewall/filter": {
		routerRule("*1", "nms-marco-aaaaaaaa-net-off", "drop", ""),
		routerRule("*2", "nms-marco-aaaaaaaa-allow", "accept", marcoAllowList),
		routerRule("*3", "nms-marco-aaaaaaaa-plat-youtube", "drop", "yt"),
	}}}
	if err := orderMarcoRules(ok); err != nil || len(moves(ok)) != 0 {
		t.Errorf("rules already in order must not be moved: %v %v", err, moves(ok))
	}
}

func TestApplyRefusesToRemoveTooManyEntries(t *testing.T) {
	var rows []map[string]string
	for i := 0; i < 70; i++ {
		rows = append(rows, map[string]string{".id": "*" + string(rune('A'+i%26)), "comment": "nms-marco-old-" + strings.Repeat("x", i), "list": "l", "address": "1.1.1.1"})
	}
	f := &rowRouter{rows: map[string][]map[string]string{"/ip/firewall/address-list": rows}}
	err := applyMarcoDesiredState(f, marcoDesiredState{firewall: map[string]desiredRouterEntry{}, queues: map[string]desiredRouterEntry{}, addrLists: map[string]desiredRouterEntry{}, layer7: map[string]desiredRouterEntry{}}, &changeJournal{}, true, 60)
	if err == nil || !strings.Contains(err.Error(), "refusing to remove 70") {
		t.Fatalf("err = %v", err)
	}
	for _, c := range f.commands {
		if strings.HasSuffix(c.path, "/remove") {
			t.Fatal("nothing may be removed when the plan is refused")
		}
	}
}

func TestApplyRemovesStaleEntriesAndLeavesFlagOffAlone(t *testing.T) {
	rows := []map[string]string{{".id": "*1", "comment": "nms-marco-src-aaaaaaaa-d1d1d1d1", "list": "nms-marco-src-aaaaaaaa", "address": "172.16.0.10/32"}}
	empty := func() marcoDesiredState {
		return marcoDesiredState{firewall: map[string]desiredRouterEntry{}, queues: map[string]desiredRouterEntry{}, addrLists: map[string]desiredRouterEntry{}, layer7: map[string]desiredRouterEntry{}}
	}
	f := &rowRouter{rows: map[string][]map[string]string{"/ip/firewall/address-list": rows}}
	if err := applyMarcoDesiredState(f, empty(), &changeJournal{}, true, 60); err != nil {
		t.Fatal(err)
	}
	removed := 0
	for _, c := range f.commands {
		if c.path == "/ip/firewall/address-list/remove" && len(c.attrs) == 1 && c.attrs[0] == "=.id=*1" {
			removed++
		}
	}
	if removed != 1 {
		t.Errorf("the stale source entry (a device taken out of a group) must be removed; commands = %v", f.commands)
	}
	g := &rowRouter{rows: map[string][]map[string]string{"/ip/firewall/address-list": rows}}
	if err := applyMarcoDesiredState(g, empty(), &changeJournal{}, false, 60); err != nil {
		t.Fatal(err)
	}
	for _, c := range g.commands {
		if strings.HasSuffix(c.path, "/remove") {
			t.Error("with pruning switched off nothing is removed")
		}
	}
}

func TestSoftApplyAddsNewRulesButLeavesManyOldOnesAlone(t *testing.T) {
	var rows []map[string]string
	for i := 0; i < 70; i++ {
		rows = append(rows, map[string]string{".id": "*" + strings.Repeat("A", i+1), "comment": "nms-marco-old-" + strings.Repeat("x", i), "list": "l", "address": "1.1.1.1"})
	}
	f := &rowRouter{rows: map[string][]map[string]string{"/ip/firewall/address-list": rows}}
	d := marcoDesiredState{firewall: map[string]desiredRouterEntry{}, queues: map[string]desiredRouterEntry{}, layer7: map[string]desiredRouterEntry{},
		addrLists: map[string]desiredRouterEntry{"nms-marco-src-new": {path: "/ip/firewall/address-list", attrs: map[string]string{"list": "nms-marco-src-x", "address": "172.16.0.9/32", "comment": "nms-marco-src-new", "disabled": "no"}}}}

	skipped, err := applyMarcoCore(f, d, &changeJournal{}, true, 60, true)
	if err != nil || skipped != 70 {
		t.Fatalf("skipped = %d, err = %v", skipped, err)
	}
	added, removed := 0, 0
	for _, c := range f.commands {
		switch c.path {
		case "/ip/firewall/address-list/add":
			added++
		case "/ip/firewall/address-list/remove":
			removed++
		}
	}
	if added != 1 || removed != 0 {
		t.Errorf("a new group must still work while old leftovers wait: added=%d removed=%d", added, removed)
	}

	// Once confirmed, the leftovers go.
	g := &rowRouter{rows: map[string][]map[string]string{"/ip/firewall/address-list": rows}}
	skipped, err = applyMarcoCore(g, d, &changeJournal{}, true, 0, true)
	if err != nil || skipped != 0 {
		t.Fatalf("confirmed: skipped = %d, err = %v", skipped, err)
	}
	removed = 0
	for _, c := range g.commands {
		if c.path == "/ip/firewall/address-list/remove" {
			removed++
		}
	}
	if removed != 70 {
		t.Errorf("confirmed removal took out %d entries, want 70", removed)
	}
}

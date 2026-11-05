package services

import (
	"context"
	"net"
	"strings"
	"testing"

	"github.com/google/uuid"
	"github.com/hospital/nms-backend/internal/config"
	"github.com/hospital/nms-backend/internal/models"
)

// memRouter is an in-memory RouterOS that honours print/add/set/remove closely
// enough to exercise the reconcile, verify and rollback paths.
type memRouter struct {
	tables  map[string][]map[string]string
	nextID  int
	writes  int
	failAdd func(path string, attrs map[string]string) error
}

func newMemRouter() *memRouter { return &memRouter{tables: map[string][]map[string]string{}} }

func parseAttrs(words []string) map[string]string {
	out := map[string]string{}
	for _, w := range words {
		if !strings.HasPrefix(w, "=") {
			continue
		}
		kv := strings.SplitN(w[1:], "=", 2)
		if len(kv) == 2 {
			out[kv[0]] = kv[1]
		}
	}
	return out
}

func (m *memRouter) Command(path string, words ...string) ([]map[string]string, error) {
	switch {
	case strings.HasSuffix(path, "/print"):
		table := strings.TrimSuffix(path, "/print")
		var out []map[string]string
		for _, e := range m.tables[table] {
			cp := map[string]string{}
			for k, v := range e {
				cp[k] = v
			}
			out = append(out, cp)
		}
		return out, nil
	case strings.HasSuffix(path, "/add"):
		table := strings.TrimSuffix(path, "/add")
		attrs := parseAttrs(words)
		delete(attrs, "place-before")
		if m.failAdd != nil {
			if err := m.failAdd(table, attrs); err != nil {
				return nil, err
			}
		}
		m.nextID++
		m.writes++
		attrs[".id"] = "*" + strings.Repeat("1", m.nextID)
		m.tables[table] = append(m.tables[table], attrs)
	case strings.HasSuffix(path, "/set"):
		table := strings.TrimSuffix(path, "/set")
		attrs := parseAttrs(words)
		id := attrs["id"]
		_ = id
		for _, e := range m.tables[table] {
			if e[".id"] == attrs[".id"] {
				for k, v := range attrs {
					if k != ".id" {
						e[k] = v
					}
				}
			}
		}
		m.writes++
	case strings.HasSuffix(path, "/remove"):
		table := strings.TrimSuffix(path, "/remove")
		id := parseAttrs(words)[".id"]
		var kept []map[string]string
		for _, e := range m.tables[table] {
			if e[".id"] != id {
				kept = append(kept, e)
			}
		}
		m.tables[table] = kept
		m.writes++
	}
	return nil, nil
}

func (m *memRouter) Close() error { return nil }

func (m *memRouter) count(table, prefix string) int {
	n := 0
	for _, e := range m.tables[table] {
		if strings.HasPrefix(e["comment"], prefix) {
			n++
		}
	}
	return n
}

func testMarcoGroup(policy models.MarcoGroupPolicy) ([]models.MarcoGroup, map[uuid.UUID][]models.MarcoGroupMember) {
	g := models.MarcoGroup{ID: uuid.MustParse("aaaaaaaa-0000-0000-0000-000000000001"), Name: "Kids", Policy: NormalizeMarcoPolicy(policy)}
	mac := "AA:BB:CC:DD:EE:01"
	member := models.MarcoGroupMember{
		GroupID: g.ID, DeviceID: uuid.MustParse("bbbbbbbb-0000-0000-0000-000000000001"),
		DeviceName: "Tablet", MACAddress: &mac, IPAddress: net.ParseIP("192.168.10.50"),
	}
	return []models.MarcoGroup{g}, map[uuid.UUID][]models.MarcoGroupMember{g.ID: {member}}
}

func boolPtr(v bool) *bool { return &v }

func TestDryRunSessionNeverMutatesRouter(t *testing.T) {
	router := newMemRouter()
	sess := newRouterSession(context.Background(), router, false, nil)

	if _, err := sess.Command("/ip/firewall/filter/add", "=chain=forward", "=action=drop"); err != nil {
		t.Fatal(err)
	}
	if _, err := sess.Command("/ip/firewall/filter/remove", "=.id=*1"); err != nil {
		t.Fatal(err)
	}
	if router.writes != 0 {
		t.Fatalf("dry-run session wrote to the router %d times", router.writes)
	}
	if len(sess.Planned()) != 2 {
		t.Fatalf("expected 2 planned changes, got %v", sess.Planned())
	}
	if _, err := sess.Command("/ip/firewall/filter/print"); err != nil {
		t.Fatal(err)
	}
}

func TestRouterGateIsExclusive(t *testing.T) {
	release, err := acquireRouterGate(context.Background())
	if err != nil {
		t.Fatal(err)
	}
	if _, ok := tryAcquireRouterGate(); ok {
		t.Fatal("second session acquired the gate while the first was running")
	}
	release()
	rel2, ok := tryAcquireRouterGate()
	if !ok {
		t.Fatal("gate was not released")
	}
	rel2()
}

func TestValidateFirewallScopeRefusesUnscopedDrop(t *testing.T) {
	bad := map[string]desiredRouterEntry{"x": {attrs: map[string]string{"chain": "forward", "action": "drop", "time": "08:00:00-17:00:00"}}}
	if err := validateFirewallScope(bad); err == nil {
		t.Fatal("unscoped drop rule must be refused")
	}
	ok := map[string]desiredRouterEntry{"x": {attrs: map[string]string{"chain": "forward", "action": "drop", "src-address-list": "l"}}}
	if err := validateFirewallScope(ok); err != nil {
		t.Fatalf("scoped rule refused: %v", err)
	}
}

func TestLegacyScheduleRuleIsDeviceScoped(t *testing.T) {
	firewall, _, err := desiredEntries([]models.AssignedPolicyDevice{policyTarget("schedule", map[string]interface{}{
		"type": "internet_off", "start_time": "22:00", "end_time": "06:00",
	})})
	if err != nil {
		t.Fatal(err)
	}
	if err := validateFirewallScope(firewall); err != nil {
		t.Fatalf("schedule rule is not scoped: %v", err)
	}
	for _, rule := range firewall {
		if rule.attrs["time"] != "22:00:00-06:00:00" {
			t.Fatalf("unexpected time %q", rule.attrs["time"])
		}
	}
}

func TestLegacyLayer7RuleIsOptIn(t *testing.T) {
	target := policyTarget("website_blacklist", map[string]interface{}{"platforms": []interface{}{"youtube"}})
	firewall, _, err := desiredEntriesWith([]models.AssignedPolicyDevice{target}, legacyOptions{})
	if err != nil {
		t.Fatal(err)
	}
	for comment := range firewall {
		if strings.HasSuffix(comment, "-l7") {
			t.Fatalf("layer7 rule %s created while layer7 is disabled", comment)
		}
	}
}

func marcoOpts() marcoBuildOptions { return marcoBuildOptions{} }

func TestMarcoReconcileIsIdempotentAndPrefixSafe(t *testing.T) {
	groups, members := testMarcoGroup(models.MarcoGroupPolicy{InternetEnabled: boolPtr(false), BlockedWebsites: []string{"telegram"}})
	desired := buildMarcoDesiredState(groups, members, marcoOpts())
	if err := validateFirewallScope(desired.firewall); err != nil {
		t.Fatal(err)
	}

	router := newMemRouter()
	// Foreign rules must never be touched.
	router.tables["/ip/firewall/filter"] = []map[string]string{{".id": "*A", "comment": "hospital-core-allow", "action": "accept"}}

	journal := &changeJournal{}
	if err := applyMarcoDesiredState(router, desired, journal, true, 0); err != nil {
		t.Fatal(err)
	}
	if err := verifyMarcoDesiredState(router, desired, true); err != nil {
		t.Fatalf("verify after apply: %v", err)
	}
	if router.count("/ip/firewall/filter", "hospital-core-allow") != 1 {
		t.Fatal("foreign firewall rule was modified")
	}

	writes := router.writes
	if err := applyMarcoDesiredState(router, desired, &changeJournal{}, true, 0); err != nil {
		t.Fatal(err)
	}
	if router.writes != writes {
		t.Fatalf("second apply wrote %d more entries; reconcile is not idempotent", router.writes-writes)
	}
}

func TestMarcoReconcileCleansDuplicatesAndStaleEntries(t *testing.T) {
	groups, members := testMarcoGroup(models.MarcoGroupPolicy{InternetEnabled: boolPtr(false)})
	desired := buildMarcoDesiredState(groups, members, marcoOpts())
	router := newMemRouter()
	if err := applyMarcoDesiredState(router, desired, &changeJournal{}, true, 0); err != nil {
		t.Fatal(err)
	}
	// Simulate earlier faulty syncs: duplicated rule plus a stale one.
	for _, e := range router.tables["/ip/firewall/filter"] {
		dup := map[string]string{}
		for k, v := range e {
			dup[k] = v
		}
		dup[".id"] = "*DUP"
		router.tables["/ip/firewall/filter"] = append(router.tables["/ip/firewall/filter"], dup)
		break
	}
	router.tables["/ip/firewall/filter"] = append(router.tables["/ip/firewall/filter"], map[string]string{".id": "*OLD", "comment": "nms-marco-oldgroup-net-off", "action": "drop"})

	if err := applyMarcoDesiredState(router, desired, &changeJournal{}, true, 0); err != nil {
		t.Fatal(err)
	}
	if err := verifyMarcoDesiredState(router, desired, true); err != nil {
		t.Fatalf("verify after cleanup: %v", err)
	}
}

func TestMarcoRollbackRestoresRouter(t *testing.T) {
	groups, members := testMarcoGroup(models.MarcoGroupPolicy{InternetEnabled: boolPtr(false), BlockedWebsites: []string{"telegram"}})
	desired := buildMarcoDesiredState(groups, members, marcoOpts())
	router := newMemRouter()
	router.failAdd = func(path string, attrs map[string]string) error {
		if path == "/ip/firewall/filter" && strings.Contains(attrs["comment"], "plat-telegram") {
			return context.DeadlineExceeded
		}
		return nil
	}
	journal := &changeJournal{}
	if err := applyMarcoDesiredState(router, desired, journal, true, 0); err == nil {
		t.Fatal("expected apply to fail")
	}
	if err := journal.rollback(router); err != nil {
		t.Fatal(err)
	}
	for table := range router.tables {
		if n := router.count(table, marcoManagedPrefix); n != 0 {
			t.Fatalf("%d managed entries left in %s after rollback", n, table)
		}
	}
}

func TestMarcoDesiredStateSkipsUnusableMembers(t *testing.T) {
	groups, members := testMarcoGroup(models.MarcoGroupPolicy{InternetEnabled: boolPtr(false)})
	m := members[groups[0].ID][0]
	m.IPAddress = net.ParseIP("0.0.0.0")
	members[groups[0].ID] = []models.MarcoGroupMember{m}
	desired := buildMarcoDesiredState(groups, members, marcoOpts())
	if len(desired.firewall) != 0 || len(desired.addrLists) != 0 {
		t.Fatalf("rules were created for a device without an IP: %d firewall, %d lists", len(desired.firewall), len(desired.addrLists))
	}
	if len(desired.warnings) == 0 {
		t.Fatal("expected a warning for the device without IP")
	}

	_, protectedNet, _ := net.ParseCIDR("192.168.10.50/32")
	m.IPAddress = net.ParseIP("192.168.10.50")
	members[groups[0].ID] = []models.MarcoGroupMember{m}
	desired = buildMarcoDesiredState(groups, members, marcoBuildOptions{protected: []*net.IPNet{protectedNet}})
	if len(desired.firewall) != 0 {
		t.Fatal("rules were created for a protected address")
	}
}

func TestMarcoQueueLimitIsUploadThenDownload(t *testing.T) {
	dl, ul := 10.0, 2.0
	groups, members := testMarcoGroup(models.MarcoGroupPolicy{UnlimitedSpeed: boolPtr(false), DownloadLimitMbps: &dl, UploadLimitMbps: &ul})
	desired := buildMarcoDesiredState(groups, members, marcoOpts())
	if len(desired.queues) != 1 {
		t.Fatalf("expected one queue, got %d", len(desired.queues))
	}
	for _, q := range desired.queues {
		if q.attrs["max-limit"] != "2000000/10000000" {
			t.Fatalf("max-limit %q must be upload/download", q.attrs["max-limit"])
		}
	}
}

func TestAttrMatchesToleratesRouterOSNormalization(t *testing.T) {
	cases := []struct{ key, got, want string }{
		{"address", "1.2.3.4", "1.2.3.4/32"},
		{"time", "08:00:00-17:00:00", "08:00:00-17:00:00"},
		{"days", "tue,mon", "mon,tue"},
		{"disabled", "false", "no"},
		{"max-limit", "2M/10M", "2000000/10000000"},
		{"burst-time", "16s/16s", "16/16"},
		{"src-mac-address", "aa:bb:cc:dd:ee:01", "AA:BB:CC:DD:EE:01"},
	}
	for _, c := range cases {
		if !attrMatches(c.key, c.got, c.want) {
			t.Errorf("%s: %q should match %q", c.key, c.got, c.want)
		}
	}
	if attrMatches("max-limit", "1M/1M", "2000000/10000000") {
		t.Error("different rates must not match")
	}
}

func TestPlatformCatalogDoesNotListSharedCloudRanges(t *testing.T) {
	forbidden := []string{"35.", "104.16.", "104.18.", "151.101.", "130.211.", "104.196."}
	for _, p := range MarcoPlatforms {
		for _, r := range p.IPRanges {
			for _, f := range forbidden {
				if strings.HasPrefix(r, f) {
					t.Errorf("%s lists shared cloud/CDN range %s", p.Key, r)
				}
			}
		}
	}
}

func TestEntryCountLimit(t *testing.T) {
	cfg := &config.Config{RouterMaxManagedEntries: 10}
	if err := validateEntryCount(cfg, 5, 5); err != nil {
		t.Fatal(err)
	}
	if err := validateEntryCount(cfg, 6, 5); err == nil {
		t.Fatal("expected the limit to be enforced")
	}
}

func TestMarcoWithoutPruneOnlyAddsAndLeavesOldEntries(t *testing.T) {
	groups, members := testMarcoGroup(models.MarcoGroupPolicy{InternetEnabled: boolPtr(false)})
	desired := buildMarcoDesiredState(groups, members, marcoOpts())
	router := newMemRouter()
	router.tables["/ip/firewall/filter"] = []map[string]string{
		{".id": "*OLD", "comment": "nms-marco-oldgroup-net-off", "action": "drop", "disabled": "true"},
		{".id": "*OLD2", "comment": "nms-marco-oldgroup-net-off", "action": "drop", "disabled": "true"},
	}

	if err := applyMarcoDesiredState(router, desired, &changeJournal{}, false, 0); err != nil {
		t.Fatal(err)
	}
	if got := router.count("/ip/firewall/filter", "nms-marco-oldgroup-net-off"); got != 2 {
		t.Fatalf("old entries were touched: %d left, want 2", got)
	}
	if err := verifyMarcoDesiredState(router, desired, false); err != nil {
		t.Fatalf("verify without prune must ignore old entries: %v", err)
	}
	for comment := range desired.firewall {
		if router.count("/ip/firewall/filter", comment) != 1 {
			t.Fatalf("desired rule %q was not added exactly once", comment)
		}
	}
}

// YouTube answers from the same Google addresses as Gmail and Translate, so it is
// blocked by name in DNS and never by address, even with the hospital's own list set.
func TestMarcoYouTubeIsBlockedInDNSNeverByAddress(t *testing.T) {
	groups, members := testMarcoGroup(models.MarcoGroupPolicy{BlockedWebsites: []string{"youtube"}})
	opts := marcoBuildOptions{platformLists: map[string]string{"youtube": "collect all youtube ips"}}
	desired := buildMarcoDesiredState(groups, members, opts)

	if len(desired.firewall) != 0 || len(desired.layer7) != 0 {
		t.Fatalf("no firewall rule and no layer7: %v %v", desired.firewall, desired.layer7)
	}
	if err := validateFirewallScope(desired.raw); err != nil {
		t.Fatal(err)
	}
	var words []string
	for comment, rule := range desired.raw {
		if rule.attrs["action"] != "drop" || rule.attrs["chain"] != "prerouting" || rule.attrs["src-address-list"] == "" {
			t.Fatalf("%q is not a scoped drop: %v", comment, rule.attrs)
		}
		if rule.attrs["dst-address-list"] == "collect all youtube ips" {
			t.Fatalf("%q uses the list of shared Google addresses", comment)
		}
		if w := rule.attrs["content"]; w != "" {
			if rule.attrs["protocol"] != "udp" || rule.attrs["dst-port"] != "53" {
				t.Fatalf("%q reads more than DNS: %v", comment, rule.attrs)
			}
			words = append(words, w)
		}
		// Every rule must pass the router session's own check.
		if why := refusedRouterWrite("/ip/firewall/raw/add", attributeWords(rule.attrs)); why != "" {
			t.Fatalf("%q would be refused: %s", comment, why)
		}
	}
	for _, name := range []string{"www.youtube.com", "m.youtube.com", "youtu.be", "youtubei.googleapis.com", "youtube.googleapis.com", "r4---sn-abc.googlevideo.com", "i.ytimg.com", "www.youtube-nocookie.com"} {
		hit := false
		for _, w := range words {
			hit = hit || strings.Contains(name, w)
		}
		if !hit {
			t.Errorf("%s is not blocked by %v", name, words)
		}
	}
	for _, name := range []string{"mail.google.com", "gmail.com", "translate.google.com", "translate.googleapis.com", "firebaseinstallations.googleapis.com", "www.googleapis.com", "www.google.com", "drive.google.com", "accounts.google.com"} {
		for _, w := range words {
			if strings.Contains(name, w) {
				t.Errorf("%s must keep working but contains %q", name, w)
			}
		}
	}
	if desired.raw["nms-marco-aaaaaaaa-dns-tls"].attrs["dst-port"] != "853" || desired.raw["nms-marco-aaaaaaaa-dns-https-tcp"].attrs["dst-address-list"] != marcoEncryptedDNSList {
		t.Errorf("encrypted DNS must be closed for the group: %v", desired.raw)
	}
	if len(desired.warnings) != 0 {
		t.Fatalf("unexpected warnings: %v", desired.warnings)
	}
}

func TestMarcoRawRulesApplyVerifyAndGoAway(t *testing.T) {
	groups, members := testMarcoGroup(models.MarcoGroupPolicy{BlockedWebsites: []string{"youtube"}})
	desired := buildMarcoDesiredState(groups, members, marcoOpts())
	router := newMemRouter()
	if err := applyMarcoDesiredState(router, desired, &changeJournal{}, true, 0); err != nil {
		t.Fatal(err)
	}
	if err := verifyMarcoDesiredState(router, desired, true); err != nil {
		t.Fatal(err)
	}
	if router.count("/ip/firewall/raw", "nms-marco-aaaaaaaa-dns-youtu") != 1 {
		t.Fatal("the DNS rule is not on the router")
	}
	// Taking the block off removes all of it.
	groups, members = testMarcoGroup(models.MarcoGroupPolicy{InternetEnabled: boolPtr(true)})
	if err := applyMarcoDesiredState(router, buildMarcoDesiredState(groups, members, marcoOpts()), &changeJournal{}, true, 0); err != nil {
		t.Fatal(err)
	}
	if router.count("/ip/firewall/raw", "nms-marco-aaaaaaaa-dns-youtu") != 0 {
		t.Fatal("the DNS rule stayed after the block was removed")
	}
}

func TestMarcoPlatformBlocksThroughConfiguredRouterList(t *testing.T) {
	groups, members := testMarcoGroup(models.MarcoGroupPolicy{BlockedWebsites: []string{"telegram"}})
	opts := marcoBuildOptions{platformLists: map[string]string{"telegram": "collect all telegram ips"}}
	desired := buildMarcoDesiredState(groups, members, opts)
	if err := validateFirewallScope(desired.firewall); err != nil {
		t.Fatal(err)
	}

	var found bool
	for comment, rule := range desired.firewall {
		if rule.attrs["dst-address-list"] != "collect all telegram ips" {
			continue
		}
		found = true
		if rule.attrs["action"] != "drop" || rule.attrs["chain"] != "forward" || rule.attrs["src-address-list"] == "" {
			t.Fatalf("rule %q is not a scoped forward drop: %v", comment, rule.attrs)
		}
	}
	if !found {
		t.Fatal("no rule uses the configured address list")
	}
	for comment := range desired.addrLists {
		if strings.HasPrefix(comment, marcoPlatListPrefix) {
			t.Fatalf("the configured list replaces built-in ranges, got %q", comment)
		}
	}
	if len(desired.warnings) != 0 {
		t.Fatalf("unexpected warnings: %v", desired.warnings)
	}
}

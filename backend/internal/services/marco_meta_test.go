package services

import (
	"context"
	"errors"
	"net"
	"time"

	"testing"

	"github.com/hospital/nms-backend/internal/models"
)

func TestMetaSpeedLimitMarksMetaDownloadsAndCapsEachDevice(t *testing.T) {
	kbps := 256
	groups := groupWith(models.MarcoGroupPolicy{MetaSpeedKbps: &kbps})
	d := buildMarcoDesiredState(groups, membersOf(member(d1, "AA:AA:AA:00:00:01", "172.16.0.10")), marcoBuildOptions{})

	mark := d.mangle["nms-marco-aaaaaaaa-meta"]
	if mark.attrs["src-address-list"] != marcoMetaList || mark.attrs["dst-address-list"] != "nms-marco-src-aaaaaaaa" ||
		mark.attrs["action"] != "mark-packet" || mark.attrs["new-packet-mark"] != "nms-marco-meta-aaaaaaaa" || mark.attrs["passthrough"] != "no" {
		t.Fatalf("mangle = %v (downloads from Meta to the group must be marked)", mark.attrs)
	}
	tree := d.trees["nms-marco-aaaaaaaa-meta"]
	if tree.attrs["packet-mark"] != "nms-marco-meta-aaaaaaaa" || tree.attrs["queue"] != "nms-marco-meta-256k" || tree.attrs["parent"] != marcoLANParent {
		t.Fatalf("tree = %v", tree.attrs)
	}
	if d.queueTypes["nms-marco-meta-256k"] != "256000" {
		t.Fatalf("queue types = %v", d.queueTypes)
	}
	n := 0
	for _, e := range d.addrLists {
		if e.attrs["list"] == marcoMetaList {
			n++
			if e.attrs["address"] == "157.240.0.0/16" {
				n += 100
			}
		}
	}
	if n != len(metaIPRanges)+100 {
		t.Errorf("Meta list has %d entries", n)
	}
	if len(d.firewall)+len(d.raw) != 0 {
		t.Errorf("a speed limit blocks nothing: firewall %v raw %v", d.firewall, d.raw)
	}

	d.setLANParent("ether5")
	if d.trees["nms-marco-aaaaaaaa-meta"].attrs["parent"] != "ether5" {
		t.Error("the tree must hang on the LAN interface")
	}
}

func TestMetaSpeedLimitIsLeftOutWithoutALANInterface(t *testing.T) {
	kbps := 128
	d := buildMarcoDesiredState(groupWith(models.MarcoGroupPolicy{MetaSpeedKbps: &kbps}), membersOf(member(d1, "AA:AA:AA:00:00:01", "172.16.0.10")), marcoBuildOptions{})
	d.setLANParent("")
	if len(d.trees)+len(d.mangle)+len(d.queueTypes) != 0 || len(d.warnings) == 0 {
		t.Fatalf("trees %v mangle %v types %v warnings %v", d.trees, d.mangle, d.queueTypes, d.warnings)
	}
}

func TestMetaSpeedLimitAppliesAndCleansUpOnTheRouter(t *testing.T) {
	kbps := 256
	d := buildMarcoDesiredState(groupWith(models.MarcoGroupPolicy{MetaSpeedKbps: &kbps}), membersOf(member(d1, "AA:AA:AA:00:00:01", "172.16.0.10")), marcoBuildOptions{})
	d.setLANParent("ether5")
	router := newMemRouter()
	router.tables["/queue/type"] = []map[string]string{{".id": "*6", "name": "facebook", "kind": "pcq"}}
	if err := applyMarcoDesiredState(router, d, &changeJournal{}, true, 0); err != nil {
		t.Fatal(err)
	}
	if err := verifyMarcoDesiredState(router, d, true); err != nil {
		t.Fatal(err)
	}
	if router.count("/queue/tree", "nms-marco-aaaaaaaa-meta") != 1 || router.count("/ip/firewall/mangle", "nms-marco-aaaaaaaa-meta") != 1 {
		t.Fatal("tree and mark must be on the router")
	}
	types := map[string]string{}
	for _, r := range router.tables["/queue/type"] {
		types[r["name"]] = r["pcq-rate"]
	}
	if types["nms-marco-meta-256k"] != "256000" || len(types) != 2 {
		t.Fatalf("queue types = %v (the hospital's own must stay)", types)
	}

	// The limit taken off: everything it added goes, the hospital's type stays.
	empty := buildMarcoDesiredState(groupWith(models.MarcoGroupPolicy{BlockedWebsites: []string{"telegram"}}), membersOf(member(d1, "AA:AA:AA:00:00:01", "172.16.0.10")), marcoBuildOptions{})
	if err := applyMarcoDesiredState(router, empty, &changeJournal{}, true, 0); err != nil {
		t.Fatal(err)
	}
	if len(router.tables["/queue/tree"])+len(router.tables["/ip/firewall/mangle"]) != 0 || len(router.tables["/queue/type"]) != 1 {
		t.Fatalf("left behind: trees %v mangle %v types %v", router.tables["/queue/tree"], router.tables["/ip/firewall/mangle"], router.tables["/queue/type"])
	}
}

func TestAChangedMetaSpeedKeepsTheOldTypeUntilTheChangeHolds(t *testing.T) {
	build := func(kbps int) marcoDesiredState {
		d := buildMarcoDesiredState(groupWith(models.MarcoGroupPolicy{MetaSpeedKbps: &kbps}), membersOf(member(d1, "AA:AA:AA:00:00:01", "172.16.0.10")), marcoBuildOptions{})
		d.setLANParent("ether5")
		return d
	}
	router := newMemRouter()
	if err := applyMarcoDesiredState(router, build(256), &changeJournal{}, true, 0); err != nil {
		t.Fatal(err)
	}
	journal := &changeJournal{}
	if _, err := applyMarcoCore(router, build(128), journal, true, 0, true); err != nil {
		t.Fatal(err)
	}
	// The router stopped answering before the change was confirmed: it is undone.
	if err := journal.rollback(router); err != nil {
		t.Fatal(err)
	}
	names := map[string]bool{}
	for _, r := range router.tables["/queue/type"] {
		names[r["name"]] = true
	}
	tree := router.tables["/queue/tree"][0]
	if tree["queue"] != "nms-marco-meta-256k" || !names["nms-marco-meta-256k"] || names["nms-marco-meta-128k"] {
		t.Fatalf("after the undo the tree uses %q and the types are %v", tree["queue"], names)
	}
}

func TestMetaCachesAtTheProviderJoinTheMetaList(t *testing.T) {
	f := newMetaCacheFinder()
	f.lookupIP = func(_ context.Context, host string) ([]net.IP, error) {
		switch host {
		case "scontent.fcai30-1.fna.fbcdn.net":
			return []net.IP{net.ParseIP("196.204.75.24")}, nil
		case "scontent.fcai1-1.fna.fbcdn.net":
			return []net.IP{net.ParseIP("157.240.196.35")}, nil // already Meta's own
		}
		return nil, errors.New("no such host")
	}
	nets := f.networks(time.Now())
	if len(nets) != 1 || nets[0] != "196.204.75.0/24" {
		t.Fatalf("networks = %v", nets)
	}

	kbps := 128
	d := buildMarcoDesiredState(groupWith(models.MarcoGroupPolicy{MetaSpeedKbps: &kbps}), membersOf(member(d1, "AA:AA:AA:00:00:01", "172.16.0.10")), marcoBuildOptions{metaCaches: nets})
	found := false
	for _, e := range d.addrLists {
		if e.attrs["list"] == marcoMetaList && e.attrs["address"] == "196.204.75.0/24" {
			found = true
		}
	}
	if !found {
		t.Error("the provider's Meta cache must be slowed too")
	}

	// A later look that finds nothing keeps what was found, for a month.
	f.lookupIP = func(context.Context, string) ([]net.IP, error) { return nil, errors.New("timeout") }
	f.find(time.Now())
	if got := f.networks(time.Now()); len(got) != 1 {
		t.Errorf("after an empty look: %v", got)
	}
	if got := f.networks(time.Now().Add(metaCacheKeep + time.Hour)); len(got) != 0 {
		t.Errorf("after a month: %v", got)
	}
}

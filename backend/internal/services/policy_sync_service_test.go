package services

import (
	"errors"
	"net"
	"reflect"
	"strings"
	"testing"

	"github.com/google/uuid"
	"github.com/hospital/nms-backend/internal/models"
)

type recordedCommand struct {
	path  string
	attrs []string
}

type fakeRouter struct {
	existing []map[string]string
	commands []recordedCommand
}

func (f *fakeRouter) Command(path string, attrs ...string) ([]map[string]string, error) {
	f.commands = append(f.commands, recordedCommand{path: path, attrs: attrs})
	if strings.HasSuffix(path, "/print") {
		return f.existing, nil
	}
	return nil, nil
}

func (f *fakeRouter) Close() error { return nil }

func policyTarget(policyType string, config map[string]interface{}) models.AssignedPolicyDevice {
	mac := "AA:BB:CC:DD:EE:FF"
	return models.AssignedPolicyDevice{
		Policy: models.Policy{ID: uuid.MustParse("11111111-1111-1111-1111-111111111111"), PolicyType: policyType, Config: config, IsActive: true},
		Device: models.Device{ID: uuid.MustParse("22222222-2222-2222-2222-222222222222"), IPAddress: net.ParseIP("192.0.2.10"), MACAddress: &mac},
	}
}

func TestDesiredEntriesScopesInternetBlockToDeviceIdentity(t *testing.T) {
	firewall, queues, err := desiredEntries([]models.AssignedPolicyDevice{policyTarget("internet_access", map[string]interface{}{"enabled": false})})
	if err != nil {
		t.Fatal(err)
	}
	if len(queues) != 0 || len(firewall) != 1 {
		t.Fatalf("unexpected desired entries: firewall=%d queues=%d", len(firewall), len(queues))
	}
	for _, entry := range firewall {
		if entry.attrs["src-address"] != "192.0.2.10/32" || entry.attrs["src-mac-address"] != "AA:BB:CC:DD:EE:FF" || entry.attrs["chain"] != "forward" {
			t.Fatalf("Internet block is not safely device-scoped: %#v", entry.attrs)
		}
	}
}

func TestDesiredEntriesBuildsRouterOSUploadDownloadOrder(t *testing.T) {
	_, queues, err := desiredEntries([]models.AssignedPolicyDevice{policyTarget("bandwidth_limit", map[string]interface{}{"upload_limit_bps": float64(1000), "download_limit_bps": float64(2000)})})
	if err != nil {
		t.Fatal(err)
	}
	for _, entry := range queues {
		if entry.attrs["target"] != "192.0.2.10/32" || entry.attrs["max-limit"] != "1000/2000" {
			t.Fatalf("unexpected queue: %#v", entry.attrs)
		}
	}
}

func TestDesiredEntriesRejectsUnsupportedWebsitePolicy(t *testing.T) {
	_, _, err := desiredEntries([]models.AssignedPolicyDevice{policyTarget("website_blacklist", map[string]interface{}{"domains": []interface{}{"example.com"}})})
	if !errors.Is(err, ErrPolicyUnsupported) {
		t.Fatalf("expected explicit unsupported error, got %v", err)
	}
}

func TestReconcileEntriesUsesSeparateAttributeWordsAndIsIdempotent(t *testing.T) {
	comment := "nms-policy-rule"
	desired := map[string]desiredRouterEntry{comment: {path: "/queue/simple", attrs: map[string]string{"name": comment, "target": "192.0.2.10/32", "max-limit": "1000/2000", "comment": comment}}}
	router := &fakeRouter{existing: []map[string]string{{".id": "*1", "name": comment, "target": "192.0.2.10/32", "max-limit": "1000/2000", "comment": comment}}}
	if err := reconcileEntries(router, "/queue/simple", desired); err != nil {
		t.Fatal(err)
	}
	want := []recordedCommand{{path: "/queue/simple/print", attrs: []string{"?comment=nms-policy-"}}}
	if !reflect.DeepEqual(router.commands, want) {
		t.Fatalf("idempotent reconciliation sent mutations: %#v", router.commands)
	}

	router = &fakeRouter{}
	if err := reconcileEntries(router, "/queue/simple", desired); err != nil {
		t.Fatal(err)
	}
	if len(router.commands) != 2 || router.commands[1].path != "/queue/simple/add" {
		t.Fatalf("expected framed add command, got %#v", router.commands)
	}
	for _, word := range router.commands[1].attrs {
		if !strings.HasPrefix(word, "=") || strings.Contains(word, " /queue/") {
			t.Fatalf("invalid RouterOS attribute framing %q", word)
		}
	}
}

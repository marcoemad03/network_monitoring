package services

import (
	"testing"
	"time"

	"github.com/google/uuid"
	"github.com/hospital/nms-backend/internal/config"
)

func TestComputeRate(t *testing.T) {
	t0 := time.Now()
	prev := counterReading{rx: 1_000_000, tx: 200_000, at: t0}

	r := computeRate(prev, counterReading{rx: 1_000_000 + 1_875_000, tx: 200_000 + 250_000, at: t0.Add(15 * time.Second)}, time.Minute)
	if !r.valid || r.gap {
		t.Fatalf("expected a normal reading: %+v", r)
	}
	if r.rxBps != 1_000_000 || r.txBps != 133_333 {
		t.Fatalf("speeds: down %d up %d", r.rxBps, r.txBps)
	}
	if r.rxDelta != 1_875_000 || r.txDelta != 250_000 {
		t.Fatalf("deltas: %+v", r)
	}

	// Router rebooted: counters went backwards. Nothing is counted.
	if r := computeRate(prev, counterReading{rx: 10, tx: 10, at: t0.Add(15 * time.Second)}, time.Minute); r.valid {
		t.Fatalf("a counter reset must not count: %+v", r)
	}

	// Long gap (server was down): bytes still count, but there is no speed.
	r = computeRate(prev, counterReading{rx: 5_000_000, tx: 300_000, at: t0.Add(2 * time.Hour)}, time.Minute)
	if !r.valid || !r.gap || r.rxBps != 0 || r.rxDelta != 4_000_000 {
		t.Fatalf("gap reading: %+v", r)
	}

	// Same instant or going back in time is ignored.
	if r := computeRate(prev, counterReading{rx: 2_000_000, tx: 300_000, at: t0}, time.Minute); r.valid {
		t.Fatalf("zero interval must be ignored: %+v", r)
	}
}

func TestWANInterfaceFromRoutes(t *testing.T) {
	cases := []struct {
		name   string
		routes []map[string]string
		want   string
	}{
		{"reachable via interface", []map[string]string{
			{"dst-address": "0.0.0.0/0", "gateway": "41.1.1.1", "gateway-status": "41.1.1.1 reachable via  ether1", "distance": "1", "active": "true"},
		}, "ether1"},
		{"prefers the active route over a backup", []map[string]string{
			{"dst-address": "0.0.0.0/0", "gateway": "10.9.9.1", "gateway-status": "10.9.9.1 reachable via  ether2", "distance": "2", "active": "false"},
			{"dst-address": "0.0.0.0/0", "gateway": "41.1.1.1", "gateway-status": "41.1.1.1 reachable via  ether1", "distance": "1", "active": "true"},
		}, "ether1"},
		{"pppoe gateway is the interface name", []map[string]string{
			{"dst-address": "0.0.0.0/0", "gateway": "pppoe-out1", "gateway-status": "pppoe-out1 reachable", "distance": "1", "active": "true"},
		}, "pppoe-out1"},
		{"ignores disabled and non-default routes", []map[string]string{
			{"dst-address": "0.0.0.0/0", "gateway": "41.1.1.1", "gateway-status": "41.1.1.1 reachable via  ether1", "disabled": "true"},
			{"dst-address": "10.0.0.0/8", "gateway": "10.1.1.1", "gateway-status": "10.1.1.1 reachable via  ether3"},
		}, ""},
		{"no routes", nil, ""},
	}
	for _, c := range cases {
		if got := wanInterfaceFromRoutes(c.routes); got != c.want {
			t.Errorf("%s: got %q want %q", c.name, got, c.want)
		}
	}
}

func TestParseRouterUptimeAndHealth(t *testing.T) {
	if got := parseRouterUptime("6d21h6m27s"); got != 6*86400+21*3600+6*60+27 {
		t.Fatalf("uptime = %d", got)
	}
	if got := parseRouterUptime("1w2d"); got != 9*86400 {
		t.Fatalf("weeks = %d", got)
	}
	h := parseRouterHealth(map[string]string{
		"board-name": "RB2011UiAS", "version": "6.49.23 (stable)", "cpu-load": "46",
		"total-memory": "134217728", "free-memory": "91068416", "uptime": "1h",
	})
	if h.CPULoadPercent != 46 || h.UptimeSeconds != 3600 || h.Board != "RB2011UiAS" {
		t.Fatalf("health: %+v", h)
	}
	if h.MemoryUsedPercent < 32 || h.MemoryUsedPercent > 33 {
		t.Fatalf("memory used = %.2f", h.MemoryUsedPercent)
	}
}

type cannedRouter struct {
	answers map[string][]map[string]string
}

func (f cannedRouter) Command(path string, _ ...string) ([]map[string]string, error) {
	return f.answers[path], nil
}
func (cannedRouter) Close() error { return nil }

func TestMeasureReadsTheDetectedWANInterface(t *testing.T) {
	s := &RouterTelemetryService{cfg: &config.Config{}, states: map[uuid.UUID]*telemetryState{}}
	router := cannedRouter{answers: map[string][]map[string]string{
		"/system/resource/print": {{"cpu-load": "40", "total-memory": "100", "free-memory": "50", "uptime": "2m", "version": "6.49.23", "board-name": "RB2011"}},
		"/ip/route/print":        {{"dst-address": "0.0.0.0/0", "gateway": "41.1.1.1", "gateway-status": "41.1.1.1 reachable via  ether1", "distance": "1", "active": "true"}},
		"/interface/print": {
			{"name": "ether2", "rx-byte": "999", "tx-byte": "999", "running": "true"},
			{"name": "ether1", "rx-byte": "123456", "tx-byte": "7890", "running": "true"},
		},
	}}

	snap, reading, err := s.measure(router, uuid.New())
	if err != nil {
		t.Fatal(err)
	}
	if snap.Interface != "ether1" || reading.rx != 123456 || reading.tx != 7890 || !snap.Running {
		t.Fatalf("snapshot %+v reading %+v", snap, reading)
	}
	if snap.Router.CPULoadPercent != 40 {
		t.Fatalf("router health missing: %+v", snap.Router)
	}

	// A configured interface wins and a missing one is an explicit error.
	s.cfg.RouterWANInterface = "ether9"
	if _, _, err := s.measure(router, uuid.New()); err == nil {
		t.Fatal("expected an error for an unknown interface")
	}
}

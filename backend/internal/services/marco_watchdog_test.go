package services

import (
	"context"
	"errors"
	"strings"
	"testing"
	"time"

	"github.com/google/uuid"
	"github.com/hospital/nms-backend/internal/config"
	"github.com/hospital/nms-backend/internal/models"
)

// healthRouter is a router fake with a clock, a CPU reading per call and a point
// after which it stops answering.
type healthRouter struct {
	rowRouter
	cpu       []string
	cpuCalls  int
	deadAfter int // resource reads answered before it goes silent; 0 means never
}

func (f *healthRouter) Command(path string, attrs ...string) ([]map[string]string, error) {
	switch path {
	case "/system/clock/print":
		f.commands = append(f.commands, recordedCommand{path: path})
		return []map[string]string{{"date": "nov/03/2026", "time": "23:58:30"}}, nil
	case "/system/resource/print":
		f.cpuCalls++
		if f.deadAfter > 0 && f.cpuCalls > f.deadAfter {
			return nil, errors.New("i/o timeout")
		}
		i := f.cpuCalls - 1
		if i >= len(f.cpu) {
			i = len(f.cpu) - 1
		}
		return []map[string]string{{"cpu-load": f.cpu[i]}}, nil
	}
	return f.rowRouter.Command(path, attrs...)
}

func (f *healthRouter) did(path string) []recordedCommand {
	var out []recordedCommand
	for _, c := range f.commands {
		if c.path == path {
			out = append(out, c)
		}
	}
	return out
}

func noWait(time.Duration) {}

func guardedService(dial func(*models.VendorIntegration, *config.Config) (routerCommander, error)) *MarcoSyncService {
	return &MarcoSyncService{cfg: &config.Config{RouterPruneStale: true}, wait: noWait, dialRouter: dial}
}

func oneRule() marcoDesiredState {
	d := marcoDesiredState{firewall: map[string]desiredRouterEntry{}, queues: map[string]desiredRouterEntry{}, addrLists: map[string]desiredRouterEntry{}, layer7: map[string]desiredRouterEntry{}}
	d.addFirewall("nms-marco-aaaaaaaa-sites", map[string]string{"chain": "forward", "action": "drop", "src-address-list": "s", "dst-address-list": "d"}, true)
	return d
}

func TestSessionRefusesEverythingThatReadsPacketContents(t *testing.T) {
	for _, write := range []bool{true, false} {
		inner := &rowRouter{}
		sess := newRouterSession(context.Background(), inner, write, nil)
		for _, c := range []struct {
			path string
			word string
		}{
			{"/ip/firewall/filter/add", "=layer7-protocol=x"},
			{"/ip/firewall/filter/set", "=tls-host=*youtube*"},
			{"/ip/firewall/mangle/add", "=content=youtube"},
			{"/ip/firewall/raw/add", "=content=youtube"},
			{"/ip/firewall/layer7-protocol/add", "=name=x"},
			{"/ip/firewall/layer7-protocol/set", "=regexp=.*"},
		} {
			if _, err := sess.Command(c.path, c.word); err == nil || !strings.Contains(err.Error(), "refusing") {
				t.Errorf("%s %s: err = %v", c.path, c.word, err)
			}
		}
		if len(inner.commands) != 0 || len(sess.Planned()) != 0 {
			t.Errorf("a refused write went through: %v %v", inner.commands, sess.Planned())
		}
		// Clearing such rules off the router must keep working.
		for _, p := range []string{"/ip/firewall/layer7-protocol/remove", "/ip/firewall/filter/remove"} {
			if _, err := sess.Command(p, "=.id=*1"); err != nil {
				t.Errorf("%s: %v", p, err)
			}
		}
		if _, err := sess.Command("/ip/firewall/filter/add", "=action=drop", "=src-address-list=s"); err != nil {
			t.Errorf("an ordinary rule was refused: %v", err)
		}
		if _, err := sess.Command("/ip/firewall/raw/add", "=protocol=udp", "=dst-port=53", "=content=youtu"); err != nil {
			t.Errorf("a word match on DNS questions was refused: %v", err)
		}
		if _, err := sess.Command("/ip/firewall/raw/add", "=protocol=tcp", "=dst-port=443", "=content=youtu"); err == nil {
			t.Error("a word match on web traffic must be refused")
		}
		if _, err := sess.Command("/ip/firewall/layer7-protocol/print"); err != nil {
			t.Errorf("reading was refused: %v", err)
		}
	}
}

func TestDeadmanRunsFiveMinutesLaterOnTheRoutersClockAndOnlyTouchesItsOwn(t *testing.T) {
	f := &healthRouter{rowRouter: rowRouter{rows: map[string][]map[string]string{"/system/scheduler": {
		{".id": "*1", "name": deadmanName},
		{".id": "*2", "name": "hospital-backup"},
	}}}}
	if err := armDeadman(f); err != nil {
		t.Fatal(err)
	}
	removed := f.did("/system/scheduler/remove")
	if len(removed) != 1 || removed[0].attrs[0] != "=.id=*1" {
		t.Errorf("only an older timer may be replaced: %v", removed)
	}
	added := f.did("/system/scheduler/add")
	if len(added) != 1 {
		t.Fatalf("added = %v", added)
	}
	words := strings.Join(added[0].attrs, " ")
	// 23:58:30 plus five minutes crosses midnight.
	if !strings.Contains(words, "=start-date=nov/04/2026") || !strings.Contains(words, "=start-time=00:03:30") {
		t.Errorf("start = %s", words)
	}
	if strings.Count(deadmanScript, " remove ") != 4 || strings.Count(deadmanScript, `comment~"^nms-marco-"`) != 3 || !strings.Contains(deadmanScript, `name="`+deadmanName+`"`) {
		t.Errorf("the job must remove only nms-marco rules, queues and itself: %s", deadmanScript)
	}
}

func TestArmDeadmanFailsWhenTheClockCannotBeRead(t *testing.T) {
	f := &rowRouter{rows: map[string][]map[string]string{"/system/clock": {{"date": "2026-11-03", "time": "10:00:00"}}}}
	if err := armDeadman(f); err == nil {
		t.Fatal("an unknown date format must stop the change")
	}
	for _, c := range f.commands {
		if c.path == "/system/scheduler/add" {
			t.Fatal("no timer may be set at a guessed time")
		}
	}
}

func TestWatchRouter(t *testing.T) {
	cases := []struct {
		name    string
		router  *healthRouter
		before  int
		wantErr string
	}{
		{"healthy", &healthRouter{cpu: []string{"60"}}, 50, ""},
		{"one missed answer is forgiven", &healthRouter{cpu: []string{"60"}, deadAfter: 5}, 50, ""},
		{"stops answering", &healthRouter{cpu: []string{"60"}, deadAfter: 2}, 50, "stopped answering"},
		{"CPU goes to full and stays", &healthRouter{cpu: []string{"100"}}, 50, "from 50% to 100%"},
		{"CPU was already full", &healthRouter{cpu: []string{"100"}}, 98, ""},
		{"CPU spikes and recovers", &healthRouter{cpu: []string{"100", "100", "40", "100"}}, 50, ""},
	}
	for _, c := range cases {
		err := watchRouter(c.router, c.before, noWait)
		if c.wantErr == "" && err != nil {
			t.Errorf("%s: %v", c.name, err)
		}
		if c.wantErr != "" && (err == nil || !strings.Contains(err.Error(), c.wantErr)) {
			t.Errorf("%s: err = %v", c.name, err)
		}
	}
}

func TestGuardedApplyKeepsTheTimerOutOfSyncsThatChangeNothing(t *testing.T) {
	d := oneRule()
	rule := map[string]string{".id": "*9"}
	for k, v := range d.firewall["nms-marco-aaaaaaaa-sites"].attrs {
		rule[k] = v
	}
	f := &healthRouter{cpu: []string{"50"}, rowRouter: rowRouter{rows: map[string][]map[string]string{"/ip/firewall/filter": {rule}}}}
	s := guardedService(nil)
	sess := newRouterSession(context.Background(), f, true, nil)
	if _, err := s.applyGuarded(context.Background(), uuid.New(), nil, sess, d, 60); err != nil {
		t.Fatal(err)
	}
	if len(f.did("/system/scheduler/add")) != 0 {
		t.Error("nothing changed, so the router must not get a timer")
	}
}

func TestGuardedApplyCancelsTheTimerOnlyAfterTheRouterStayedHealthy(t *testing.T) {
	// memRouter holds the rules for the verify step.
	m := newMemRouter()
	f := &guardedMem{memRouter: m, cpu: "50"}
	s := guardedService(nil)
	sess := newRouterSession(context.Background(), f, true, nil)
	if _, err := s.applyGuarded(context.Background(), uuid.New(), nil, sess, oneRule(), 60); err != nil {
		t.Fatal(err)
	}
	if f.armedAt < 0 || f.ruleAt < f.armedAt {
		t.Errorf("the timer must be set before the first rule: timer at %d, rule at %d", f.armedAt, f.ruleAt)
	}
	if f.disarmedAt < f.ruleAt || f.reads < watchRounds {
		t.Errorf("the timer must stay until the watch is over: cancelled at %d, %d reads", f.disarmedAt, f.reads)
	}
}

func TestGuardedApplyUndoesABadChangeAndPausesUntilSomeonePressesUpdate(t *testing.T) {
	m := newMemRouter()
	f := &guardedMem{memRouter: m, cpu: "50", thenCPU: "100"}
	s := guardedService(nil)
	org := uuid.New()
	sess := newRouterSession(context.Background(), f, true, nil)
	_, err := s.applyGuarded(context.Background(), org, nil, sess, oneRule(), 60)
	if err == nil || !strings.Contains(err.Error(), "rolled back") {
		t.Fatalf("err = %v", err)
	}
	if m.count("/ip/firewall/filter", "nms-marco-aaaaaaaa-sites") != 0 {
		t.Error("the rule must be gone after a bad change")
	}
	if f.disarmedAt < 0 {
		t.Error("after a clean undo the timer is not needed")
	}

	// A background sync (a device got a new address, say) must not put it back.
	f = &guardedMem{memRouter: m, cpu: "50"}
	sess = newRouterSession(context.Background(), f, true, nil)
	_, err = s.applyGuarded(context.Background(), org, nil, sess, oneRule(), 60)
	if err == nil || !strings.Contains(err.Error(), "paused") {
		t.Fatalf("err = %v", err)
	}
	if m.count("/ip/firewall/filter", "nms-marco-aaaaaaaa-sites") != 0 || f.armedAt >= 0 {
		t.Error("nothing may be written while paused")
	}

	s.ResumeWrites(org)
	f = &guardedMem{memRouter: m, cpu: "50"}
	sess = newRouterSession(context.Background(), f, true, nil)
	if _, err = s.applyGuarded(context.Background(), org, nil, sess, oneRule(), 60); err != nil {
		t.Fatalf("after someone pressed Update: %v", err)
	}
	if m.count("/ip/firewall/filter", "nms-marco-aaaaaaaa-sites") != 1 {
		t.Error("the rule must be applied after resuming")
	}
}

func TestGuardedApplyLeavesTheTimerWhenTheRouterCannotBeReached(t *testing.T) {
	m := newMemRouter()
	f := &guardedMem{memRouter: m, cpu: "50", dieAfterApply: true}
	s := guardedService(func(*models.VendorIntegration, *config.Config) (routerCommander, error) {
		return nil, errors.New("i/o timeout")
	})
	sess := newRouterSession(context.Background(), f, true, nil)
	_, err := s.applyGuarded(context.Background(), uuid.New(), nil, sess, oneRule(), 60)
	if err == nil || !strings.Contains(err.Error(), "safety timer removes") {
		t.Fatalf("err = %v", err)
	}
	if f.disarmedAt >= 0 {
		t.Error("the timer is the only thing left that can clean up, it must stay")
	}
}

func TestGuardedApplyReconnectsToUndoWhenTheConnectionDied(t *testing.T) {
	m := newMemRouter()
	f := &guardedMem{memRouter: m, cpu: "50", dieAfterApply: true}
	fresh := &guardedMem{memRouter: m, cpu: "50"}
	s := guardedService(func(*models.VendorIntegration, *config.Config) (routerCommander, error) {
		return fresh, nil
	})
	sess := newRouterSession(context.Background(), f, true, nil)
	_, err := s.applyGuarded(context.Background(), uuid.New(), nil, sess, oneRule(), 60)
	if err == nil || !strings.Contains(err.Error(), "rolled back") {
		t.Fatalf("err = %v", err)
	}
	if m.count("/ip/firewall/filter", "nms-marco-aaaaaaaa-sites") != 0 {
		t.Error("the rule must be gone once the router can be reached again")
	}
}

func TestGuardedApplyInDryRunWritesNothing(t *testing.T) {
	m := newMemRouter()
	f := &guardedMem{memRouter: m, cpu: "50"}
	s := guardedService(nil)
	sess := newRouterSession(context.Background(), f, false, nil)
	if _, err := s.applyGuarded(context.Background(), uuid.New(), nil, sess, oneRule(), 60); err != nil {
		t.Fatal(err)
	}
	if f.armedAt >= 0 || m.count("/ip/firewall/filter", "nms-marco-aaaaaaaa-sites") != 0 || len(sess.Planned()) == 0 {
		t.Errorf("dry run: timer at %d, planned %v", f.armedAt, sess.Planned())
	}
}

// guardedMem adds a clock, CPU readings and a scheduler table to memRouter, and
// notes the order things happened in.
type guardedMem struct {
	*memRouter
	cpu, thenCPU  string
	dieAfterApply bool

	step                   int
	armedAt, ruleAt        int
	disarmedAt, reads      int
	started, applied, dead bool
}

func (g *guardedMem) Command(path string, attrs ...string) ([]map[string]string, error) {
	if !g.started {
		g.started, g.armedAt, g.ruleAt, g.disarmedAt = true, -1, -1, -1
	}
	g.step++
	// It goes silent during the watch, so the rule stays on and nothing can reach it.
	if g.dieAfterApply && g.applied && path == "/system/resource/print" {
		g.dead = true
	}
	if g.dead {
		return nil, errors.New("i/o timeout")
	}
	switch path {
	case "/system/clock/print":
		return []map[string]string{{"date": "nov/03/2026", "time": "10:00:00"}}, nil
	case "/system/resource/print":
		g.reads++
		cpu := g.cpu
		if g.applied && g.thenCPU != "" {
			cpu = g.thenCPU
		}
		return []map[string]string{{"cpu-load": cpu}}, nil
	case "/system/scheduler/print":
		if g.armedAt >= 0 && g.disarmedAt < 0 {
			return []map[string]string{{".id": "*S", "name": deadmanName}}, nil
		}
		return nil, nil
	case "/system/scheduler/add":
		g.armedAt = g.step
		return nil, nil
	case "/system/scheduler/remove":
		g.disarmedAt = g.step
		return nil, nil
	case "/ip/firewall/filter/add":
		g.ruleAt, g.applied = g.step, true
	}
	return g.memRouter.Command(path, attrs...)
}

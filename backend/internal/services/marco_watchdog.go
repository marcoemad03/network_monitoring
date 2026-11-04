package services

import (
	"context"
	"fmt"
	"strconv"
	"strings"
	"time"

	"github.com/google/uuid"
	"github.com/hospital/nms-backend/internal/models"
)

// A change to the live router is guarded on the router itself: before it, a
// scheduler job is set that removes every nms-marco- rule and queue in a few
// minutes. The sync cancels the job only after the router stayed healthy for a
// while. If a rule makes the router stop answering, nothing outside can undo it, but
// the job still runs there, so the hospital gets its internet back without anyone
// logging in. Every way this can go wrong removes rules, none adds any.
const (
	deadmanName  = "nms-marco-deadman"
	deadmanAfter = 5 * time.Minute

	watchRounds  = 6
	watchEvery   = 5 * time.Second
	watchCPUHigh = 95
)

const deadmanScript = `:log warning "NMS: change not confirmed, removing nms-marco rules"; ` +
	`/ip firewall raw remove [find where comment~"^nms-marco-"]; ` +
	`/ip firewall filter remove [find where comment~"^nms-marco-"]; ` +
	`/queue simple remove [find where comment~"^nms-marco-"]; ` +
	`/system scheduler remove [find where name="` + deadmanName + `"]`

// armDeadman sets the job to run deadmanAfter from now on the router's own clock.
func armDeadman(conn routerCommander) error {
	rows, err := conn.Command("/system/clock/print")
	if err != nil {
		return fmt.Errorf("read router clock: %w", err)
	}
	if len(rows) == 0 {
		return fmt.Errorf("read router clock: no answer")
	}
	now, err := time.Parse("Jan/02/2006 15:04:05", rows[0]["date"]+" "+rows[0]["time"])
	if err != nil {
		return fmt.Errorf("read router clock: %w", err)
	}
	if err := disarmDeadman(conn); err != nil {
		return err
	}
	at := now.Add(deadmanAfter)
	_, err = conn.Command("/system/scheduler/add", "=name="+deadmanName,
		"=start-date="+strings.ToLower(at.Format("Jan/02/2006")), "=start-time="+at.Format("15:04:05"),
		"=interval=5m", "=policy=read,write", "=on-event="+deadmanScript)
	return err
}

// disarmDeadman cancels the job, leaving the router's other scheduler jobs alone.
func disarmDeadman(conn routerCommander) error {
	rows, err := conn.Command("/system/scheduler/print")
	if err != nil {
		return err
	}
	for _, r := range rows {
		if r["name"] != deadmanName {
			continue
		}
		if _, err := conn.Command("/system/scheduler/remove", "=.id="+r[".id"]); err != nil {
			return err
		}
	}
	return nil
}

func routerLoad(conn routerCommander) (int, error) {
	rows, err := conn.Command("/system/resource/print")
	if err != nil {
		return 0, err
	}
	if len(rows) == 0 {
		return 0, fmt.Errorf("no answer")
	}
	return strconv.Atoi(rows[0]["cpu-load"])
}

// watchRouter watches the router after a change. It fails when the router stops
// answering, or when its CPU stays full although it was not full before the change.
func watchRouter(conn routerCommander, cpuBefore int, wait func(time.Duration)) error {
	misses, high, peak := 0, 0, 0
	for i := 0; i < watchRounds; i++ {
		wait(watchEvery)
		cpu, err := routerLoad(conn)
		if err != nil {
			if misses++; misses >= 2 {
				return fmt.Errorf("the router stopped answering after the change: %w", err)
			}
			continue
		}
		misses = 0
		if cpu >= watchCPUHigh {
			high++
		}
		if cpu > peak {
			peak = cpu
		}
	}
	if high == watchRounds && cpuBefore < watchCPUHigh {
		return fmt.Errorf("the router's CPU went from %d%% to %d%% after the change", cpuBefore, peak)
	}
	return nil
}

// applyGuarded applies the plan to the router under the safety timer. A plan that
// changes nothing never touches the timer.
func (s *MarcoSyncService) applyGuarded(ctx context.Context, orgID uuid.UUID, vendor *models.VendorIntegration, sess *routerSession, desired marcoDesiredState, maxPrune int) (int, error) {
	journal := &changeJournal{}
	armed := false
	cpuBefore := 0
	if sess.write {
		plan := newRouterSession(ctx, sess.inner, false, nil)
		if _, err := applyMarcoCore(plan, desired, &changeJournal{}, s.cfg.RouterPruneStale, maxPrune, true); err != nil {
			return 0, fmt.Errorf("work out the router changes: %w", err)
		}
		if len(plan.Planned()) > 0 {
			if why := s.writesPaused(orgID); why != "" {
				return 0, fmt.Errorf("router changes are paused because %s; press Update the router now to try again", why)
			}
			cpu, err := routerLoad(sess.inner)
			if err != nil {
				return 0, fmt.Errorf("read router load, nothing was changed: %w", err)
			}
			cpuBefore = cpu
			if err := armDeadman(sess.inner); err != nil {
				return 0, fmt.Errorf("set the safety timer, nothing was changed: %w", err)
			}
			armed = true
		}
	}
	fail := func(step string, err error) error {
		if !sess.write {
			return fmt.Errorf("%s: %w", step, err)
		}
		if rbErr := journal.rollback(sess.inner); rbErr != nil {
			return fmt.Errorf("%s: %w (rollback also failed: %v; the safety timer removes the rules)", step, err, rbErr)
		}
		if armed {
			_ = disarmDeadman(sess.inner)
		}
		return fmt.Errorf("%s: %w (changes rolled back)", step, err)
	}

	skipped, err := applyMarcoCore(sess, desired, journal, s.cfg.RouterPruneStale, maxPrune, true)
	if err != nil {
		return 0, fail("apply RouterOS configuration", err)
	}
	if !sess.write {
		return skipped, nil
	}
	if err := verifyMarcoDesiredState(sess, desired, s.cfg.RouterPruneStale && skipped == 0); err != nil {
		return 0, fail("verify RouterOS configuration", err)
	}
	if !armed {
		return skipped, nil
	}
	if err := watchRouter(sess.inner, cpuBefore, s.wait); err != nil {
		s.pauseWrites(orgID, err.Error())
		return 0, s.undoBadChange(vendor, sess.inner, journal, err)
	}
	if err := disarmDeadman(sess.inner); err != nil {
		if err = disarmDeadman(sess.inner); err != nil {
			return 0, fmt.Errorf("the safety timer could not be cancelled, so the router removes the nms-marco rules within %s: %w", deadmanAfter, err)
		}
	}
	return skipped, nil
}

// undoBadChange takes back a change the router did not cope with, over a new
// connection if the old one died. When the router cannot be reached the timer on
// it does the job.
func (s *MarcoSyncService) undoBadChange(vendor *models.VendorIntegration, conn routerCommander, journal *changeJournal, cause error) error {
	if journal.rollback(conn) == nil {
		_ = disarmDeadman(conn)
		return fmt.Errorf("%w; changes rolled back and router changes paused", cause)
	}
	for i := 0; i < 3; i++ {
		fresh, err := s.dialRouter(vendor, s.cfg)
		if err != nil {
			continue
		}
		err = journal.rollback(fresh)
		if err == nil {
			_ = disarmDeadman(fresh)
		}
		fresh.Close()
		if err == nil {
			return fmt.Errorf("%w; changes rolled back and router changes paused", cause)
		}
	}
	return fmt.Errorf("%w; the router could not be reached, so its safety timer removes the nms-marco rules within %s; router changes paused", cause, deadmanAfter)
}

func hasWord(words []string, want string) bool {
	for _, w := range words {
		if w == want {
			return true
		}
	}
	return false
}

func (s *MarcoSyncService) writesPaused(orgID uuid.UUID) string {
	s.sitesMu.Lock()
	defer s.sitesMu.Unlock()
	return s.paused[orgID]
}

func (s *MarcoSyncService) pauseWrites(orgID uuid.UUID, why string) {
	s.sitesMu.Lock()
	defer s.sitesMu.Unlock()
	if s.paused == nil {
		s.paused = map[uuid.UUID]string{}
	}
	s.paused[orgID] = why
}

// ResumeWrites lifts a pause. Only a person pressing Update the router now does
// this, so a rule that hurt the router is not put back on its own.
func (s *MarcoSyncService) ResumeWrites(orgID uuid.UUID) {
	s.sitesMu.Lock()
	defer s.sitesMu.Unlock()
	delete(s.paused, orgID)
}

// refusedRouterWrite names a write that must never reach the router. Matching on
// packet contents (layer7, tls-host, content) runs on every packet it sees, and a
// layer7 rule for just two devices took this router and the whole hospital's
// internet down on 2026-11-03. Removing such entries stays allowed. The one exception
// is a plain word match on DNS questions (udp 53) in the raw table: those packets are
// tiny and few.
func refusedRouterWrite(path string, attrs []string) string {
	if strings.HasSuffix(path, "/remove") {
		return ""
	}
	if strings.HasPrefix(path, "/ip/firewall/layer7-protocol/") {
		return "layer7 protocols"
	}
	dnsOnly := strings.HasPrefix(path, "/ip/firewall/raw/") && hasWord(attrs, "=protocol=udp") && hasWord(attrs, "=dst-port=53")
	for _, a := range attrs {
		for _, name := range []string{"layer7-protocol", "tls-host", "content"} {
			if name == "content" && dnsOnly {
				continue
			}
			if strings.HasPrefix(a, "="+name+"=") && a != "="+name+"=" {
				return name + " matching"
			}
		}
	}
	return ""
}

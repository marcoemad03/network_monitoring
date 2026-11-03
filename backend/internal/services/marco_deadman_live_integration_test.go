//go:build integration

package services

import (
	"context"
	"os"
	"strings"
	"testing"
	"time"

	"github.com/google/uuid"
	"github.com/hospital/nms-backend/internal/config"
	"github.com/hospital/nms-backend/internal/database"
	"github.com/hospital/nms-backend/internal/repository"
	"github.com/hospital/nms-backend/pkg/logger"
)

// Sets the real safety timer on the real router and waits for it to run. It adds one
// switched-off rule of its own for the timer to remove, and stops if the router has
// any other nms-marco- rule or queue, since the timer would remove those too.
//
//	NMS_LIVE_TIMER_TEST=yes go test -tags integration -v -timeout 10m -run TestDeadmanOnLiveRouter ./internal/services
func TestDeadmanOnLiveRouter(t *testing.T) {
	if os.Getenv("NMS_LIVE_TIMER_TEST") != "yes" {
		t.Skip("writes to the live router; set NMS_LIVE_TIMER_TEST=yes")
	}
	cfg, err := config.Load(0)
	if err != nil {
		t.Fatal(err)
	}
	logger.Init("error", "json")
	db, err := database.NewPostgresDB(cfg)
	if err != nil {
		t.Fatal(err)
	}
	defer db.Close()
	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()
	org := uuid.MustParse("00000000-0000-0000-0000-000000000001")
	vendor, err := repository.NewInternetRepository(db).GetActiveMikroTikIntegration(ctx, org)
	if err != nil {
		t.Fatal(err)
	}
	conn, err := dialRouterConnection(vendor, cfg)
	if err != nil {
		t.Fatal(err)
	}
	defer conn.Close()

	managed := func(c routerCommander, path string) []map[string]string {
		rows, err := c.Command(path + "/print")
		if err != nil {
			t.Fatalf("print %s: %v", path, err)
		}
		var out []map[string]string
		for _, r := range rows {
			if strings.HasPrefix(r["comment"], marcoManagedPrefix) {
				out = append(out, r)
			}
		}
		return out
	}
	for _, path := range []string{"/ip/firewall/filter", "/queue/simple"} {
		if rows := managed(conn, path); len(rows) > 0 {
			t.Fatalf("%s has %d nms-marco- entries the timer would remove", path, len(rows))
		}
	}

	const marker = "nms-marco-timer-test"
	cleanup := func() {
		c, err := dialRouterConnection(vendor, cfg)
		if err != nil {
			t.Logf("CLEANUP FAILED, remove %s and %s by hand: %v", marker, deadmanName, err)
			return
		}
		defer c.Close()
		for _, r := range managed(c, "/ip/firewall/filter") {
			if r["comment"] == marker {
				if _, err := c.Command("/ip/firewall/filter/remove", "=.id="+r[".id"]); err != nil {
					t.Logf("cleanup: %v", err)
				}
			}
		}
		if err := disarmDeadman(c); err != nil {
			t.Logf("cleanup: %v", err)
		}
	}
	defer cleanup()

	if _, err := conn.Command("/ip/firewall/filter/add", "=chain=forward", "=action=passthrough", "=disabled=yes", "=comment="+marker); err != nil {
		t.Fatalf("add the switched-off rule: %v", err)
	}
	start := time.Now()
	if err := armDeadman(conn); err != nil {
		t.Fatalf("the router refused the safety timer: %v", err)
	}
	rows, err := conn.Command("/system/scheduler/print")
	if err != nil {
		t.Fatal(err)
	}
	for _, r := range rows {
		if r["name"] == deadmanName {
			t.Logf("timer set: start=%s %s next-run=%s interval=%s owner=%s policy=%s", r["start-date"], r["start-time"], r["next-run"], r["interval"], r["owner"], r["policy"])
		}
	}
	if clock, err := conn.Command("/system/clock/print"); err == nil && len(clock) > 0 {
		t.Logf("router clock: %s %s", clock[0]["date"], clock[0]["time"])
	}

	for time.Since(start) < deadmanAfter+2*time.Minute {
		time.Sleep(15 * time.Second)
		c, err := dialRouterConnection(vendor, cfg)
		if err != nil {
			t.Logf("%s no answer: %v", time.Since(start).Round(time.Second), err)
			continue
		}
		ruleLeft := len(managed(c, "/ip/firewall/filter")) > 0
		jobs, err := c.Command("/system/scheduler/print")
		c.Close()
		if err != nil {
			continue
		}
		jobLeft := false
		for _, r := range jobs {
			if r["name"] == deadmanName {
				jobLeft = true
			}
		}
		if ruleLeft && jobLeft {
			continue
		}
		took := time.Since(start).Round(time.Second)
		t.Logf("after %s: rule still there=%v, timer still there=%v", took, ruleLeft, jobLeft)
		if ruleLeft || jobLeft {
			t.Fatalf("the timer did only part of its job")
		}
		if took < deadmanAfter-30*time.Second {
			t.Fatalf("the timer ran early, after %s", took)
		}
		return
	}
	t.Fatalf("the timer did not run within %s", deadmanAfter+2*time.Minute)
}

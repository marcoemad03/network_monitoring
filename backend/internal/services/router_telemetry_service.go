package services

import (
	"context"
	"fmt"
	"regexp"
	"sort"
	"strconv"
	"strings"
	"sync"
	"time"

	"github.com/google/uuid"
	"github.com/hospital/nms-backend/internal/config"
	"github.com/hospital/nms-backend/internal/models"
	"github.com/hospital/nms-backend/internal/repository"
	"github.com/hospital/nms-backend/pkg/logger"
)

const (
	telemetryPersistEvery = 30 * time.Second
	telemetryRingSize     = 240 // 1 hour at 15s
	telemetryRetention    = 400 * 24 * time.Hour
	wanDetectEvery        = 5 * time.Minute
)

// RouterHealth is the router's own resource usage.
type RouterHealth struct {
	Board             string  `json:"board"`
	Version           string  `json:"version"`
	CPULoadPercent    int     `json:"cpu_load_percent"`
	MemoryUsedPercent float64 `json:"memory_used_percent"`
	TotalMemoryBytes  int64   `json:"total_memory_bytes"`
	FreeMemoryBytes   int64   `json:"free_memory_bytes"`
	UptimeSeconds     int64   `json:"uptime_seconds"`
}

// WANSnapshot is the latest measurement of the internet link.
type WANSnapshot struct {
	Interface   string `json:"interface"`
	Running     bool   `json:"running"`
	DownloadBps int64  `json:"download_bps"`
	UploadBps   int64  `json:"upload_bps"`
	// The interface counters since the router last restarted.
	DownloadBytesSinceBoot int64        `json:"download_bytes_since_boot"`
	UploadBytesSinceBoot   int64        `json:"upload_bytes_since_boot"`
	Router                 RouterHealth `json:"router"`
	UpdatedAt              time.Time    `json:"updated_at"`
	// Error is the reason the latest poll failed; the other fields then still
	// hold the last good measurement.
	Error string `json:"error,omitempty"`
}

// WANLivePoint is one in-memory point of the live chart.
type WANLivePoint struct {
	At          time.Time `json:"at"`
	DownloadBps int64     `json:"download_bps"`
	UploadBps   int64     `json:"upload_bps"`
}

// RouterTelemetryService measures the internet link from the router's own
// interface counters. It only ever reads from the router: its session is opened
// without write permission, whatever ROUTER_POLICY_WRITES says.
type RouterTelemetryService struct {
	wanRepo      *repository.WANRepository
	internetRepo *repository.InternetRepository
	cfg          *config.Config
	dial         func(*models.VendorIntegration, *config.Config) (routerCommander, error)

	mu     sync.RWMutex
	states map[uuid.UUID]*telemetryState
}

type counterReading struct {
	rx, tx int64
	at     time.Time
}

type telemetryState struct {
	iface        string
	ifaceChecked time.Time
	prev         *counterReading
	snapshot     WANSnapshot
	hasSnapshot  bool
	ring         []WANLivePoint
	pendingRx    int64
	pendingTx    int64
	lastPersist  time.Time
}

func NewRouterTelemetryService(wanRepo *repository.WANRepository, internetRepo *repository.InternetRepository, cfg *config.Config) *RouterTelemetryService {
	return &RouterTelemetryService{
		wanRepo: wanRepo, internetRepo: internetRepo, cfg: cfg,
		dial:   dialRouterConnection,
		states: make(map[uuid.UUID]*telemetryState),
	}
}

// Start polls every organization's router until ctx ends. interval <= 0 disables it.
func (s *RouterTelemetryService) Start(ctx context.Context, interval time.Duration) {
	if interval <= 0 {
		logger.Info("Router telemetry disabled")
		return
	}
	go func() {
		ticker := time.NewTicker(interval)
		defer ticker.Stop()
		lastPrune := time.Time{}
		for {
			s.pollAll(ctx, interval)
			if time.Since(lastPrune) > 24*time.Hour {
				if err := s.wanRepo.Prune(ctx, time.Now().Add(-telemetryRetention)); err != nil {
					logger.Warn("WAN sample prune failed", "error", err)
				}
				lastPrune = time.Now()
			}
			select {
			case <-ctx.Done():
				return
			case <-ticker.C:
			}
		}
	}()
}

func (s *RouterTelemetryService) pollAll(ctx context.Context, interval time.Duration) {
	orgs, err := s.wanRepo.OrgsWithRouter(ctx)
	if err != nil {
		logger.Warn("Router telemetry: list organizations failed", "error", err)
		return
	}
	for _, orgID := range orgs {
		pollCtx, cancel := context.WithTimeout(ctx, 20*time.Second)
		s.Poll(pollCtx, orgID, interval)
		cancel()
	}
}

// Snapshot returns the latest measurement for the organization.
func (s *RouterTelemetryService) Snapshot(orgID uuid.UUID) (WANSnapshot, bool) {
	s.mu.RLock()
	defer s.mu.RUnlock()
	st := s.states[orgID]
	if st == nil || !st.hasSnapshot {
		return WANSnapshot{}, false
	}
	return st.snapshot, true
}

// LastError is the reason the latest poll failed, or "" when it succeeded.
func (s *RouterTelemetryService) LastError(orgID uuid.UUID) string {
	s.mu.RLock()
	defer s.mu.RUnlock()
	if st := s.states[orgID]; st != nil {
		return st.snapshot.Error
	}
	return ""
}

// Live returns the in-memory chart points, oldest first.
func (s *RouterTelemetryService) Live(orgID uuid.UUID) []WANLivePoint {
	s.mu.RLock()
	defer s.mu.RUnlock()
	st := s.states[orgID]
	if st == nil {
		return []WANLivePoint{}
	}
	out := make([]WANLivePoint, len(st.ring))
	copy(out, st.ring)
	return out
}

func (s *RouterTelemetryService) state(orgID uuid.UUID) *telemetryState {
	st := s.states[orgID]
	if st == nil {
		st = &telemetryState{}
		s.states[orgID] = st
	}
	return st
}

func (s *RouterTelemetryService) fail(orgID uuid.UUID, err error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	st := s.state(orgID)
	st.snapshot.Error = err.Error()
}

// Poll takes one measurement. A poll that cannot get the router (busy with a
// policy sync, unreachable) keeps the previous measurement and records why.
func (s *RouterTelemetryService) Poll(ctx context.Context, orgID uuid.UUID, interval time.Duration) {
	vendor, err := s.internetRepo.GetActiveMikroTikIntegration(ctx, orgID)
	if err != nil {
		s.fail(orgID, fmt.Errorf("no active MikroTik integration"))
		return
	}
	sess, err := openRouterSessionWith(ctx, vendor, s.cfg, s.dial, false, false)
	if err != nil {
		s.fail(orgID, fmt.Errorf("router unreachable: %w", err))
		return
	}
	if sess == nil {
		return // a policy sync holds the router; try again next tick
	}
	defer sess.Close()

	snap, reading, err := s.measure(sess, orgID)
	if err != nil {
		s.fail(orgID, err)
		return
	}
	s.record(ctx, orgID, snap, reading, interval)
}

func (s *RouterTelemetryService) measure(conn routerCommander, orgID uuid.UUID) (WANSnapshot, counterReading, error) {
	var snap WANSnapshot

	res, err := conn.Command("/system/resource/print")
	if err != nil {
		return snap, counterReading{}, fmt.Errorf("read router resources: %w", err)
	}
	if len(res) > 0 {
		snap.Router = parseRouterHealth(res[0])
	}

	iface, err := s.wanInterface(conn, orgID)
	if err != nil {
		return snap, counterReading{}, err
	}
	snap.Interface = iface

	rows, err := conn.Command("/interface/print", "=.proplist=name,type,running,rx-byte,tx-byte")
	if err != nil {
		return snap, counterReading{}, fmt.Errorf("read interface counters: %w", err)
	}
	for _, row := range rows {
		if row["name"] != iface {
			continue
		}
		rx, errRx := strconv.ParseInt(row["rx-byte"], 10, 64)
		tx, errTx := strconv.ParseInt(row["tx-byte"], 10, 64)
		if errRx != nil || errTx != nil {
			return snap, counterReading{}, fmt.Errorf("interface %q has no byte counters", iface)
		}
		snap.Running = isRouterTrue(row["running"])
		snap.DownloadBytesSinceBoot, snap.UploadBytesSinceBoot = rx, tx
		return snap, counterReading{rx: rx, tx: tx, at: time.Now()}, nil
	}
	return snap, counterReading{}, fmt.Errorf("interface %q not found on the router", iface)
}

// wanInterface returns the configured or detected internet-facing interface.
func (s *RouterTelemetryService) wanInterface(conn routerCommander, orgID uuid.UUID) (string, error) {
	if s.cfg.RouterWANInterface != "" {
		return s.cfg.RouterWANInterface, nil
	}
	s.mu.RLock()
	st := s.states[orgID]
	cached, checked := "", time.Time{}
	if st != nil {
		cached, checked = st.iface, st.ifaceChecked
	}
	s.mu.RUnlock()
	if cached != "" && time.Since(checked) < wanDetectEvery {
		return cached, nil
	}

	routes, err := conn.Command("/ip/route/print", "?dst-address=0.0.0.0/0")
	if err != nil {
		return "", fmt.Errorf("read default route: %w", err)
	}
	iface := wanInterfaceFromRoutes(routes)
	if iface == "" {
		return "", fmt.Errorf("could not find the internet interface from the default route; set ROUTER_WAN_INTERFACE")
	}
	s.mu.Lock()
	st = s.state(orgID)
	st.iface, st.ifaceChecked = iface, time.Now()
	s.mu.Unlock()
	return iface, nil
}

func (s *RouterTelemetryService) record(ctx context.Context, orgID uuid.UUID, snap WANSnapshot, cur counterReading, interval time.Duration) {
	s.mu.Lock()
	st := s.state(orgID)

	if st.snapshot.Interface != "" && st.snapshot.Interface != snap.Interface {
		st.prev, st.pendingRx, st.pendingTx = nil, 0, 0
	}
	needBaseline := st.prev == nil
	s.mu.Unlock()

	if needBaseline {
		// Resume from the last stored counters so usage is not lost across a restart.
		if last, err := s.wanRepo.Last(ctx, orgID, snap.Interface); err == nil && last != nil {
			s.mu.Lock()
			st.prev = &counterReading{rx: last.RxCounter, tx: last.TxCounter, at: last.SampledAt}
			s.mu.Unlock()
		}
	}

	s.mu.Lock()
	maxGap := 3 * interval
	if maxGap < time.Minute {
		maxGap = time.Minute
	}
	var rate rateResult
	if st.prev != nil {
		rate = computeRate(*st.prev, cur, maxGap)
	}
	st.prev = &cur
	snap.UpdatedAt = cur.at
	if rate.valid && !rate.gap {
		snap.DownloadBps, snap.UploadBps = rate.rxBps, rate.txBps
	} else if st.hasSnapshot {
		snap.DownloadBps, snap.UploadBps = st.snapshot.DownloadBps, st.snapshot.UploadBps
	}
	st.snapshot, st.hasSnapshot = snap, true
	st.ring = append(st.ring, WANLivePoint{At: cur.at, DownloadBps: snap.DownloadBps, UploadBps: snap.UploadBps})
	if len(st.ring) > telemetryRingSize {
		st.ring = st.ring[len(st.ring)-telemetryRingSize:]
	}
	if rate.valid {
		st.pendingRx += rate.rxDelta
		st.pendingTx += rate.txDelta
	}
	flush := st.lastPersist.IsZero() || cur.at.Sub(st.lastPersist) >= telemetryPersistEvery
	var sample repository.WANSample
	if flush {
		sample = repository.WANSample{
			Interface: snap.Interface, SampledAt: cur.at, RxCounter: cur.rx, TxCounter: cur.tx,
			RxBytesDelta: st.pendingRx, TxBytesDelta: st.pendingTx,
			RxBps: snap.DownloadBps, TxBps: snap.UploadBps,
		}
		st.pendingRx, st.pendingTx = 0, 0
		st.lastPersist = cur.at
	}
	s.mu.Unlock()

	if flush {
		if err := s.wanRepo.Insert(ctx, orgID, sample); err != nil {
			logger.Warn("WAN sample not stored", "error", err)
		}
	}
}

// ---------------------------------------------------------------------------
// Pure helpers

type rateResult struct {
	rxDelta, txDelta int64
	rxBps, txBps     int64
	valid            bool // the counters moved forward and can be counted
	gap              bool // too long since the previous reading to give a speed
}

// computeRate turns two counter readings into bytes moved and bits per second.
// A counter that went backwards means the router restarted: the reading only
// becomes the new baseline.
func computeRate(prev, cur counterReading, maxGap time.Duration) rateResult {
	if cur.rx < prev.rx || cur.tx < prev.tx {
		return rateResult{}
	}
	dt := cur.at.Sub(prev.at)
	if dt <= 0 {
		return rateResult{}
	}
	r := rateResult{rxDelta: cur.rx - prev.rx, txDelta: cur.tx - prev.tx, valid: true}
	if dt > maxGap {
		r.gap = true
		return r
	}
	secs := dt.Seconds()
	r.rxBps = int64(float64(r.rxDelta) * 8 / secs)
	r.txBps = int64(float64(r.txDelta) * 8 / secs)
	return r
}

var viaInterface = regexp.MustCompile(`\bvia\s+(?:\S+\s+)*?(\S+)\s*$`)

// wanInterfaceFromRoutes picks the interface of the preferred active default route.
func wanInterfaceFromRoutes(routes []map[string]string) string {
	type candidate struct {
		iface    string
		distance int
		active   bool
	}
	var cands []candidate
	for _, r := range routes {
		if r["dst-address"] != "0.0.0.0/0" || isRouterTrue(r["disabled"]) {
			continue
		}
		iface := ""
		if status := r["gateway-status"]; strings.Contains(status, "via") {
			if m := viaInterface.FindStringSubmatch(status); m != nil {
				iface = m[1]
			}
		}
		if iface == "" {
			if vrf := r["vrf-interface"]; vrf != "" {
				iface = vrf
			} else if gw := r["gateway"]; gw != "" && !looksLikeIP(gw) {
				iface = gw
			}
		}
		if iface == "" {
			continue
		}
		dist, err := strconv.Atoi(r["distance"])
		if err != nil {
			dist = 255
		}
		cands = append(cands, candidate{iface: iface, distance: dist, active: isRouterTrue(r["active"])})
	}
	sort.SliceStable(cands, func(i, j int) bool {
		if cands[i].active != cands[j].active {
			return cands[i].active
		}
		return cands[i].distance < cands[j].distance
	})
	if len(cands) == 0 {
		return ""
	}
	return cands[0].iface
}

func looksLikeIP(v string) bool {
	return strings.Count(v, ".") == 3 || strings.Contains(v, ":")
}

func isRouterTrue(v string) bool {
	switch strings.ToLower(strings.TrimSpace(v)) {
	case "true", "yes":
		return true
	}
	return false
}

func parseRouterHealth(r map[string]string) RouterHealth {
	h := RouterHealth{Board: r["board-name"], Version: r["version"], UptimeSeconds: parseRouterUptime(r["uptime"])}
	h.CPULoadPercent, _ = strconv.Atoi(r["cpu-load"])
	h.TotalMemoryBytes, _ = strconv.ParseInt(r["total-memory"], 10, 64)
	h.FreeMemoryBytes, _ = strconv.ParseInt(r["free-memory"], 10, 64)
	if h.TotalMemoryBytes > 0 {
		h.MemoryUsedPercent = float64(h.TotalMemoryBytes-h.FreeMemoryBytes) * 100 / float64(h.TotalMemoryBytes)
	}
	return h
}

var uptimePart = regexp.MustCompile(`(\d+)([wdhms])`)

// parseRouterUptime converts RouterOS durations such as "1w2d3h4m5s" to seconds.
func parseRouterUptime(v string) int64 {
	var total int64
	for _, m := range uptimePart.FindAllStringSubmatch(v, -1) {
		n, _ := strconv.ParseInt(m[1], 10, 64)
		switch m[2] {
		case "w":
			total += n * 7 * 86400
		case "d":
			total += n * 86400
		case "h":
			total += n * 3600
		case "m":
			total += n * 60
		case "s":
			total += n
		}
	}
	return total
}

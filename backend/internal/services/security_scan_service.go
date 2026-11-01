package services

import (
	"context"
	"errors"
	"fmt"
	"net"
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
	scanReadTimeout   = 60 * time.Second
	ptrLookupBudget   = 8 * time.Second
	ptrLookupTimeout  = 1500 * time.Millisecond
	ptrMaxLookups     = 80
	ptrCacheFor       = 24 * time.Hour
	maxFindingsStored = 500
)

// ErrScanBusy is returned while a scan is already running.
var ErrScanBusy = errors.New("a scan is already running")

// ScanCooldownError is returned when the last scan is too recent.
type ScanCooldownError struct{ RetryAfter time.Duration }

func (e *ScanCooldownError) Error() string {
	return fmt.Sprintf("the last scan is recent; wait %d more seconds", int(e.RetryAfter.Seconds())+1)
}

// RouterBusyError is returned when scanning now would load a router that is
// already working hard.
type RouterBusyError struct {
	CPU    int
	Reason string
}

func (e *RouterBusyError) Error() string { return e.Reason }

// DestinationStat is a destination summed over all devices.
type DestinationStat struct {
	Name        string `json:"name"`
	Kind        string `json:"kind"`
	Connections int    `json:"connections"`
	Devices     int    `json:"devices"`
	Down        int64  `json:"download_bytes"`
	Up          int64  `json:"upload_bytes"`
}

// ScanSnapshot is the result of one scan.
type ScanSnapshot struct {
	ID              int64             `json:"id"`
	TakenAt         time.Time         `json:"taken_at"`
	DurationMs      int               `json:"duration_ms"`
	Connections     int               `json:"connections"`
	RouterCPUBefore int               `json:"router_cpu_before"`
	RouterCPUAfter  int               `json:"router_cpu_after"`
	PlatformLists   int               `json:"platform_lists_read"`
	Restored        bool              `json:"restored"`
	Devices         []DeviceActivity  `json:"devices"`
	Destinations    []DestinationStat `json:"destinations"`
	Findings        []Finding         `json:"findings"`
}

// SecurityScanService reads the router's connection table to show what each
// device is connected to, and looks it over for behaviour worth a look. It only
// reads, and only when asked (or on the configured interval).
type SecurityScanService struct {
	repo         *repository.SecurityRepository
	internetRepo *repository.InternetRepository
	inventory    *ClientInventoryService
	cfg          *config.Config
	dial         func(*models.VendorIntegration, *config.Config) (routerCommander, error)
	lookupAddr   func(ctx context.Context, ip string) ([]string, error)

	mu     sync.Mutex
	states map[uuid.UUID]*scanState

	ptrMu    sync.Mutex
	ptrCache map[string]ptrEntry
}

type scanState struct {
	snapshot *ScanSnapshot
	scanning bool
	lastErr  string
}

type ptrEntry struct {
	owner string
	at    time.Time
}

func NewSecurityScanService(repo *repository.SecurityRepository, internetRepo *repository.InternetRepository, inventory *ClientInventoryService, cfg *config.Config) *SecurityScanService {
	return &SecurityScanService{
		repo: repo, internetRepo: internetRepo, inventory: inventory, cfg: cfg,
		dial:       dialRouterConnection,
		lookupAddr: func(ctx context.Context, ip string) ([]string, error) { return net.DefaultResolver.LookupAddr(ctx, ip) },
		states:     make(map[uuid.UUID]*scanState),
		ptrCache:   make(map[string]ptrEntry),
	}
}

// Start scans every interval until ctx ends. interval <= 0 means scans only
// happen when someone asks. orgs lists the organizations that have a router.
func (s *SecurityScanService) Start(ctx context.Context, interval time.Duration, orgs func(context.Context) ([]uuid.UUID, error)) {
	go func() {
		pruneTicker := time.NewTicker(6 * time.Hour)
		defer pruneTicker.Stop()
		var scanTick <-chan time.Time
		if interval > 0 {
			t := time.NewTicker(interval)
			defer t.Stop()
			scanTick = t.C
		}
		s.prune(ctx)
		for {
			select {
			case <-ctx.Done():
				return
			case <-pruneTicker.C:
				s.prune(ctx)
			case <-scanTick:
				ids, err := orgs(ctx)
				if err != nil {
					continue
				}
				for _, id := range ids {
					if _, err := s.Scan(ctx, id); err != nil {
						logger.Info("Scheduled security scan skipped", "reason", err.Error())
					}
				}
			}
		}
	}()
}

func (s *SecurityScanService) prune(ctx context.Context) {
	days := s.cfg.SecurityRetentionDays
	if days <= 0 {
		days = 30
	}
	if err := s.repo.Prune(ctx, time.Now().AddDate(0, 0, -days)); err != nil {
		logger.Warn("Security scan prune failed", "error", err)
	}
}

func (s *SecurityScanService) state(orgID uuid.UUID) *scanState {
	st := s.states[orgID]
	if st == nil {
		st = &scanState{}
		s.states[orgID] = st
	}
	return st
}

// Status is what the page shows about scanning itself.
type ScanStatus struct {
	Scanning       bool
	LastError      string
	CooldownLeft   time.Duration
	AutoInterval   time.Duration
	MaxCPU         int
	RetentionDays  int
	HasPlatformFor []string
}

func (s *SecurityScanService) Status(orgID uuid.UUID) ScanStatus {
	s.mu.Lock()
	defer s.mu.Unlock()
	st := s.state(orgID)
	out := ScanStatus{
		Scanning: st.scanning, LastError: st.lastErr, AutoInterval: s.cfg.RouterSecurityScanInterval,
		MaxCPU: s.cfg.RouterScanMaxCPU, RetentionDays: s.cfg.SecurityRetentionDays,
	}
	if st.snapshot != nil && !st.snapshot.Restored {
		if left := s.cfg.RouterScanCooldown - time.Since(st.snapshot.TakenAt); left > 0 {
			out.CooldownLeft = left
		}
	}
	for name := range s.cfg.RouterScanPlatformLists {
		out.HasPlatformFor = append(out.HasPlatformFor, name)
	}
	sort.Strings(out.HasPlatformFor)
	return out
}

// Latest returns the newest scan. After a restart it is rebuilt from the
// database, without the per-connection detail.
func (s *SecurityScanService) Latest(ctx context.Context, orgID uuid.UUID) *ScanSnapshot {
	s.mu.Lock()
	st := s.state(orgID)
	snap := st.snapshot
	s.mu.Unlock()
	if snap != nil {
		return snap
	}
	restored := s.restore(ctx, orgID)
	if restored != nil {
		s.mu.Lock()
		if st.snapshot == nil {
			st.snapshot = restored
		}
		snap = st.snapshot
		s.mu.Unlock()
	}
	return snap
}

func (s *SecurityScanService) restore(ctx context.Context, orgID uuid.UUID) *ScanSnapshot {
	rec, err := s.repo.LastScan(ctx, orgID)
	if err != nil || rec == nil {
		return nil
	}
	flows, _ := s.repo.ScanFlows(ctx, rec.ID)
	findings, _ := s.repo.ScanFindings(ctx, rec.ID)

	names := map[string]DeviceIdentity{}
	if list, err := s.inventory.List(ctx, orgID); err == nil {
		for _, c := range list.Clients {
			names[c.MAC] = DeviceIdentity{MAC: c.MAC, Name: c.DisplayName, Kind: c.Kind}
		}
	}
	byDevice := map[string]*DeviceActivity{}
	var order []string
	dest := map[string]*DestinationStat{}
	devicesPer := map[string]map[string]bool{}
	for _, f := range flows {
		key := f.MAC
		if key == "" {
			key = f.IP
		}
		d := byDevice[key]
		if d == nil {
			ident := names[f.MAC]
			name := ident.Name
			if name == "" {
				name = f.IP
			}
			d = &DeviceActivity{MAC: f.MAC, IP: f.IP, Name: name, Kind: ident.Kind}
			byDevice[key] = d
			order = append(order, key)
		}
		d.Connections += f.Connections
		d.Down += f.Down
		d.Up += f.Up
		d.Destinations++
		d.Top = append(d.Top, LabelStat{Name: f.Label, Kind: f.Kind, Connections: f.Connections, Down: f.Down, Up: f.Up})

		ds := dest[f.Label]
		if ds == nil {
			ds = &DestinationStat{Name: f.Label, Kind: f.Kind}
			dest[f.Label] = ds
			devicesPer[f.Label] = map[string]bool{}
		}
		ds.Connections += f.Connections
		ds.Down += f.Down
		ds.Up += f.Up
		devicesPer[f.Label][key] = true
	}
	snap := &ScanSnapshot{
		ID: rec.ID, TakenAt: rec.TakenAt, DurationMs: rec.DurationMs, Connections: rec.Connections,
		RouterCPUBefore: rec.RouterCPUBefore, RouterCPUAfter: rec.RouterCPUAfter, Restored: true,
	}
	for _, key := range order {
		d := byDevice[key]
		sort.Slice(d.Top, func(i, j int) bool { return d.Top[i].Down+d.Top[i].Up > d.Top[j].Down+d.Top[j].Up })
		snap.Devices = append(snap.Devices, *d)
	}
	for label, d := range dest {
		d.Devices = len(devicesPer[label])
		snap.Destinations = append(snap.Destinations, *d)
	}
	for _, f := range findings {
		ident := names[f.MAC]
		name := ident.Name
		if name == "" {
			name = f.IP
		}
		snap.Findings = append(snap.Findings, Finding{Severity: f.Severity, Code: f.Code, Title: f.Title, Detail: f.Detail, MAC: f.MAC, IP: f.IP, Device: name})
		for i := range snap.Devices {
			if snap.Devices[i].MAC == f.MAC && snap.Devices[i].IP == f.IP {
				countSeverity(&snap.Devices[i], f.Severity)
			}
		}
	}
	finishSnapshot(snap)
	return snap
}

func countSeverity(d *DeviceActivity, sev string) {
	switch sev {
	case SeverityHigh:
		d.High++
	case SeverityMedium:
		d.Medium++
	}
}

func finishSnapshot(snap *ScanSnapshot) {
	sort.Slice(snap.Devices, func(i, j int) bool {
		a, b := snap.Devices[i], snap.Devices[j]
		if a.High != b.High {
			return a.High > b.High
		}
		if a.Medium != b.Medium {
			return a.Medium > b.Medium
		}
		return a.Down+a.Up > b.Down+b.Up
	})
	sort.Slice(snap.Destinations, func(i, j int) bool {
		return snap.Destinations[i].Down+snap.Destinations[i].Up > snap.Destinations[j].Down+snap.Destinations[j].Up
	})
	order := map[string]int{SeverityHigh: 0, SeverityMedium: 1, SeverityLow: 2, SeverityInfo: 3}
	sort.SliceStable(snap.Findings, func(i, j int) bool { return order[snap.Findings[i].Severity] < order[snap.Findings[j].Severity] })
}

// Scan reads the connection table once and analyses it.
func (s *SecurityScanService) Scan(ctx context.Context, orgID uuid.UUID) (*ScanSnapshot, error) {
	s.mu.Lock()
	st := s.state(orgID)
	if st.scanning {
		s.mu.Unlock()
		return nil, ErrScanBusy
	}
	if st.snapshot != nil && !st.snapshot.Restored {
		if left := s.cfg.RouterScanCooldown - time.Since(st.snapshot.TakenAt); left > 0 {
			s.mu.Unlock()
			return nil, &ScanCooldownError{RetryAfter: left}
		}
	}
	st.scanning = true
	s.mu.Unlock()

	snap, err := s.run(ctx, orgID)

	s.mu.Lock()
	st.scanning = false
	if err != nil {
		st.lastErr = err.Error()
	} else {
		st.lastErr = ""
		st.snapshot = snap
	}
	s.mu.Unlock()
	return snap, err
}

func (s *SecurityScanService) run(ctx context.Context, orgID uuid.UUID) (*ScanSnapshot, error) {
	vendor, err := s.internetRepo.GetActiveMikroTikIntegration(ctx, orgID)
	if err != nil {
		return nil, errors.New("no MikroTik router is connected")
	}
	routerHost, _, _ := net.SplitHostPort(vendor.BaseURL)
	if routerHost == "" {
		routerHost = vendor.BaseURL
	}

	readCtx, cancel := context.WithTimeout(ctx, scanReadTimeout)
	defer cancel()
	sess, err := openRouterSessionWith(readCtx, vendor, s.cfg, s.dial, false, false)
	if err != nil {
		return nil, fmt.Errorf("router unreachable: %w", err)
	}
	if sess == nil {
		return nil, &RouterBusyError{Reason: "The router is busy with another task. Try again in a moment."}
	}

	cpuBefore := routerCPU(sess)
	if max := s.cfg.RouterScanMaxCPU; max > 0 && cpuBefore >= max {
		_ = sess.Close()
		return nil, &RouterBusyError{CPU: cpuBefore, Reason: fmt.Sprintf("The router is at %d%% CPU (limit %d%%). Scanning now could slow the network down.", cpuBefore, max)}
	}

	start := time.Now()
	lb := newLabeler([]string{routerHost})
	listsRead := 0
	for name, listName := range s.cfg.RouterScanPlatformLists {
		rows, err := sess.Command("/ip/firewall/address-list/print", "?list="+listName, "=.proplist=address")
		if err != nil {
			continue
		}
		listsRead++
		for _, r := range rows {
			lb.addPlatform(platformTitle(name), r["address"])
		}
	}
	rows, err := sess.Command("/ip/firewall/connection/print", "=.proplist=protocol,src-address,dst-address,orig-bytes,repl-bytes")
	cpuAfter := routerCPU(sess)
	_ = sess.Close() // release the router before the slow part
	if err != nil {
		return nil, fmt.Errorf("read the connection table: %w", err)
	}
	flows := parseFlows(rows)
	took := time.Since(start)

	idents := s.identities(ctx, orgID)
	s.resolveOwners(ctx, flows, lb)

	snap := &ScanSnapshot{
		TakenAt: time.Now(), DurationMs: int(took.Milliseconds()), Connections: len(flows),
		RouterCPUBefore: cpuBefore, RouterCPUAfter: cpuAfter, PlatformLists: listsRead,
	}
	snap.Devices, snap.Findings, snap.Destinations = analyzeFlows(flows, lb, idents, routerHost)
	finishSnapshot(snap)

	s.persist(ctx, orgID, snap)
	return snap, nil
}

// analyzeFlows groups the connections by device, labels where each goes, and
// looks for behaviour worth a look.
func analyzeFlows(flows []Flow, lb *labeler, idents map[string]DeviceIdentity, routerHost string) ([]DeviceActivity, []Finding, []DestinationStat) {
	aggs := map[string]*deviceAgg{}
	for _, f := range flows {
		if !isPrivateIP(f.SrcIP) || f.SrcIP == routerHost || strings.HasPrefix(f.DstIP, "224.") || f.DstIP == "255.255.255.255" {
			continue // not a device in the network, or just broadcast
		}
		a := aggs[f.SrcIP]
		if a == nil {
			a = newDeviceAgg(f.SrcIP, idents[f.SrcIP])
			aggs[f.SrcIP] = a
		}
		a.add(f, lb.label(f))
	}

	var devices []DeviceActivity
	var findings []Finding
	dest := map[string]*DestinationStat{}
	devicesPer := map[string]map[string]bool{}
	for ip, a := range aggs {
		act := a.activity()
		fs := findingsFor(a)
		for _, f := range fs {
			countSeverity(&act, f.Severity)
		}
		findings = append(findings, fs...)
		devices = append(devices, act)
		for _, l := range a.labels {
			ds := dest[l.Name]
			if ds == nil {
				ds = &DestinationStat{Name: l.Name, Kind: l.Kind}
				dest[l.Name] = ds
				devicesPer[l.Name] = map[string]bool{}
			}
			ds.Connections += l.Connections
			ds.Down += l.Down
			ds.Up += l.Up
			devicesPer[l.Name][ip] = true
		}
	}
	var destinations []DestinationStat
	for label, d := range dest {
		d.Devices = len(devicesPer[label])
		destinations = append(destinations, *d)
	}
	return devices, findings, destinations
}

func routerCPU(conn routerCommander) int {
	rows, err := conn.Command("/system/resource/print", "=.proplist=cpu-load")
	if err != nil || len(rows) == 0 {
		return 0
	}
	n, _ := strconv.Atoi(rows[0]["cpu-load"])
	return n
}

// platformTitle turns a configured key such as "youtube" into "YouTube".
func platformTitle(key string) string {
	known := map[string]string{"youtube": "YouTube", "facebook": "Facebook", "instagram": "Instagram", "tiktok": "TikTok", "whatsapp": "WhatsApp", "netflix": "Netflix", "twitter": "X (Twitter)", "snapchat": "Snapchat", "telegram": "Telegram"}
	if v, ok := known[strings.ToLower(key)]; ok {
		return v
	}
	if key == "" {
		return key
	}
	return strings.ToUpper(key[:1]) + key[1:]
}

// identities maps IP addresses to the device behind them.
func (s *SecurityScanService) identities(ctx context.Context, orgID uuid.UUID) map[string]DeviceIdentity {
	out := map[string]DeviceIdentity{}
	list, err := s.inventory.List(ctx, orgID)
	if err != nil {
		return out
	}
	for _, c := range list.Clients {
		if c.IP == "" || c.IP == "0.0.0.0" {
			continue
		}
		if existing, ok := out[c.IP]; ok && existing.MAC != "" && !c.Online {
			continue // an online device owns the address
		}
		out[c.IP] = DeviceIdentity{MAC: c.MAC, Name: c.DisplayName, Kind: c.Kind}
	}
	return out
}

// resolveOwners looks up the reverse DNS name of the busiest unlabeled
// destinations. It is bounded in number and time, and cached.
func (s *SecurityScanService) resolveOwners(ctx context.Context, flows []Flow, lb *labeler) {
	bytesTo := map[string]int64{}
	for _, f := range flows {
		if isPrivateIP(f.DstIP) || lb.platformOf(f.DstIP) != "" {
			continue
		}
		bytesTo[f.DstIP] += f.Up + f.Down + 1
	}
	type dst struct {
		ip    string
		bytes int64
	}
	var list []dst
	for ip, b := range bytesTo {
		list = append(list, dst{ip, b})
	}
	sort.Slice(list, func(i, j int) bool { return list[i].bytes > list[j].bytes })
	if len(list) > ptrMaxLookups {
		list = list[:ptrMaxLookups]
	}

	var mu sync.Mutex
	var wg sync.WaitGroup
	sem := make(chan struct{}, 8)
	budget, cancel := context.WithTimeout(ctx, ptrLookupBudget)
	defer cancel()
	for _, d := range list {
		if owner, ok := s.cachedOwner(d.ip); ok {
			if owner != "" {
				lb.owners[d.ip] = owner
			}
			continue
		}
		wg.Add(1)
		sem <- struct{}{}
		go func(ip string) {
			defer wg.Done()
			defer func() { <-sem }()
			lookupCtx, cancelOne := context.WithTimeout(budget, ptrLookupTimeout)
			defer cancelOne()
			names, err := s.lookupAddr(lookupCtx, ip)
			owner := ""
			if err == nil && len(names) > 0 {
				owner = providerFromPTR(names[0])
			}
			s.storeOwner(ip, owner)
			if owner != "" {
				mu.Lock()
				lb.owners[ip] = owner
				mu.Unlock()
			}
		}(d.ip)
	}
	wg.Wait()
}

func (s *SecurityScanService) cachedOwner(ip string) (string, bool) {
	s.ptrMu.Lock()
	defer s.ptrMu.Unlock()
	e, ok := s.ptrCache[ip]
	if !ok || time.Since(e.at) > ptrCacheFor {
		return "", false
	}
	return e.owner, true
}

func (s *SecurityScanService) storeOwner(ip, owner string) {
	s.ptrMu.Lock()
	defer s.ptrMu.Unlock()
	if len(s.ptrCache) > 20000 {
		s.ptrCache = make(map[string]ptrEntry)
	}
	s.ptrCache[ip] = ptrEntry{owner: owner, at: time.Now()}
}

// persist stores the scan so trends survive a restart. Failure is logged and
// does not fail the scan.
func (s *SecurityScanService) persist(ctx context.Context, orgID uuid.UUID, snap *ScanSnapshot) {
	var flows []repository.FlowRow
	for _, d := range snap.Devices {
		for _, l := range d.Top {
			flows = append(flows, repository.FlowRow{MAC: d.MAC, IP: d.IP, Label: l.Name, Kind: l.Kind, Down: l.Down, Up: l.Up, Connections: l.Connections})
		}
	}
	var findings []repository.FindingRow
	for i, f := range snap.Findings {
		if i >= maxFindingsStored {
			break
		}
		findings = append(findings, repository.FindingRow{MAC: f.MAC, IP: f.IP, Severity: f.Severity, Code: f.Code, Title: f.Title, Detail: f.Detail})
	}
	id, err := s.repo.InsertScan(ctx, orgID, repository.ScanRecord{
		TakenAt: snap.TakenAt, Connections: snap.Connections, Devices: len(snap.Devices), DurationMs: snap.DurationMs,
		RouterCPUBefore: snap.RouterCPUBefore, RouterCPUAfter: snap.RouterCPUAfter,
	}, flows, findings)
	if err != nil {
		logger.Warn("Security scan not stored", "error", err)
		return
	}
	snap.ID = id
}

// Popular ranks destinations over the last days by how many devices used them.
func (s *SecurityScanService) Popular(ctx context.Context, orgID uuid.UUID, days int) ([]repository.PopularLabel, error) {
	return s.repo.Popular(ctx, orgID, time.Now().AddDate(0, 0, -days), 12)
}

// DeviceHistory ranks one device's destinations over the last days.
func (s *SecurityScanService) DeviceHistory(ctx context.Context, orgID uuid.UUID, mac string, days int) ([]repository.PopularLabel, error) {
	if mac == "" {
		return []repository.PopularLabel{}, nil
	}
	return s.repo.DeviceLabels(ctx, orgID, mac, time.Now().AddDate(0, 0, -days), 15)
}

// NewDevices lists devices first seen since the given time, newest first.
func (s *SecurityScanService) NewDevices(ctx context.Context, orgID uuid.UUID, since time.Time) []ClientView {
	list, err := s.inventory.List(ctx, orgID)
	if err != nil {
		return nil
	}
	var out []ClientView
	for _, c := range list.Clients {
		if c.FirstSeen != nil && c.FirstSeen.After(since) {
			out = append(out, c)
		}
	}
	sort.Slice(out, func(i, j int) bool { return out[i].FirstSeen.After(*out[j].FirstSeen) })
	return out
}

// Device returns what the latest scan saw for a MAC address or IP.
func (s *SecurityScanService) Device(ctx context.Context, orgID uuid.UUID, key string) (*DeviceActivity, *ScanSnapshot) {
	snap := s.Latest(ctx, orgID)
	if snap == nil {
		return nil, nil
	}
	key = strings.ToUpper(strings.TrimSpace(key))
	for i := range snap.Devices {
		d := snap.Devices[i]
		if strings.ToUpper(d.MAC) == key || d.IP == strings.TrimSpace(key) {
			return &d, snap
		}
	}
	return nil, snap
}

// MonitoringSince is when the first device was recorded. A device counts as new
// only if it appeared after that; during the first day everything looks new.
func (s *SecurityScanService) MonitoringSince(ctx context.Context, orgID uuid.UUID) *time.Time {
	list, err := s.inventory.List(ctx, orgID)
	if err != nil {
		return nil
	}
	var first *time.Time
	for _, c := range list.Clients {
		if c.FirstSeen != nil && (first == nil || c.FirstSeen.Before(*first)) {
			t := *c.FirstSeen
			first = &t
		}
	}
	return first
}

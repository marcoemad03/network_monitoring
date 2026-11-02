package services

import (
	"context"
	"fmt"
	"regexp"
	"sort"
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
	clientFlushEvery   = 60 * time.Second
	clientMaxGap       = 2 * time.Minute
	clientOnlineIdle   = 300  // seconds without traffic before a hotspot host counts as gone
	clientLeaseSeen    = 600  // seconds
	clientKnownLimit   = 2000 // devices remembered and listed
	maxDisplayNameLen  = 80
	maxNoteLen         = 500
	clientPollTimeout  = 25 * time.Second
	clientUsageHistory = 90 // days returned by the per-device usage endpoint
)

var macPattern = regexp.MustCompile(`^([0-9A-F]{2}:){5}[0-9A-F]{2}$`)

// LiveClient is a device as the router sees it right now.
type LiveClient struct {
	MAC           string
	IP            string
	Hostname      string
	RouterComment string
	Network       string
	Authorized    bool
	Online        bool
	HasCounters   bool
	// BytesDown is data sent to the device, BytesUp data received from it, both
	// as session counters of the hotspot.
	BytesDown, BytesUp int64
	UptimeSeconds      int64
	IdleSeconds        int64
	// ArpInterface is the router interface the ARP entry was learned on.
	ArpInterface string
	DownBps, UpBps     int64
}

// ClientInventoryService keeps a picture of the devices on the network: who is
// online, what each one is, and how much each one used. It reads the router
// without ever writing to it.
type ClientInventoryService struct {
	repo         *repository.ClientRepository
	internetRepo *repository.InternetRepository
	cfg          *config.Config
	dial         func(*models.VendorIntegration, *config.Config) (routerCommander, error)

	mu       sync.RWMutex
	states   map[uuid.UUID]*inventoryState
	interval time.Duration
}

type inventoryState struct {
	live      []LiveClient
	prev      map[string]counterReading // rx = download counter, tx = upload counter
	pendDown  map[string]int64
	pendUp    map[string]int64
	lastFlush time.Time
	updatedAt time.Time
	err       string
	ready     bool
}

func NewClientInventoryService(repo *repository.ClientRepository, internetRepo *repository.InternetRepository, cfg *config.Config) *ClientInventoryService {
	return &ClientInventoryService{
		repo: repo, internetRepo: internetRepo, cfg: cfg,
		dial:   dialRouterConnection,
		states: make(map[uuid.UUID]*inventoryState),
	}
}

// Start polls the router until ctx ends. interval <= 0 disables it.
func (s *ClientInventoryService) Start(ctx context.Context, interval time.Duration, orgs func(context.Context) ([]uuid.UUID, error)) {
	if interval <= 0 {
		logger.Info("Client inventory disabled")
		return
	}
	s.interval = interval
	go func() {
		ticker := time.NewTicker(interval)
		defer ticker.Stop()
		for {
			ids, err := orgs(ctx)
			if err != nil {
				logger.Warn("Client inventory: list organizations failed", "error", err)
			}
			for _, id := range ids {
				pollCtx, cancel := context.WithTimeout(ctx, clientPollTimeout)
				s.Poll(pollCtx, id)
				cancel()
			}
			select {
			case <-ctx.Done():
				return
			case <-ticker.C:
			}
		}
	}()
}

func (s *ClientInventoryService) state(orgID uuid.UUID) *inventoryState {
	st := s.states[orgID]
	if st == nil {
		st = &inventoryState{prev: map[string]counterReading{}, pendDown: map[string]int64{}, pendUp: map[string]int64{}}
		s.states[orgID] = st
	}
	return st
}

func (s *ClientInventoryService) fail(orgID uuid.UUID, err error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	s.state(orgID).err = err.Error()
}

// Poll reads the router once and updates the picture.
func (s *ClientInventoryService) Poll(ctx context.Context, orgID uuid.UUID) {
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

	clients, err := readClients(sess)
	if err != nil {
		s.fail(orgID, err)
		return
	}
	now := time.Now()

	s.mu.Lock()
	st := s.state(orgID)
	st.apply(clients, now)
	st.live, st.updatedAt, st.err, st.ready = clients, now, "", true
	flush := st.lastFlush.IsZero() || now.Sub(st.lastFlush) >= clientFlushEvery
	var seen []repository.SeenClient
	var macs []string
	var down, up []int64
	if flush {
		for _, c := range clients {
			if c.Online {
				seen = append(seen, repository.SeenClient{MAC: c.MAC, IP: c.IP, Hostname: c.Hostname, RouterComment: c.RouterComment, Network: c.Network})
			}
		}
		for mac := range st.pendDown {
			macs = append(macs, mac)
		}
		for mac := range st.pendUp {
			if _, ok := st.pendDown[mac]; !ok {
				macs = append(macs, mac)
			}
		}
		sort.Strings(macs)
		for _, mac := range macs {
			down = append(down, st.pendDown[mac])
			up = append(up, st.pendUp[mac])
		}
		st.lastFlush = now
	}
	s.mu.Unlock()

	if !flush {
		return
	}
	if err := s.repo.MarkSeen(ctx, orgID, now, seen); err != nil {
		logger.Warn("Client inventory: devices not stored", "error", err)
	}
	day := time.Date(now.Year(), now.Month(), now.Day(), 0, 0, 0, 0, now.Location())
	if err := s.repo.AddUsage(ctx, orgID, day, macs, down, up); err != nil {
		logger.Warn("Client inventory: usage not stored", "error", err)
		return
	}
	s.mu.Lock()
	for _, mac := range macs {
		delete(st.pendDown, mac)
		delete(st.pendUp, mac)
	}
	s.mu.Unlock()
}

// apply turns the new byte counters into speeds and pending daily usage.
func (st *inventoryState) apply(clients []LiveClient, now time.Time) {
	next := make(map[string]counterReading, len(clients))
	for i := range clients {
		c := &clients[i]
		if !c.HasCounters {
			continue
		}
		cur := counterReading{rx: c.BytesDown, tx: c.BytesUp, at: now}
		if prev, ok := st.prev[c.MAC]; ok {
			if r := computeRate(prev, cur, clientMaxGap); r.valid {
				st.pendDown[c.MAC] += r.rxDelta
				st.pendUp[c.MAC] += r.txDelta
				if !r.gap {
					c.DownBps, c.UpBps = r.rxBps, r.txBps
				}
			}
		}
		next[c.MAC] = cur
	}
	st.prev = next
}

func readClients(conn routerCommander) ([]LiveClient, error) {
	var errs []string
	read := func(path string, props string) []map[string]string {
		rows, err := conn.Command(path, "=.proplist="+props)
		if err != nil {
			errs = append(errs, fmt.Sprintf("%s: %v", path, err))
			return nil
		}
		return rows
	}
	hosts := read("/ip/hotspot/host/print", "mac-address,address,server,bytes-in,bytes-out,uptime,idle-time,comment,authorized")
	leases := read("/ip/dhcp-server/lease/print", "mac-address,address,host-name,status,last-seen,server")
	arps := read("/ip/arp/print", "address,mac-address,interface,complete,invalid")
	if len(errs) == 3 {
		return nil, fmt.Errorf("read router clients: %s", strings.Join(errs, "; "))
	}
	return mergeClientTables(hosts, leases, arps), nil
}

func normalizeMAC(v string) string {
	mac := strings.ToUpper(strings.TrimSpace(v))
	if macPattern.MatchString(mac) {
		return mac
	}
	return ""
}

// mergeClientTables joins the hotspot, DHCP and ARP tables by MAC address.
func mergeClientTables(hosts, leases, arps []map[string]string) []LiveClient {
	type entry struct {
		LiveClient
		hasHost, leaseBound, arpPresent bool
		leaseSeen                       int64
	}
	byMAC := map[string]*entry{}
	get := func(mac string) *entry {
		e := byMAC[mac]
		if e == nil {
			e = &entry{LiveClient: LiveClient{MAC: mac}, leaseSeen: -1}
			byMAC[mac] = e
		}
		return e
	}

	for _, r := range hosts {
		mac := normalizeMAC(r["mac-address"])
		if mac == "" {
			continue
		}
		e := get(mac)
		e.hasHost = true
		e.HasCounters = true
		e.IP = pickText(e.IP, r["address"])
		e.Network = pickText(e.Network, r["server"])
		e.BytesUp = parseCounter(r["bytes-in"])
		e.BytesDown = parseCounter(r["bytes-out"])
		e.UptimeSeconds = parseRouterUptime(r["uptime"])
		e.IdleSeconds = parseRouterUptime(r["idle-time"])
		e.RouterComment = decodeRouterText(strings.TrimSpace(r["comment"]))
		e.Authorized = isRouterTrue(r["authorized"])
	}
	for _, r := range leases {
		mac := normalizeMAC(r["mac-address"])
		if mac == "" {
			continue
		}
		e := get(mac)
		e.IP = pickText(e.IP, r["address"])
		e.Network = pickText(e.Network, r["server"])
		if host := cleanHostname(decodeRouterText(r["host-name"])); host != "" {
			e.Hostname = host
		}
		if strings.EqualFold(r["status"], "bound") {
			e.leaseBound = true
		}
		if r["last-seen"] != "" {
			e.leaseSeen = parseRouterUptime(r["last-seen"])
		}
	}
	for _, r := range arps {
		mac := normalizeMAC(r["mac-address"])
		if mac == "" || !isRouterTrue(r["complete"]) || isRouterTrue(r["invalid"]) {
			continue
		}
		e := get(mac)
		e.arpPresent = true
		e.ArpInterface = pickText(e.ArpInterface, r["interface"])
		e.IP = pickText(e.IP, r["address"])
		e.Network = pickText(e.Network, r["interface"])
	}

	out := make([]LiveClient, 0, len(byMAC))
	for _, e := range byMAC {
		switch {
		case e.hasHost:
			e.Online = e.IdleSeconds <= clientOnlineIdle
		default:
			e.Online = (e.leaseBound && e.leaseSeen >= 0 && e.leaseSeen <= clientLeaseSeen) || e.arpPresent
		}
		out = append(out, e.LiveClient)
	}
	sort.Slice(out, func(i, j int) bool { return out[i].MAC < out[j].MAC })
	return out
}

func pickText(a, b string) string {
	if strings.TrimSpace(a) != "" {
		return a
	}
	return strings.TrimSpace(b)
}

func parseCounter(v string) int64 {
	var n int64
	for _, c := range strings.TrimSpace(v) {
		if c < '0' || c > '9' {
			return 0
		}
		n = n*10 + int64(c-'0')
	}
	return n
}

// ---------------------------------------------------------------------------
// Queries

// ClientView is one device as the UI shows it.
type ClientView struct {
	// ArpInterface is where the router learned the device; used to place it on the map.
	ArpInterface string `json:"-"`
	// LastPort is the router port the device was last seen on.
	LastPort string `json:"-"`
	MAC         string     `json:"mac"`
	IP          string     `json:"ip"`
	Hostname    string     `json:"hostname"`
	DisplayName string     `json:"display_name"`
	NameSource  string     `json:"name_source"` // custom | hostname | guess | ip
	Kind        string     `json:"kind"`
	KindSource  string     `json:"kind_source"` // custom | detected
	Brand       string     `json:"brand,omitempty"`
	Vendor      string     `json:"vendor,omitempty"`
	Confidence  string     `json:"confidence"`
	KindReason  string     `json:"kind_reason"`
	PrivateMAC  bool       `json:"private_mac"`
	Online      bool       `json:"online"`
	Network     string     `json:"network"`
	Authorized  bool       `json:"authorized"`
	HasCounters bool       `json:"has_counters"`
	Note        string     `json:"note"`
	RouterNote  string     `json:"router_comment"`
	FirstSeen   *time.Time `json:"first_seen,omitempty"`
	LastSeen    *time.Time `json:"last_seen,omitempty"`
	UptimeSecs  int64      `json:"uptime_seconds"`
	IdleSecs    int64      `json:"idle_seconds"`
	DownloadBps int64      `json:"download_bps"`
	UploadBps   int64      `json:"upload_bps"`
	SessionDown int64      `json:"session_download_bytes"`
	SessionUp   int64      `json:"session_upload_bytes"`
	TodayDown   int64      `json:"today_download_bytes"`
	TodayUp     int64      `json:"today_upload_bytes"`
	MonthDown   int64      `json:"month_download_bytes"`
	MonthUp     int64      `json:"month_upload_bytes"`
}

// ClientSummary totals the list.
type ClientSummary struct {
	Online      int            `json:"online"`
	Known       int            `json:"known"`
	ByKind      map[string]int `json:"online_by_kind"`
	DownloadBps int64          `json:"download_bps"`
	UploadBps   int64          `json:"upload_bps"`
	TodayDown   int64          `json:"today_download_bytes"`
	TodayUp     int64          `json:"today_upload_bytes"`
}

// ClientList is the response of the inventory endpoint.
type ClientList struct {
	Available bool          `json:"available"`
	Error     string        `json:"error,omitempty"`
	Stale     bool          `json:"stale"`
	UpdatedAt *time.Time    `json:"updated_at,omitempty"`
	Summary   ClientSummary `json:"summary"`
	Clients   []ClientView  `json:"clients"`
}

// List returns every device the router sees now plus the ones remembered from
// earlier, with detection, notes and usage merged in.
func (s *ClientInventoryService) List(ctx context.Context, orgID uuid.UUID) (ClientList, error) {
	s.mu.RLock()
	st := s.states[orgID]
	var live []LiveClient
	var updated time.Time
	var pollErr string
	ready := false
	if st != nil {
		live = append(live, st.live...)
		updated, pollErr, ready = st.updatedAt, st.err, st.ready
	}
	s.mu.RUnlock()

	known, err := s.repo.Known(ctx, orgID, clientKnownLimit)
	if err != nil {
		return ClientList{}, err
	}
	notes, err := s.repo.Notes(ctx, orgID)
	if err != nil {
		return ClientList{}, err
	}
	now := time.Now()
	today := time.Date(now.Year(), now.Month(), now.Day(), 0, 0, 0, 0, now.Location())
	monthStart := time.Date(now.Year(), now.Month(), 1, 0, 0, 0, 0, now.Location())
	usage, err := s.repo.Usage(ctx, orgID, today, monthStart)
	if err != nil {
		return ClientList{}, err
	}

	out := ClientList{Available: ready, Error: pollErr, Clients: []ClientView{}, Summary: ClientSummary{ByKind: map[string]int{}}}
	if ready {
		out.UpdatedAt = &updated
		interval := s.interval
		if interval <= 0 {
			interval = 30 * time.Second
		}
		out.Stale = now.Sub(updated) > 4*interval
	}

	views := map[string]*ClientView{}
	for _, k := range known {
		first, last := k.FirstSeen, k.LastSeen
		views[k.MAC] = &ClientView{
			MAC: k.MAC, IP: k.LastIP, Hostname: k.Hostname, Network: k.Network, RouterNote: k.RouterComment,
			FirstSeen: &first, LastSeen: &last, LastPort: k.LastPort,
		}
	}
	for _, c := range live {
		v := views[c.MAC]
		if v == nil {
			v = &ClientView{MAC: c.MAC}
			views[c.MAC] = v
		}
		v.IP = pickText(c.IP, v.IP)
		v.Hostname = pickText(c.Hostname, v.Hostname)
		v.Network = pickText(c.Network, v.Network)
		v.RouterNote = c.RouterComment
		v.Online, v.Authorized, v.HasCounters = c.Online, c.Authorized, c.HasCounters
		v.UptimeSecs, v.IdleSecs = c.UptimeSeconds, c.IdleSeconds
		v.DownloadBps, v.UploadBps = c.DownBps, c.UpBps
		v.SessionDown, v.SessionUp = c.BytesDown, c.BytesUp
		v.ArpInterface = c.ArpInterface
		if c.Online {
			seen := updated
			v.LastSeen = &seen
		}
	}

	for mac, v := range views {
		describeClient(v, notes[mac])
		u := usage[mac]
		v.TodayDown, v.TodayUp, v.MonthDown, v.MonthUp = u.TodayDown, u.TodayUp, u.MonthDown, u.MonthUp
		out.Clients = append(out.Clients, *v)
		out.Summary.Known++
		out.Summary.TodayDown += u.TodayDown
		out.Summary.TodayUp += u.TodayUp
		if v.Online {
			out.Summary.Online++
			out.Summary.ByKind[v.Kind]++
			out.Summary.DownloadBps += v.DownloadBps
			out.Summary.UploadBps += v.UploadBps
		}
	}
	sort.Slice(out.Clients, func(i, j int) bool {
		a, b := out.Clients[i], out.Clients[j]
		if a.Online != b.Online {
			return a.Online
		}
		if a.TodayDown+a.TodayUp != b.TodayDown+b.TodayUp {
			return a.TodayDown+a.TodayUp > b.TodayDown+b.TodayUp
		}
		return a.MAC < b.MAC
	})
	return out, nil
}

// describeClient fills in the name, kind and notes of a device.
func describeClient(v *ClientView, note repository.ClientNote) {
	v.Hostname = cleanHostname(v.Hostname)
	guess := ClassifyDevice(v.Hostname, v.MAC, v.RouterNote)
	v.PrivateMAC = IsPrivateMAC(v.MAC)
	v.Vendor = ShortVendor(guess.Vendor)
	v.Kind, v.Brand, v.Confidence, v.KindReason, v.KindSource = guess.Kind, guess.Brand, guess.Confidence, guess.Reason, "detected"
	if validKind(note.KindOverride) {
		v.Kind, v.Confidence, v.KindReason, v.KindSource = note.KindOverride, ConfidenceHigh, "set by you", "custom"
	}
	v.Note = note.Note

	switch {
	case strings.TrimSpace(note.DisplayName) != "":
		v.DisplayName, v.NameSource = note.DisplayName, "custom"
	case strings.TrimSpace(v.Hostname) != "":
		v.DisplayName, v.NameSource = v.Hostname, "hostname"
	case v.Brand != "" && v.Kind != KindUnknown:
		// Many devices share a guess, so the address keeps the names apart.
		v.DisplayName, v.NameSource = strings.TrimSpace(v.Brand+" "+v.Kind+" · "+v.IP), "guess"
	default:
		v.DisplayName, v.NameSource = pickText(v.IP, v.MAC), "ip"
	}
}

var kinds = map[string]bool{
	KindPhone: true, KindTablet: true, KindComputer: true, KindPrinter: true, KindCamera: true,
	KindTV: true, KindNetwork: true, KindServer: true, KindIoT: true, KindMedical: true, KindUnknown: true,
}

func validKind(k string) bool { return kinds[k] }

// NoteInput is what the user may change on a device. Nil fields are left as they are.
type NoteInput struct {
	DisplayName *string
	Note        *string
	Kind        *string
	Place       *string
}

// ClientNoteError is returned for input that cannot be saved.
type ClientNoteError struct{ Message string }

func (e *ClientNoteError) Error() string { return e.Message }

// SaveNote validates and stores the user's name, comment and kind for a device.
func (s *ClientInventoryService) SaveNote(ctx context.Context, orgID uuid.UUID, mac string, in NoteInput) (repository.ClientNote, error) {
	mac = normalizeMAC(mac)
	if mac == "" {
		return repository.ClientNote{}, &ClientNoteError{"Invalid MAC address"}
	}
	patch := repository.NotePatch{}
	if in.DisplayName != nil {
		v := strings.TrimSpace(*in.DisplayName)
		if len([]rune(v)) > maxDisplayNameLen {
			return repository.ClientNote{}, &ClientNoteError{fmt.Sprintf("The name can be at most %d characters", maxDisplayNameLen)}
		}
		patch.DisplayName = &v
	}
	if in.Note != nil {
		v := strings.TrimSpace(*in.Note)
		if len([]rune(v)) > maxNoteLen {
			return repository.ClientNote{}, &ClientNoteError{fmt.Sprintf("The comment can be at most %d characters", maxNoteLen)}
		}
		patch.Note = &v
	}
	if in.Place != nil {
		v := strings.TrimSpace(*in.Place)
		if len([]rune(v)) > maxDisplayNameLen {
			return repository.ClientNote{}, &ClientNoteError{fmt.Sprintf("The place can be at most %d characters", maxDisplayNameLen)}
		}
		patch.Place = &v
	}
	if in.Kind != nil {
		v := strings.TrimSpace(*in.Kind)
		if v != "" && !validKind(v) {
			return repository.ClientNote{}, &ClientNoteError{"Unknown device type"}
		}
		patch.KindOverride = &v
	}
	return s.repo.SaveNote(ctx, orgID, mac, patch)
}

// Usage returns one device's daily usage for the last days (at most 90).
func (s *ClientInventoryService) Usage(ctx context.Context, orgID uuid.UUID, mac string, days int) ([]repository.ClientDay, error) {
	mac = normalizeMAC(mac)
	if mac == "" {
		return nil, &ClientNoteError{"Invalid MAC address"}
	}
	if days < 1 {
		days = 7
	}
	if days > clientUsageHistory {
		days = clientUsageHistory
	}
	now := time.Now()
	since := time.Date(now.Year(), now.Month(), now.Day(), 0, 0, 0, 0, now.Location()).AddDate(0, 0, -(days - 1))
	return s.repo.Daily(ctx, orgID, mac, since)
}

// LiveIPs returns the address of every device the router sees online now, by MAC.
func (s *ClientInventoryService) LiveIPs(orgID uuid.UUID) map[string]string {
	s.mu.RLock()
	defer s.mu.RUnlock()
	out := map[string]string{}
	if st := s.states[orgID]; st != nil {
		for _, c := range st.live {
			if c.Online && c.IP != "" {
				out[c.MAC] = c.IP
			}
		}
	}
	return out
}

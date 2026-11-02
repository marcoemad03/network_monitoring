package services

import (
	"context"
	"fmt"
	"sort"
	"strings"
	"sync"
	"time"

	"github.com/google/uuid"
	"github.com/hospital/nms-backend/internal/config"
	"github.com/hospital/nms-backend/internal/models"
	"github.com/hospital/nms-backend/internal/repository"
	"github.com/hospital/nms-backend/pkg/mikrotik"
)

const (
	topologyTTL       = 60 * time.Second // the router is read at most this often
	topologyMinForce  = 15 * time.Second // a refresh button cannot hammer the router
	topologyTimeout   = 20 * time.Second
	topologyMaxGap    = 3 * time.Minute
	topologyPortLimit = 128
)

// RouterPort is one interface of the router.
type RouterPort struct {
	Name     string
	Type     string
	Comment  string
	Bridge   string // bridge this port belongs to, if any
	Running  bool
	Disabled bool
	RxBps    int64 // traffic received on the port
	TxBps    int64
}

// Physical reports whether the port is a cable or radio port rather than a bridge,
// VLAN or tunnel.
func (p RouterPort) Physical() bool {
	switch p.Type {
	case "ether", "wlan", "sfp", "cap", "wifi":
		return true
	}
	return false
}

// WifiClient is what the router knows about a device on its wireless network.
type WifiClient struct {
	Interface string
	Signal    string
	SSID      string
}

// Neighbor is a device that announced itself to the router (MNDP, CDP, LLDP).
type Neighbor struct {
	MAC, IP, Identity, Platform, Board, Version, Interface string
}

// RouterTopology is a read-only picture of how the router is connected.
type RouterTopology struct {
	Identity  string
	Address   string
	Ports     map[string]*RouterPort
	HostPort  map[string]string // MAC -> port the bridge learned it on
	Wifi      map[string]WifiClient
	Neighbors []Neighbor
	ReadAt    time.Time
	Notes     []string // tables that could not be read

	// counters holds the raw byte counters of the last read: port -> {received, sent}.
	counters map[string][2]int64
}

// buildTopology turns the printed router tables into a RouterTopology.
func buildTopology(ifaces, bports, hosts, wifi, capsman, neighbors []map[string]string) RouterTopology {
	t := RouterTopology{
		Ports:    map[string]*RouterPort{},
		HostPort: map[string]string{},
		Wifi:     map[string]WifiClient{},
	}
	for _, r := range ifaces {
		name := strings.TrimSpace(r["name"])
		if name == "" || len(t.Ports) >= topologyPortLimit {
			continue
		}
		t.Ports[name] = &RouterPort{
			Name:     name,
			Type:     strings.TrimSpace(r["type"]),
			Comment:  decodeRouterText(strings.TrimSpace(r["comment"])),
			Running:  isRouterTrue(r["running"]),
			Disabled: isRouterTrue(r["disabled"]),
		}
	}
	for _, r := range bports {
		if p := t.Ports[strings.TrimSpace(r["interface"])]; p != nil {
			p.Bridge = strings.TrimSpace(r["bridge"])
		}
	}
	for _, r := range hosts {
		mac := normalizeMAC(r["mac-address"])
		on := strings.TrimSpace(r["on-interface"])
		if mac == "" || on == "" || isRouterTrue(r["local"]) || isRouterTrue(r["disabled"]) || isRouterTrue(r["invalid"]) {
			continue
		}
		if _, seen := t.HostPort[mac]; !seen {
			t.HostPort[mac] = on
		}
	}
	for _, r := range wifi {
		if mac := normalizeMAC(r["mac-address"]); mac != "" {
			t.Wifi[mac] = WifiClient{Interface: strings.TrimSpace(r["interface"]), Signal: strings.TrimSpace(r["signal-strength"])}
		}
	}
	for _, r := range capsman {
		if mac := normalizeMAC(r["mac-address"]); mac != "" {
			t.Wifi[mac] = WifiClient{Interface: strings.TrimSpace(r["interface"]), Signal: strings.TrimSpace(r["rx-signal"]), SSID: strings.TrimSpace(r["ssid"])}
		}
	}
	for _, r := range neighbors {
		mac := normalizeMAC(r["mac-address"])
		if mac == "" {
			continue
		}
		t.Neighbors = append(t.Neighbors, Neighbor{
			MAC: mac, IP: strings.TrimSpace(r["address"]), Identity: decodeRouterText(strings.TrimSpace(r["identity"])),
			Platform: strings.TrimSpace(r["platform"]), Board: strings.TrimSpace(r["board"]),
			Version: strings.TrimSpace(r["version"]), Interface: firstInterface(r["interface"]),
		})
	}
	sort.Slice(t.Neighbors, func(i, j int) bool { return t.Neighbors[i].MAC < t.Neighbors[j].MAC })
	return t
}

// firstInterface keeps the first of a "ether2,bridge1" style list.
func firstInterface(v string) string {
	if i := strings.IndexByte(v, ','); i >= 0 {
		v = v[:i]
	}
	return strings.TrimSpace(v)
}

// TopologyService reads how the router is wired: ports, which device is behind
// which port, wireless clients and neighbours. It only ever prints tables, never
// writes, and caches the answer so the router is not read more than once a minute.
type TopologyService struct {
	internetRepo *repository.InternetRepository
	cfg          *config.Config
	dial         func(*models.VendorIntegration, *config.Config) (routerCommander, error)

	mu    sync.Mutex
	state map[uuid.UUID]*topologyState
}

type topologyState struct {
	topo    RouterTopology
	ready   bool
	err     string
	tried   time.Time
	prev    map[string]counterReading
	reading bool
}

func NewTopologyService(internetRepo *repository.InternetRepository, cfg *config.Config) *TopologyService {
	return &TopologyService{internetRepo: internetRepo, cfg: cfg, dial: dialRouterConnection, state: map[uuid.UUID]*topologyState{}}
}

// Topology is the cached picture of the router together with how fresh it is.
type TopologyResult struct {
	Topology RouterTopology
	Ready    bool
	Error    string
}

// Get returns the cached topology, reading the router first when the cache is
// older than a minute (or older than 15 seconds when force is set).
func (s *TopologyService) Get(ctx context.Context, orgID uuid.UUID, force bool) TopologyResult {
	s.mu.Lock()
	st := s.state[orgID]
	if st == nil {
		st = &topologyState{prev: map[string]counterReading{}}
		s.state[orgID] = st
	}
	age := time.Since(st.tried)
	limit := topologyTTL
	if force {
		limit = topologyMinForce
	}
	if st.reading || (!st.tried.IsZero() && age < limit) {
		res := TopologyResult{Topology: st.topo, Ready: st.ready, Error: st.err}
		s.mu.Unlock()
		return res
	}
	st.reading = true
	st.tried = time.Now()
	s.mu.Unlock()

	topo, err := s.read(ctx, orgID)

	s.mu.Lock()
	defer s.mu.Unlock()
	st.reading = false
	switch {
	case err != nil:
		st.err = err.Error()
	case topo == nil:
		// Another router job held the connection; keep the last picture and try soon.
		st.tried = time.Now().Add(-topologyTTL + 5*time.Second)
	default:
		s.applyRates(st, topo)
		st.topo, st.ready, st.err = *topo, true, ""
	}
	return TopologyResult{Topology: st.topo, Ready: st.ready, Error: st.err}
}

func (s *TopologyService) applyRates(st *topologyState, topo *RouterTopology) {
	next := make(map[string]counterReading, len(topo.Ports))
	for name, p := range topo.Ports {
		rd, ok := topo.counters[name]
		if !ok {
			continue
		}
		cur := counterReading{rx: rd[0], tx: rd[1], at: topo.ReadAt}
		if prev, ok := st.prev[name]; ok {
			if r := computeRate(prev, cur, topologyMaxGap); r.valid && !r.gap {
				p.RxBps, p.TxBps = r.rxBps, r.txBps
			}
		}
		next[name] = cur
	}
	st.prev = next
	topo.counters = nil
}

func (s *TopologyService) read(ctx context.Context, orgID uuid.UUID) (*RouterTopology, error) {
	vendor, err := s.internetRepo.GetActiveMikroTikIntegration(ctx, orgID)
	if err != nil {
		return nil, fmt.Errorf("no active MikroTik integration")
	}
	readCtx, cancel := context.WithTimeout(ctx, topologyTimeout)
	defer cancel()
	sess, err := openRouterSessionWith(readCtx, vendor, s.cfg, s.dial, false, false)
	if err != nil {
		return nil, fmt.Errorf("router unreachable: %w", err)
	}
	if sess == nil {
		return nil, nil
	}
	defer sess.Close()

	var notes []string
	optional := func(path, props string) []map[string]string {
		rows, err := sess.Command(path, "=.proplist="+props)
		if err != nil {
			notes = append(notes, strings.TrimSuffix(strings.TrimPrefix(path, "/"), "/print"))
			return nil
		}
		return rows
	}
	ifaceRows, err := sess.Command("/interface/print", "=.proplist=name,type,running,disabled,comment,rx-byte,tx-byte")
	if err != nil {
		return nil, fmt.Errorf("read router interfaces: %w", err)
	}
	bports := optional("/interface/bridge/port/print", "interface,bridge")
	hosts := optional("/interface/bridge/host/print", "mac-address,on-interface,bridge,local,disabled,invalid")
	wifi := optional("/interface/wireless/registration-table/print", "mac-address,interface,signal-strength")
	caps := optional("/caps-man/registration-table/print", "mac-address,interface,ssid,rx-signal")
	neigh := optional("/ip/neighbor/print", "mac-address,address,identity,platform,board,version,interface")
	var identity string
	if rows, err := sess.Command("/system/identity/print", "=.proplist=name"); err == nil && len(rows) > 0 {
		identity = decodeRouterText(strings.TrimSpace(rows[0]["name"]))
	}

	topo := buildTopology(ifaceRows, bports, hosts, wifi, caps, neigh)
	topo.Identity = identity
	topo.ReadAt = time.Now()
	topo.Notes = notes
	if host, _, err := mikrotik.ParseEndpoint(vendor.BaseURL); err == nil {
		topo.Address = host
	}
	topo.counters = make(map[string][2]int64, len(ifaceRows))
	for _, r := range ifaceRows {
		if name := strings.TrimSpace(r["name"]); name != "" {
			topo.counters[name] = [2]int64{parseCounter(r["rx-byte"]), parseCounter(r["tx-byte"])}
		}
	}
	return &topo, nil
}

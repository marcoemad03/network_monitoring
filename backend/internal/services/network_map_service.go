package services

import (
	"context"
	"sort"
	"strconv"
	"strings"
	"time"
	"unicode"

	"github.com/google/uuid"
	"github.com/hospital/nms-backend/internal/repository"
	"github.com/hospital/nms-backend/pkg/logger"
)

const (
	maxPlaceLen  = 80
	trunkDevices = 10 // more devices than this behind one port means it leads to another switch
)

// Extra kinds the map uses for registered equipment, next to the client kinds.
const (
	KindRouter      = "router"
	KindSwitch      = "switch"
	KindFirewall    = "firewall"
	KindAccessPoint = "access_point"
)

// MapWifi is the wireless link of a device.
type MapWifi struct {
	Interface string `json:"interface"`
	Signal    string `json:"signal,omitempty"`
	SSID      string `json:"ssid,omitempty"`
}

// MapDevice is one device on the network map.
type MapDevice struct {
	ID          string     `json:"id"`
	Source      string     `json:"source"` // router | client | equipment | neighbor
	Name        string     `json:"name"`
	NameSource  string     `json:"name_source"`
	IP          string     `json:"ip"`
	MAC         string     `json:"mac"`
	Hostname    string     `json:"hostname,omitempty"`
	Kind        string     `json:"kind"`
	KindCustom  bool       `json:"kind_custom"`
	Brand       string     `json:"brand,omitempty"`
	Vendor      string     `json:"vendor,omitempty"`
	Model       string     `json:"model,omitempty"`
	Confidence  string     `json:"confidence"`
	KindReason  string     `json:"kind_reason,omitempty"`
	Online      bool       `json:"online"`
	Status      string     `json:"status"` // online | offline | degraded
	Port        string     `json:"port"`
	PortSource  string     `json:"port_source"` // bridge | wifi | arp | remembered | registered | none
	Place       string     `json:"place"`
	PlaceSource string     `json:"place_source"` // custom | port_label | port_comment | port | registered | none
	Wifi        *MapWifi   `json:"wifi,omitempty"`
	Network     string     `json:"network,omitempty"`
	Note        string     `json:"note,omitempty"`
	Critical    bool       `json:"critical,omitempty"`
	LastSeen    *time.Time `json:"last_seen,omitempty"`
	PingMs      *float64   `json:"ping_ms,omitempty"`
	DownloadBps int64      `json:"download_bps"`
	UploadBps   int64      `json:"upload_bps"`
	TodayBytes  int64      `json:"today_bytes"`
	Registered  string     `json:"registered_id,omitempty"` // id in the equipment list, if registered
}

// MapPort is a router port with the devices behind it.
type MapPort struct {
	Name        string `json:"name"`
	Label       string `json:"label"`
	LabelSource string `json:"label_source"` // custom | comment | none
	Comment     string `json:"comment,omitempty"`
	Trunk       bool   `json:"trunk"` // many devices behind it: an uplink to another switch, not a place
	Type        string `json:"type"`
	Running     bool   `json:"running"`
	Disabled    bool   `json:"disabled"`
	Physical    bool   `json:"physical"`
	RxBps       int64  `json:"rx_bps"`
	TxBps       int64  `json:"tx_bps"`
	Devices     int    `json:"devices"`
	Online      int    `json:"online"`
}

// MapRouter is the router in the middle of the map.
type MapRouter struct {
	Name   string `json:"name"`
	IP     string `json:"ip"`
	Online bool   `json:"online"`
}

// MapSummary totals the map.
type MapSummary struct {
	Total     int            `json:"total"`
	Online    int            `json:"online"`
	Offline   int            `json:"offline"`
	Located   int            `json:"located"`
	Unplaced  int            `json:"unplaced"`
	Unnamed   int            `json:"unnamed"`
	ByKind    map[string]int `json:"by_kind"`
	OnlineKnd map[string]int `json:"online_by_kind"`
}

// NetworkMap is the response of the map endpoint.
type NetworkMap struct {
	Available     bool        `json:"available"`
	Error         string      `json:"error,omitempty"`
	Stale         bool        `json:"stale"`
	UpdatedAt     *time.Time  `json:"updated_at,omitempty"`
	TopologyAt    *time.Time  `json:"topology_at,omitempty"`
	TopologyError string      `json:"topology_error,omitempty"`
	TopologyNotes []string    `json:"topology_notes,omitempty"`
	Router        MapRouter   `json:"router"`
	Ports         []MapPort   `json:"ports"`
	Devices       []MapDevice `json:"devices"`
	Summary       MapSummary  `json:"summary"`
}

// NetworkMapService joins the live device list, the registered equipment and the
// router's wiring into one picture of the network.
type NetworkMapService struct {
	inventory *ClientInventoryService
	topology  *TopologyService
	clients   *repository.ClientRepository
	mon       *repository.MonitoringRepository
}

func NewNetworkMapService(inventory *ClientInventoryService, topology *TopologyService, clients *repository.ClientRepository, mon *repository.MonitoringRepository) *NetworkMapService {
	return &NetworkMapService{inventory: inventory, topology: topology, clients: clients, mon: mon}
}

// Build returns the current map. refresh asks for a fresh read of the router's
// wiring (still limited to once per 15 seconds).
func (s *NetworkMapService) Build(ctx context.Context, orgID uuid.UUID, refresh bool) (NetworkMap, error) {
	list, err := s.inventory.List(ctx, orgID)
	if err != nil {
		return NetworkMap{}, err
	}
	notes, err := s.clients.Notes(ctx, orgID)
	if err != nil {
		return NetworkMap{}, err
	}
	places, err := s.clients.Places(ctx, orgID)
	if err != nil {
		return NetworkMap{}, err
	}
	equipment, err := s.mon.ListMapDevices(ctx, orgID)
	if err != nil {
		return NetworkMap{}, err
	}
	topo := s.topology.Get(ctx, orgID, refresh)

	m := composeMap(list, notes, places, equipment, topo)

	// Remember where devices are so offline ones keep their place.
	var macs, ports []string
	for _, c := range list.Clients {
		for _, d := range m.Devices {
			if d.MAC == c.MAC && d.Online && d.Port != "" && d.PortSource != "remembered" && d.Source != "equipment" && d.Port != c.LastPort {
				macs, ports = append(macs, c.MAC), append(ports, d.Port)
			}
		}
	}
	if len(macs) > 0 {
		if err := s.clients.SetPorts(ctx, orgID, macs, ports); err != nil {
			logger.Warn("Network map: ports not stored", "error", err)
		}
	}
	return m, nil
}

// SavePlace names a router port. An empty label removes the name.
func (s *NetworkMapService) SavePlace(ctx context.Context, orgID uuid.UUID, port, label string) error {
	port, label = strings.TrimSpace(port), strings.TrimSpace(label)
	if port == "" || len([]rune(port)) > 64 {
		return &ClientNoteError{"Invalid port"}
	}
	if len([]rune(label)) > maxPlaceLen {
		return &ClientNoteError{"The name can be at most 80 characters"}
	}
	return s.clients.SavePlace(ctx, orgID, port, label)
}

// composeMap is the pure part of Build: it needs no database and no router.
func composeMap(list ClientList, notes map[string]repository.ClientNote, places map[string]string, equipment []repository.MapDeviceRow, topo TopologyResult) NetworkMap {
	t := topo.Topology
	m := NetworkMap{
		Available: list.Available || topo.Ready,
		Error:     list.Error,
		Stale:     list.Stale,
		UpdatedAt: list.UpdatedAt,
		Devices:   []MapDevice{},
		Ports:     []MapPort{},
	}
	if topo.Ready {
		at := t.ReadAt
		m.TopologyAt = &at
	}
	m.TopologyError = topo.Error
	m.TopologyNotes = t.Notes
	m.Router = MapRouter{Name: firstText(t.Identity, "Router"), IP: t.Address, Online: topo.Ready}

	portLabel := func(name string) (label, source string) {
		if l := strings.TrimSpace(places[name]); l != "" {
			return l, "custom"
		}
		if p := t.Ports[name]; p != nil && p.Comment != "" {
			return p.Comment, "comment"
		}
		return "", "none"
	}

	byMAC := map[string]int{}
	byIP := map[string]int{}
	add := func(d MapDevice) int {
		m.Devices = append(m.Devices, d)
		i := len(m.Devices) - 1
		if d.MAC != "" {
			byMAC[d.MAC] = i
		}
		if d.IP != "" {
			byIP[d.IP] = i
		}
		return i
	}

	for _, c := range list.Clients {
		if c.IP != "" && c.IP == t.Address {
			continue // the router itself
		}
		d := MapDevice{
			ID: "mac:" + c.MAC, Source: "client", Name: c.DisplayName, NameSource: c.NameSource,
			IP: c.IP, MAC: c.MAC, Hostname: c.Hostname, Kind: c.Kind, KindCustom: c.KindSource == "custom",
			Brand: c.Brand, Vendor: c.Vendor, Confidence: c.Confidence, KindReason: c.KindReason,
			Online: c.Online, Network: c.Network, Note: c.Note, LastSeen: c.LastSeen,
			DownloadBps: c.DownloadBps, UploadBps: c.UploadBps, TodayBytes: c.TodayDown + c.TodayUp,
		}
		d.Status = statusOf(d.Online, "")
		d.Port, d.PortSource = resolvePort(c.MAC, c.ArpInterface, c.LastPort, t, topo.Ready)
		if w, ok := t.Wifi[c.MAC]; ok {
			d.Wifi = &MapWifi{Interface: w.Interface, Signal: w.Signal, SSID: w.SSID}
		}
		add(d)
	}

	for _, n := range t.Neighbors {
		if n.IP != "" && n.IP == t.Address {
			continue
		}
		i, ok := byMAC[n.MAC]
		if !ok && n.IP != "" {
			i, ok = byIP[n.IP]
		}
		if !ok {
			i = add(MapDevice{
				ID: "mac:" + n.MAC, Source: "neighbor", IP: n.IP, MAC: n.MAC, Online: true, Status: "online",
				Kind: KindNetwork, Confidence: ConfidenceHigh, PortSource: "none", Name: firstText(n.Identity, n.IP, n.MAC), NameSource: "hostname",
			})
		}
		d := &m.Devices[i]
		if !d.KindCustom {
			d.Kind, d.Confidence, d.KindReason = KindNetwork, ConfidenceHigh, "announced itself to the router"
		}
		if d.NameSource != "custom" && n.Identity != "" {
			d.Name, d.NameSource = n.Identity, "hostname"
		}
		d.Model = firstText(d.Model, n.Board)
		d.Brand = firstText(d.Brand, n.Platform)
		if d.IP == "" {
			d.IP = n.IP
		}
		if d.Port == "" && n.Interface != "" {
			if _, known := t.Ports[n.Interface]; known || !topo.Ready {
				d.Port, d.PortSource = n.Interface, "bridge"
			}
		}
	}

	for _, e := range equipment {
		if e.IPAddress != "" && e.IPAddress == t.Address {
			continue
		}
		i, ok := -1, false
		if e.MAC != "" {
			i, ok = byMAC[e.MAC]
		}
		if !ok && e.IPAddress != "" {
			i, ok = byIP[e.IPAddress]
		}
		if !ok {
			online := e.Status == "online" || e.Status == "degraded"
			seen := e.LastSeen
			i = add(MapDevice{
				ID: "eq:" + e.ID.String(), Source: "equipment", IP: cleanIP(e.IPAddress), MAC: e.MAC, Online: online,
				Status: e.Status, Confidence: ConfidenceHigh, PortSource: "none", LastSeen: &seen, NameSource: "custom", Kind: KindUnknown,
			})
			if !online {
				m.Devices[i].Status = statusOf(false, e.Status)
			}
		}
		d := &m.Devices[i]
		d.Registered = e.ID.String()
		d.Critical = e.IsCritical
		d.PingMs = e.PingAvgMs
		if e.Name != "" && d.NameSource != "custom" || d.Source == "equipment" {
			d.Name, d.NameSource = firstText(e.Name, d.Name), "custom"
		}
		if k := equipmentKind(e.DeviceType); k != KindUnknown && !d.KindCustom {
			d.Kind, d.Confidence, d.KindReason = k, ConfidenceHigh, "registered as "+strings.ReplaceAll(e.DeviceType, "_", " ")
		}
		d.Vendor = firstText(d.Vendor, e.Vendor)
		d.Model = firstText(d.Model, e.Model)
		if d.Source == "client" && (e.Status == "online" || e.Status == "degraded") {
			d.Status = e.Status
		}
		if d.Port == "" && e.Port != "" {
			if _, known := t.Ports[e.Port]; known || !topo.Ready {
				d.Port, d.PortSource = e.Port, "registered"
			}
		}
		if e.Place != "" {
			d.Place, d.PlaceSource = e.Place, "registered"
		}
	}

	// A port with many devices behind it leads to another switch; it says nothing about where one device is.
	behind := map[string]int{}
	for _, d := range m.Devices {
		if d.Port != "" {
			behind[d.Port]++
		}
	}
	trunk := func(port string) bool { return behind[port] > trunkDevices }

	// Names, places and port counts.
	counts := map[string]*MapPort{}
	for name, p := range t.Ports {
		label, src := portLabel(name)
		counts[name] = &MapPort{
			Name: name, Label: label, LabelSource: src, Comment: p.Comment, Type: p.Type, Running: p.Running,
			Disabled: p.Disabled, Physical: p.Physical(), Trunk: trunk(name), RxBps: p.RxBps, TxBps: p.TxBps,
		}
	}
	m.Summary = MapSummary{ByKind: map[string]int{}, OnlineKnd: map[string]int{}}
	for i := range m.Devices {
		d := &m.Devices[i]
		if n, ok := notes[d.MAC]; ok && strings.TrimSpace(n.Place) != "" {
			d.Place, d.PlaceSource = strings.TrimSpace(n.Place), "custom"
		}
		if d.PlaceSource == "" || d.PlaceSource == "none" {
			d.Place, d.PlaceSource = "", "none"
		}
		if d.Port != "" && d.PlaceSource == "none" && !trunk(d.Port) {
			if label, src := portLabel(d.Port); label != "" {
				d.Place, d.PlaceSource = label, map[string]string{"custom": "port_label", "comment": "port_comment"}[src]
			} else {
				d.Place, d.PlaceSource = d.Port, "port"
			}
		}
		if d.Port != "" {
			p := counts[d.Port]
			if p == nil {
				label, src := portLabel(d.Port)
				p = &MapPort{Name: d.Port, Label: label, LabelSource: src, Running: true, Trunk: trunk(d.Port)}
				counts[d.Port] = p
			}
			p.Devices++
			if d.Online {
				p.Online++
			}
		}
		if d.Online {
			m.Summary.Online++
			m.Summary.OnlineKnd[d.Kind]++
		} else {
			m.Summary.Offline++
		}
		m.Summary.Total++
		m.Summary.ByKind[d.Kind]++
		if d.PlaceSource != "none" {
			m.Summary.Located++
		} else {
			m.Summary.Unplaced++
		}
		if d.NameSource == "ip" || d.NameSource == "guess" || d.Name == d.IP || d.Name == d.MAC {
			m.Summary.Unnamed++
		}
	}

	for _, p := range counts {
		if p.Physical || p.Devices > 0 {
			m.Ports = append(m.Ports, *p)
		}
	}
	sort.Slice(m.Ports, func(i, j int) bool { return naturalLess(m.Ports[i].Name, m.Ports[j].Name) })

	sort.SliceStable(m.Devices, func(i, j int) bool {
		a, b := m.Devices[i], m.Devices[j]
		if a.Online != b.Online {
			return a.Online
		}
		if ra, rb := kindRank(a.Kind), kindRank(b.Kind); ra != rb {
			return ra < rb
		}
		return naturalLess(firstText(a.IP, a.MAC), firstText(b.IP, b.MAC))
	})
	return m
}

// resolvePort finds the router port a client is behind and says how it knows.
func resolvePort(mac, arpIface, remembered string, t RouterTopology, ready bool) (string, string) {
	if !ready {
		if arpIface != "" {
			return arpIface, "arp"
		}
		if remembered != "" {
			return remembered, "remembered"
		}
		return "", "none"
	}
	if p, ok := t.HostPort[mac]; ok {
		return p, "bridge"
	}
	if w, ok := t.Wifi[mac]; ok && w.Interface != "" {
		return w.Interface, "wifi"
	}
	if p := t.Ports[arpIface]; p != nil && p.Physical() {
		return arpIface, "arp"
	}
	if p := t.Ports[remembered]; p != nil {
		return remembered, "remembered"
	}
	return "", "none"
}

func statusOf(online bool, registered string) string {
	if online {
		return "online"
	}
	if registered == "degraded" {
		return "degraded"
	}
	return "offline"
}

func equipmentKind(deviceType string) string {
	switch deviceType {
	case "router":
		return KindRouter
	case "switch":
		return KindSwitch
	case "firewall":
		return KindFirewall
	case "access_point":
		return KindAccessPoint
	case "server":
		return KindServer
	case "workstation":
		return KindComputer
	case "printer":
		return KindPrinter
	case "camera":
		return KindCamera
	case "phone":
		return KindPhone
	case "iot":
		return KindIoT
	case "medical_device":
		return KindMedical
	}
	return KindUnknown
}

// kindRank orders infrastructure first, then what people use.
func kindRank(kind string) int {
	switch kind {
	case KindRouter:
		return 0
	case KindFirewall:
		return 1
	case KindSwitch:
		return 2
	case KindAccessPoint:
		return 3
	case KindNetwork:
		return 4
	case KindServer:
		return 5
	case KindMedical:
		return 6
	case KindComputer:
		return 7
	case KindPrinter:
		return 8
	case KindPhone, KindTablet:
		return 9
	case KindCamera:
		return 10
	case KindTV, KindIoT:
		return 11
	}
	return 12
}

func firstText(values ...string) string {
	for _, v := range values {
		if strings.TrimSpace(v) != "" {
			return strings.TrimSpace(v)
		}
	}
	return ""
}

// naturalLess compares "ether2" before "ether10" and "172.16.0.9" before "172.16.0.10".
func naturalLess(a, b string) bool {
	for a != "" && b != "" {
		if unicode.IsDigit(rune(a[0])) && unicode.IsDigit(rune(b[0])) {
			ia, ib := 0, 0
			for ia < len(a) && unicode.IsDigit(rune(a[ia])) {
				ia++
			}
			for ib < len(b) && unicode.IsDigit(rune(b[ib])) {
				ib++
			}
			na, _ := strconv.Atoi(a[:ia])
			nb, _ := strconv.Atoi(b[:ib])
			if na != nb {
				return na < nb
			}
			a, b = a[ia:], b[ib:]
			continue
		}
		if a[0] != b[0] {
			return a[0] < b[0]
		}
		a, b = a[1:], b[1:]
	}
	return len(a) < len(b)
}

// cleanIP drops placeholder addresses.
func cleanIP(ip string) string {
	if ip == "0.0.0.0" || ip == "::" {
		return ""
	}
	return ip
}

const maxBulkPlaces = 200

// SaveDevicePlaces says where several devices are. An empty place clears it.
func (s *NetworkMapService) SaveDevicePlaces(ctx context.Context, orgID uuid.UUID, macs []string, place string) (int, error) {
	place = strings.TrimSpace(place)
	if len([]rune(place)) > maxPlaceLen {
		return 0, &ClientNoteError{"The place can be at most 80 characters"}
	}
	if len(macs) == 0 || len(macs) > maxBulkPlaces {
		return 0, &ClientNoteError{"Choose between 1 and 200 devices"}
	}
	seen := map[string]bool{}
	var clean []string
	for _, m := range macs {
		mac := normalizeMAC(m)
		if mac == "" {
			return 0, &ClientNoteError{"Invalid MAC address"}
		}
		if !seen[mac] {
			seen[mac] = true
			clean = append(clean, mac)
		}
	}
	if err := s.clients.SaveDevicePlaces(ctx, orgID, clean, place); err != nil {
		return 0, err
	}
	return len(clean), nil
}

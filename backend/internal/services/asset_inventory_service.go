package services

import (
	"bytes"
	"context"
	"encoding/csv"
	"fmt"
	"net"
	"sort"
	"strconv"
	"strings"
	"sync"
	"time"

	"github.com/google/uuid"
	"github.com/hospital/nms-backend/internal/repository"
	"github.com/hospital/nms-backend/pkg/logger"
)

// The inventory counts what the hospital owns: every device the router sees and
// every registered one, minus phones and tablets. A person's choice of type always
// wins, then what a scan found, then what the name and the MAC address suggest.

// InventoryItem is one device in the inventory.
type InventoryItem struct {
	ID           string     `json:"id"`
	Name         string     `json:"name"`
	IP           string     `json:"ip"`
	MAC          string     `json:"mac"`
	Hostname     string     `json:"hostname,omitempty"`
	Kind         string     `json:"kind"`
	KindSource   string     `json:"kind_source"` // manual | scan | detected
	Reason       string     `json:"reason,omitempty"`
	Confidence   string     `json:"confidence"`
	Brand        string     `json:"brand,omitempty"`
	Vendor       string     `json:"vendor,omitempty"`
	Model        string     `json:"model,omitempty"`
	Serial       string     `json:"serial,omitempty"`
	PageCount    *int64     `json:"page_count,omitempty"`
	TonerPercent *int       `json:"toner_percent,omitempty"`
	Ports        []int      `json:"ports,omitempty"`
	Place        string     `json:"place,omitempty"`
	Note         string     `json:"note,omitempty"`
	Online       bool       `json:"online"`
	LastSeen     *time.Time `json:"last_seen,omitempty"`
	ScannedAt    *time.Time `json:"scanned_at,omitempty"`
}

// InventoryCount is the count of one type of device.
type InventoryCount struct {
	Kind   string `json:"kind"`
	Total  int    `json:"total"`
	Online int    `json:"online"`
}

// InventoryScan says where the scan is.
type InventoryScan struct {
	Running    bool       `json:"running"`
	Done       int        `json:"done"`
	Total      int        `json:"total"`
	FinishedAt *time.Time `json:"finished_at,omitempty"`
}

// Inventory is the page: Items are counted, Excluded (phones, tablets) are not but
// stay reachable so a wrong guess can be corrected.
type Inventory struct {
	Items       []InventoryItem  `json:"items"`
	Excluded    []InventoryItem  `json:"excluded"`
	Counts      []InventoryCount `json:"counts"`
	Total       int              `json:"total"`
	Online      int              `json:"online"`
	NeedsReview int              `json:"needs_review"`
	Scan        InventoryScan    `json:"scan"`
}

const (
	scanWorkers     = 12
	scanPortWorkers = 6
	scanPortTimeout = 700 * time.Millisecond
	scanSNMPTimeout = 900 * time.Millisecond
)

// Ports that say what a device is. Connecting and closing is all that is done:
// nothing is sent, so a printer does not print.
var scanPorts = []int{9100, 515, 631, 8291, 554, 104, 1433, 3306, 5432, 389, 88, 445, 3389, 135}

const (
	oidSysDescr   = "1.3.6.1.2.1.1.1.0"
	oidSysName    = "1.3.6.1.2.1.1.5.0"
	oidDeviceName = "1.3.6.1.2.1.25.3.2.1.3.1"
	oidSerial     = "1.3.6.1.2.1.43.5.1.1.17.1"
	oidPageCount  = "1.3.6.1.2.1.43.10.2.1.4.1.1"
	oidTonerMax   = "1.3.6.1.2.1.43.11.1.1.8.1.1"
	oidTonerLevel = "1.3.6.1.2.1.43.11.1.1.9.1.1"
)

type AssetInventoryService struct {
	mapService *NetworkMapService
	repo       *repository.AssetInventoryRepository
	probe      func(ctx context.Context, ip string) repository.AssetFingerprint

	mu   sync.Mutex
	scan map[uuid.UUID]*InventoryScan
}

func NewAssetInventoryService(mapService *NetworkMapService, repo *repository.AssetInventoryRepository) *AssetInventoryService {
	return &AssetInventoryService{mapService: mapService, repo: repo, probe: probeDevice, scan: map[uuid.UUID]*InventoryScan{}}
}

func inventoryKey(mac, ip string) string {
	if mac != "" {
		return mac
	}
	return "ip:" + ip
}

// Get returns the inventory.
func (s *AssetInventoryService) Get(ctx context.Context, orgID uuid.UUID) (Inventory, error) {
	m, err := s.mapService.Build(ctx, orgID, false)
	if err != nil {
		return Inventory{}, err
	}
	prints, err := s.repo.Fingerprints(ctx, orgID)
	if err != nil {
		return Inventory{}, err
	}
	inv := composeInventory(withMainRouter(m), prints)
	s.mu.Lock()
	if st := s.scan[orgID]; st != nil {
		inv.Scan = *st
	}
	s.mu.Unlock()
	return inv, nil
}

// withMainRouter adds the router the NMS is connected to, which the map keeps apart
// from the devices behind it.
func withMainRouter(m NetworkMap) []MapDevice {
	for _, d := range m.Devices {
		if d.Source == "router" {
			return m.Devices
		}
	}
	if m.Router.IP == "" {
		return m.Devices
	}
	return append([]MapDevice{{
		ID: "router", Source: "router", Name: firstText(m.Router.Name, "Main router"), IP: m.Router.IP, Brand: "MikroTik",
		Kind: KindRouter, Confidence: ConfidenceHigh, Online: m.Router.Online,
	}}, m.Devices...)
}

func composeInventory(devices []MapDevice, prints map[string]repository.AssetFingerprint) Inventory {
	inv := Inventory{Items: []InventoryItem{}, Excluded: []InventoryItem{}, Counts: []InventoryCount{}}
	counts := map[string]*InventoryCount{}
	for _, d := range devices {
		item := InventoryItem{
			ID: d.ID, Name: d.Name, IP: d.IP, MAC: d.MAC, Hostname: d.Hostname, Kind: d.Kind, KindSource: "detected",
			Reason: d.KindReason, Confidence: d.Confidence, Brand: d.Brand, Vendor: d.Vendor, Model: d.Model,
			Place: d.Place, Note: d.Note, Online: d.Online, LastSeen: d.LastSeen,
		}
		if d.Source == "router" {
			item.Kind, item.Confidence, item.Reason = KindRouter, ConfidenceHigh, "This is the router the NMS is connected to"
		}
		if f, ok := prints[inventoryKey(d.MAC, d.IP)]; ok {
			scanned := f.ScannedAt
			item.ScannedAt, item.Ports, item.Serial, item.PageCount, item.TonerPercent = &scanned, f.Ports, f.Serial, f.PageCount, f.TonerPercent
			if f.Model != "" {
				item.Model = f.Model
			}
			if f.Kind != "" && !d.KindCustom && d.Source != "router" && (d.Confidence != ConfidenceHigh || d.Kind == KindUnknown || f.Confidence == ConfidenceHigh) {
				item.Kind, item.KindSource, item.Reason, item.Confidence = f.Kind, "scan", f.Reason, f.Confidence
			}
		}
		if d.KindCustom {
			item.KindSource, item.Confidence, item.Reason = "manual", ConfidenceHigh, "You chose this type"
		}
		if item.Kind == KindPhone || item.Kind == KindTablet {
			inv.Excluded = append(inv.Excluded, item)
			continue
		}
		inv.Items = append(inv.Items, item)
		c := counts[item.Kind]
		if c == nil {
			c = &InventoryCount{Kind: item.Kind}
			counts[item.Kind] = c
		}
		c.Total++
		inv.Total++
		if item.Online {
			c.Online++
			inv.Online++
		}
		if item.KindSource != "manual" && (item.Kind == KindUnknown || item.Confidence == ConfidenceLow || item.Confidence == ConfidenceNone) {
			inv.NeedsReview++
		}
	}
	sort.SliceStable(inv.Items, func(i, j int) bool {
		a, b := inv.Items[i], inv.Items[j]
		if a.Kind != b.Kind {
			return kindRank(a.Kind) < kindRank(b.Kind)
		}
		return naturalLess(a.IP, b.IP)
	})
	for _, c := range counts {
		inv.Counts = append(inv.Counts, *c)
	}
	sort.Slice(inv.Counts, func(i, j int) bool { return kindRank(inv.Counts[i].Kind) < kindRank(inv.Counts[j].Kind) })
	return inv
}

// StartScan looks at every device that is on now, in the background. Medical devices
// are left alone, and phones have nothing to find.
func (s *AssetInventoryService) StartScan(ctx context.Context, orgID uuid.UUID) (InventoryScan, error) {
	s.mu.Lock()
	if st := s.scan[orgID]; st != nil && st.Running {
		cur := *st
		s.mu.Unlock()
		return cur, nil
	}
	s.mu.Unlock()
	m, err := s.mapService.Build(ctx, orgID, false)
	if err != nil {
		return InventoryScan{}, err
	}
	targets := scanTargets(m.Devices)
	st := &InventoryScan{Running: true, Total: len(targets)}
	s.mu.Lock()
	s.scan[orgID] = st
	cur := *st
	s.mu.Unlock()
	go s.runScan(orgID, targets, st)
	return cur, nil
}

func scanTargets(devices []MapDevice) []MapDevice {
	var out []MapDevice
	for _, d := range devices {
		ip := net.ParseIP(d.IP)
		if !d.Online || ip == nil || ip.To4() == nil || !ip.IsPrivate() {
			continue
		}
		if d.Source == "router" || d.Kind == KindPhone || d.Kind == KindTablet || d.Kind == KindMedical {
			continue
		}
		out = append(out, d)
	}
	return out
}

func (s *AssetInventoryService) runScan(orgID uuid.UUID, targets []MapDevice, st *InventoryScan) {
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Minute)
	defer cancel()
	work := make(chan MapDevice)
	var wg sync.WaitGroup
	for i := 0; i < scanWorkers; i++ {
		wg.Add(1)
		go func() {
			defer wg.Done()
			for d := range work {
				f := s.probe(ctx, d.IP)
				if err := s.repo.SaveFingerprint(ctx, orgID, inventoryKey(d.MAC, d.IP), f); err != nil {
					logger.Warn("Inventory scan: result not stored", "ip", d.IP, "error", err)
				}
				s.mu.Lock()
				st.Done++
				s.mu.Unlock()
			}
		}()
	}
	for _, d := range targets {
		work <- d
	}
	close(work)
	wg.Wait()
	now := time.Now()
	s.mu.Lock()
	st.Running, st.FinishedAt = false, &now
	s.mu.Unlock()
}

func probeDevice(ctx context.Context, ip string) repository.AssetFingerprint {
	f := repository.AssetFingerprint{IP: ip, ScannedAt: time.Now()}
	var mu sync.Mutex
	var wg sync.WaitGroup
	slots := make(chan struct{}, scanPortWorkers)
	for _, port := range scanPorts {
		wg.Add(1)
		slots <- struct{}{}
		go func(port int) {
			defer wg.Done()
			defer func() { <-slots }()
			d := net.Dialer{Timeout: scanPortTimeout}
			conn, err := d.DialContext(ctx, "tcp", net.JoinHostPort(ip, strconv.Itoa(port)))
			if err != nil {
				return
			}
			conn.Close()
			mu.Lock()
			f.Ports = append(f.Ports, port)
			mu.Unlock()
		}(port)
	}
	wg.Wait()
	sort.Ints(f.Ports)
	values, err := snmpGet(ctx, ip, []string{oidSysDescr, oidSysName, oidDeviceName, oidSerial, oidPageCount, oidTonerMax, oidTonerLevel}, scanSNMPTimeout)
	if err != nil {
		values = nil
	}
	applyScan(&f, values)
	return f
}

// applyScan turns open ports and SNMP answers into a type and details.
func applyScan(f *repository.AssetFingerprint, values map[string]string) {
	f.SysDescr, f.SysName = values[oidSysDescr], values[oidSysName]
	f.Kind, f.Confidence, f.Reason = kindFromScan(f.Ports, f.SysDescr)
	f.Serial = values[oidSerial]
	if v, err := strconv.ParseInt(values[oidPageCount], 10, 64); err == nil && v >= 0 {
		f.PageCount = &v
	}
	level, errL := strconv.Atoi(values[oidTonerLevel])
	limit, errM := strconv.Atoi(values[oidTonerMax])
	if errL == nil && errM == nil && level >= 0 && limit > 0 {
		pct := level * 100 / limit
		f.TonerPercent = &pct
	}
	if f.Kind == KindPrinter {
		f.Model = firstText(values[oidDeviceName], firstLine(f.SysDescr))
	} else if f.SysDescr != "" {
		f.Model = firstLine(f.SysDescr)
	}
	if len(f.Model) > 120 {
		f.Model = f.Model[:120]
	}
}

func firstLine(s string) string {
	if i := strings.IndexAny(s, "\r\n;"); i >= 0 {
		s = s[:i]
	}
	return strings.TrimSpace(s)
}

func hasPort(ports []int, want int) bool {
	for _, p := range ports {
		if p == want {
			return true
		}
	}
	return false
}

func kindFromScan(ports []int, descr string) (kind, confidence, reason string) {
	d := strings.ToLower(descr)
	contains := func(words ...string) bool {
		for _, w := range words {
			if strings.Contains(d, w) {
				return true
			}
		}
		return false
	}
	switch {
	case contains("jetdirect", "laserjet", "printer", "officejet", "kyocera", "ricoh", "xerox", "brother nc", "canon ", "epson", "lexmark", "ecosys", "bizhub", "sharp mx"):
		return KindPrinter, ConfidenceHigh, "The device says it is a printer: " + firstLine(descr)
	case contains("routeros", "mikrotik"):
		return KindRouter, ConfidenceHigh, "The device says it is MikroTik: " + firstLine(descr)
	case contains("access point", "unifi", "eap1", "eap2"):
		return KindAccessPoint, ConfidenceHigh, "The device says it is an access point: " + firstLine(descr)
	case contains("switch", "catalyst", "procurve", "aruba", "jetstream"):
		return KindSwitch, ConfidenceHigh, "The device says it is a switch: " + firstLine(descr)
	case contains("windows server", "esxi", "synology", "qnap"):
		return KindServer, ConfidenceHigh, "The device says it is a server: " + firstLine(descr)
	case hasPort(ports, 9100):
		return KindPrinter, ConfidenceHigh, "It accepts print jobs (port 9100 is open)"
	case hasPort(ports, 515) && hasPort(ports, 631):
		return KindPrinter, ConfidenceMedium, "It accepts print jobs (ports 515 and 631 are open)"
	case hasPort(ports, 8291):
		return KindRouter, ConfidenceMedium, "MikroTik management is open (port 8291)"
	case hasPort(ports, 104):
		return KindMedical, ConfidenceMedium, "It speaks DICOM, used for medical images (port 104 is open)"
	case hasPort(ports, 1433), hasPort(ports, 3306), hasPort(ports, 5432):
		return KindServer, ConfidenceMedium, "A database is running on it"
	case hasPort(ports, 389), hasPort(ports, 88):
		return KindServer, ConfidenceMedium, "It looks like a domain controller (ports 389 or 88 are open)"
	case hasPort(ports, 3389), hasPort(ports, 445), hasPort(ports, 135):
		return KindComputer, ConfidenceMedium, "It has Windows file sharing or remote desktop open"
	case hasPort(ports, 554):
		return KindCamera, ConfidenceMedium, "It streams video (port 554 is open)"
	}
	return "", "", ""
}

// ExportInventoryCSV writes the inventory report for Excel.
func ExportInventoryCSV(inv Inventory, now time.Time) []byte {
	var buf bytes.Buffer
	buf.WriteString("\xEF\xBB\xBF")
	w := csv.NewWriter(&buf)
	row := func(cells ...string) {
		for i := range cells {
			cells[i] = safeCell(cells[i])
		}
		_ = w.Write(cells)
	}
	row("Inventory report", now.Format("2006-01-02 15:04"))
	row("Total devices", strconv.Itoa(inv.Total), "Online now", strconv.Itoa(inv.Online))
	row("Phones and tablets, not counted", strconv.Itoa(len(inv.Excluded)))
	row("Devices to review", strconv.Itoa(inv.NeedsReview))
	row("")
	row("Type", "Total", "Online")
	for _, c := range inv.Counts {
		row(inventoryKindLabel(c.Kind), strconv.Itoa(c.Total), strconv.Itoa(c.Online))
	}
	row("")
	row("Type", "Name", "IP", "MAC", "Brand", "Model", "Serial", "Place", "Status", "Last seen", "Identified by", "Pages printed", "Toner %", "Note")
	for _, it := range inv.Items {
		status, seen, pages, toner := "Offline", "", "", ""
		if it.Online {
			status = "Online"
		}
		if it.LastSeen != nil {
			seen = it.LastSeen.Format("2006-01-02 15:04")
		}
		if it.PageCount != nil {
			pages = strconv.FormatInt(*it.PageCount, 10)
		}
		if it.TonerPercent != nil {
			toner = strconv.Itoa(*it.TonerPercent)
		}
		row(inventoryKindLabel(it.Kind), it.Name, it.IP, it.MAC, firstText(it.Brand, it.Vendor), it.Model, it.Serial, it.Place, status, seen, it.Reason, pages, toner, it.Note)
	}
	w.Flush()
	return buf.Bytes()
}

func inventoryKindLabel(kind string) string {
	switch kind {
	case KindRouter:
		return "Router"
	case KindFirewall:
		return "Firewall"
	case KindSwitch:
		return "Switch"
	case KindAccessPoint:
		return "Access point"
	case KindNetwork:
		return "Network equipment"
	case KindServer:
		return "Server"
	case KindMedical:
		return "Medical device"
	case KindComputer:
		return "Computer"
	case KindPrinter:
		return "Printer"
	case KindCamera:
		return "Camera"
	case KindTV:
		return "TV"
	case KindIoT:
		return "Smart device"
	}
	return "Unknown"
}

// InventoryFileName names the report.
func InventoryFileName(now time.Time) string {
	return fmt.Sprintf("inventory-%s.csv", now.Format("2006-01-02"))
}

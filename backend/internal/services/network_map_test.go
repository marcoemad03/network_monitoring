package services

import (
	"testing"
	"time"

	"github.com/google/uuid"
	"github.com/hospital/nms-backend/internal/repository"
)

func sampleTopology() RouterTopology {
	return buildTopology(
		[]map[string]string{
			{"name": "ether1", "type": "ether", "running": "true"},
			{"name": "ether2", "type": "ether", "running": "true", "comment": "Emergency ward"},
			{"name": "ether10", "type": "ether", "running": "false"},
			{"name": "bridge1", "type": "bridge", "running": "true"},
		},
		[]map[string]string{{"interface": "ether2", "bridge": "bridge1"}},
		[]map[string]string{
			{"mac-address": "AA:AA:AA:00:00:01", "on-interface": "ether2", "bridge": "bridge1"},
			{"mac-address": "AA:AA:AA:00:00:99", "on-interface": "bridge1", "local": "true"},
		},
		[]map[string]string{{"mac-address": "AA:AA:AA:00:00:03", "interface": "wlan1", "signal-strength": "-60dBm"}},
		nil,
		[]map[string]string{{"mac-address": "AA:AA:AA:00:00:05", "address": "172.16.0.20", "identity": "SW-ER", "board": "CRS109", "interface": "ether2,bridge1"}},
	)
}

func TestBuildTopologySkipsLocalHostsAndKeepsPorts(t *testing.T) {
	topo := sampleTopology()
	if got := topo.HostPort["AA:AA:AA:00:00:01"]; got != "ether2" {
		t.Errorf("host port = %q", got)
	}
	if _, ok := topo.HostPort["AA:AA:AA:00:00:99"]; ok {
		t.Error("the router's own MAC must not be a device")
	}
	if topo.Ports["ether2"].Bridge != "bridge1" || topo.Ports["ether2"].Comment != "Emergency ward" {
		t.Errorf("ether2 = %+v", topo.Ports["ether2"])
	}
	if topo.Wifi["AA:AA:AA:00:00:03"].Interface != "wlan1" {
		t.Errorf("wifi = %+v", topo.Wifi)
	}
	if len(topo.Neighbors) != 1 || topo.Neighbors[0].Interface != "ether2" || topo.Neighbors[0].Identity != "SW-ER" {
		t.Errorf("neighbors = %+v", topo.Neighbors)
	}
}

func client(mac, ip, name, kind string, online bool, arp string) ClientView {
	return ClientView{MAC: mac, IP: ip, DisplayName: name, NameSource: "hostname", Kind: kind, KindSource: "detected", Confidence: "high", Online: online, ArpInterface: arp}
}

func TestComposeMapPlacesDevicesByPort(t *testing.T) {
	topo := sampleTopology()
	topo.Address = "172.16.0.1"
	topo.ReadAt = time.Now()
	list := ClientList{Available: true, Clients: []ClientView{
		client("AA:AA:AA:00:00:01", "172.16.0.10", "Nurse PC", KindComputer, true, "bridge1"),
		client("AA:AA:AA:00:00:03", "172.16.0.11", "iPhone", KindPhone, true, "bridge1"),
		client("AA:AA:AA:00:00:04", "172.16.0.12", "Old printer", KindPrinter, false, ""),
		client("AA:AA:AA:00:00:07", "172.16.0.1", "router", KindNetwork, true, ""),
	}}
	list.Clients[2].LastPort = "ether1"
	m := composeMap(list, map[string]repository.ClientNote{}, map[string]string{}, nil, TopologyResult{Topology: topo, Ready: true})

	byMAC := map[string]MapDevice{}
	for _, d := range m.Devices {
		byMAC[d.MAC] = d
	}
	if _, ok := byMAC["AA:AA:AA:00:00:07"]; ok {
		t.Error("the router must not appear as a client")
	}
	pc := byMAC["AA:AA:AA:00:00:01"]
	if pc.Port != "ether2" || pc.PortSource != "bridge" || pc.Place != "Emergency ward" || pc.PlaceSource != "port_comment" {
		t.Errorf("pc = %+v", pc)
	}
	phone := byMAC["AA:AA:AA:00:00:03"]
	if phone.Port != "wlan1" || phone.PortSource != "wifi" || phone.Wifi == nil || phone.Wifi.Signal != "-60dBm" {
		t.Errorf("phone = %+v", phone)
	}
	printer := byMAC["AA:AA:AA:00:00:04"]
	if printer.Port != "ether1" || printer.PortSource != "remembered" || printer.Online {
		t.Errorf("printer = %+v", printer)
	}
	if sw := byMAC["AA:AA:AA:00:00:05"]; sw.Source != "neighbor" || sw.Name != "SW-ER" || sw.Kind != KindNetwork || sw.Port != "ether2" || sw.IP != "172.16.0.20" {
		t.Errorf("neighbor = %+v", sw)
	}
	var ether2 *MapPort
	for i := range m.Ports {
		if m.Ports[i].Name == "ether2" {
			ether2 = &m.Ports[i]
		}
	}
	if ether2 == nil || ether2.Devices != 2 || ether2.Online != 2 || ether2.Label != "Emergency ward" {
		t.Errorf("ether2 = %+v", ether2)
	}
	if m.Ports[0].Name != "ether1" || m.Ports[1].Name != "ether2" || m.Ports[2].Name != "ether10" {
		t.Errorf("ports not in natural order: %v", m.Ports)
	}
	if m.Summary.Total != 4 || m.Summary.Online != 3 || m.Summary.Offline != 1 {
		t.Errorf("summary = %+v", m.Summary)
	}
}

func TestComposeMapNamesAndMerging(t *testing.T) {
	topo := sampleTopology()
	topo.Address = "172.16.0.1"
	list := ClientList{Available: true, Clients: []ClientView{
		client("AA:AA:AA:00:00:01", "172.16.0.10", "Nurse PC", KindComputer, true, ""),
	}}
	notes := map[string]repository.ClientNote{"AA:AA:AA:00:00:01": {Place: "Reception desk 2"}}
	places := map[string]string{"ether1": "Server room"}
	eqID := uuid.New()
	srvID := uuid.New()
	equipment := []repository.MapDeviceRow{
		{ID: eqID, Name: "Triage workstation", IPAddress: "172.16.0.10", DeviceType: "workstation", Status: "online", Place: "Main, Floor 1", IsCritical: true},
		{ID: srvID, Name: "PACS", IPAddress: "172.16.0.50", DeviceType: "server", Status: "offline", Port: "ether1"},
		{ID: uuid.New(), Name: "MikroTik", IPAddress: "172.16.0.1", DeviceType: "router", Status: "online"},
	}
	m := composeMap(list, notes, places, equipment, TopologyResult{Topology: topo, Ready: true})
	if len(m.Devices) != 3 { // pc (merged), PACS, SW-ER neighbor; router skipped
		t.Fatalf("devices = %d: %+v", len(m.Devices), m.Devices)
	}
	by := map[string]MapDevice{}
	for _, d := range m.Devices {
		by[d.IP] = d
	}
	pc := by["172.16.0.10"]
	if pc.Name != "Triage workstation" || pc.Registered != eqID.String() || !pc.Critical || pc.Place != "Reception desk 2" || pc.PlaceSource != "custom" {
		t.Errorf("merged pc = %+v", pc)
	}
	srv := by["172.16.0.50"]
	if srv.Source != "equipment" || srv.Kind != KindServer || srv.Online || srv.Status != "offline" || srv.Port != "ether1" || srv.Place != "Server room" || srv.PlaceSource != "port_label" {
		t.Errorf("server = %+v", srv)
	}
}

func TestComposeMapWithoutTopologyFallsBackToARP(t *testing.T) {
	list := ClientList{Available: true, Clients: []ClientView{client("AA:AA:AA:00:00:01", "172.16.0.10", "PC", KindComputer, true, "ether3")}}
	m := composeMap(list, nil, nil, nil, TopologyResult{Error: "router unreachable"})
	d := m.Devices[0]
	if d.Port != "ether3" || d.PortSource != "arp" || d.Place != "ether3" || d.PlaceSource != "port" {
		t.Errorf("device = %+v", d)
	}
	if m.TopologyError == "" || m.Router.Online {
		t.Errorf("topology error not reported: %+v", m)
	}
}

func TestNaturalLess(t *testing.T) {
	cases := []struct {
		a, b string
		want bool
	}{{"ether2", "ether10", true}, {"ether10", "ether2", false}, {"172.16.0.9", "172.16.0.10", true}, {"a", "a", false}, {"sfp1", "ether1", false}}
	for _, c := range cases {
		if got := naturalLess(c.a, c.b); got != c.want {
			t.Errorf("naturalLess(%q,%q)=%v", c.a, c.b, got)
		}
	}
}

func TestComposeMapTreatsBusyPortAsUplink(t *testing.T) {
	topo := sampleTopology()
	var clients []ClientView
	for i := 0; i < 12; i++ {
		clients = append(clients, client("AA:AA:AA:01:00:"+string(rune('A'+i))+"0", "172.16.1."+string(rune('1'+i%9)), "PC", KindComputer, true, "ether1"))
		clients[i].MAC = "AA:AA:AA:01:00:" + map[bool]string{true: "0", false: "1"}[i < 10] + string(rune('0'+i%10))
		clients[i].IP = "172.16.1." + string(rune('0'+i%10)) + string(rune('0'+i/10))
	}
	list := ClientList{Available: true, Clients: clients}
	m := composeMap(list, nil, nil, nil, TopologyResult{Topology: topo, Ready: true})
	var port *MapPort
	for i := range m.Ports {
		if m.Ports[i].Name == "ether1" {
			port = &m.Ports[i]
		}
	}
	if port == nil || !port.Trunk || port.Devices != 12 {
		t.Fatalf("ether1 = %+v", port)
	}
	for _, d := range m.Devices {
		if d.Source == "client" && (d.Place != "" || d.PlaceSource != "none" || d.Port != "ether1") {
			t.Fatalf("a device behind an uplink must keep its port but get no place: %+v", d)
		}
	}
	if m.Summary.Located != 1 { // only the neighbour on ether2 has a place
		t.Errorf("located = %d", m.Summary.Located)
	}
}

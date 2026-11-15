package services

import (
	"encoding/binary"
	"strings"
	"testing"
)

// tzspQuery builds what the router's sniffer sends for one DNS query from src.
func tzspQuery(src [4]byte, name string, qtype uint16, response bool, vlan bool) []byte {
	dns := []byte{0x12, 0x34, 0x01, 0x00, 0, 1, 0, 0, 0, 0, 0, 0}
	if response {
		dns[2] |= 0x80
	}
	for _, l := range strings.Split(name, ".") {
		dns = append(dns, byte(len(l)))
		dns = append(dns, l...)
	}
	dns = append(dns, 0, byte(qtype>>8), byte(qtype), 0, 1)
	udp := make([]byte, 8)
	binary.BigEndian.PutUint16(udp[0:2], 53000)
	binary.BigEndian.PutUint16(udp[2:4], 53)
	binary.BigEndian.PutUint16(udp[4:6], uint16(8+len(dns)))
	udp = append(udp, dns...)
	ip := make([]byte, 20)
	ip[0], ip[9] = 0x45, 17
	copy(ip[12:16], src[:])
	copy(ip[16:20], []byte{8, 8, 8, 8})
	ip = append(ip, udp...)
	eth := make([]byte, 12)
	if vlan {
		eth = append(eth, 0x81, 0x00, 0, 10)
	}
	eth = append(eth, 0x08, 0x00)
	eth = append(eth, ip...)
	// TZSP v1, received, Ethernet, a padding tag, then the end tag.
	return append([]byte{1, 0, 0, 1, 0, 1}, eth...)
}

func TestSnifferReadsTheDeviceAndTheNameOfADNSQuery(t *testing.T) {
	ev, ok := parseTZSPDNS(tzspQuery([4]byte{172, 16, 0, 96}, "cima.my-cima.net", 1, false, false))
	if !ok || ev.ClientIP != "172.16.0.96" || ev.Name != "cima.my-cima.net" || ev.QType != "A" {
		t.Fatalf("got %+v ok=%v", ev, ok)
	}
	if ev, ok := parseTZSPDNS(tzspQuery([4]byte{172, 16, 0, 5}, "WWW.Example.COM", 28, false, true)); !ok || ev.Name != "www.example.com" || ev.QType != "AAAA" {
		t.Fatalf("vlan frame: %+v ok=%v", ev, ok)
	}
	if _, ok := parseTZSPDNS(tzspQuery([4]byte{172, 16, 0, 5}, "example.com", 1, true, false)); ok {
		t.Error("an answer is not a lookup")
	}
	for _, bad := range [][]byte{nil, {2, 0, 0, 1, 1}, {1, 0, 0, 1, 5, 200}, tzspQuery([4]byte{1, 2, 3, 4}, "a.b", 1, false, false)[:30]} {
		if _, ok := parseTZSPDNS(bad); ok {
			t.Errorf("broken packet %v accepted", bad)
		}
	}
}

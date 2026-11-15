package services

import (
	"context"
	"encoding/binary"
	"net"
	"strings"
	"time"

	"github.com/hospital/nms-backend/pkg/logger"
)

// SourceSniffer is the router's packet sniffer in the source status.
const SourceSniffer = "sniffer"

// The router's packet sniffer can stream a copy of the DNS questions devices send
// (port 53 on the LAN interface) to the NMS in TZSP. That gives each device's
// lookups without changing the DNS devices use: the questions still go to 8.8.8.8,
// and the name blocks still drop them. Questions sent encrypted (DNS over TLS or
// HTTPS) are not seen.

// parseTZSPDNS reads one TZSP packet and returns the DNS question in it. ok is false
// for anything that is not a DNS query sent over UDP in an Ethernet frame.
func parseTZSPDNS(b []byte) (DNSEvent, bool) {
	// TZSP: version 1, type, encapsulation (1 = Ethernet), then tagged fields up to
	// the end tag (1); tag 0 is one byte of padding.
	if len(b) < 5 || b[0] != 1 || binary.BigEndian.Uint16(b[2:4]) != 1 {
		return DNSEvent{}, false
	}
	i := 4
	for {
		if i >= len(b) {
			return DNSEvent{}, false
		}
		tag := b[i]
		i++
		if tag == 1 {
			break
		}
		if tag == 0 {
			continue
		}
		if i >= len(b) {
			return DNSEvent{}, false
		}
		i += 1 + int(b[i])
	}
	frame := b[i:]

	// Ethernet, with up to two VLAN tags.
	if len(frame) < 14 {
		return DNSEvent{}, false
	}
	etherType := binary.BigEndian.Uint16(frame[12:14])
	p := frame[14:]
	for etherType == 0x8100 || etherType == 0x88a8 {
		if len(p) < 4 {
			return DNSEvent{}, false
		}
		etherType = binary.BigEndian.Uint16(p[2:4])
		p = p[4:]
	}
	if etherType != 0x0800 || len(p) < 20 || p[0]>>4 != 4 {
		return DNSEvent{}, false
	}
	ihl := int(p[0]&0x0f) * 4
	if ihl < 20 || len(p) < ihl+8 || p[9] != 17 {
		return DNSEvent{}, false
	}
	src := net.IP(p[12:16]).String()
	udp := p[ihl:]
	if binary.BigEndian.Uint16(udp[2:4]) != 53 {
		return DNSEvent{}, false
	}
	name, qtype, ok := parseDNSQuestion(udp[8:])
	if !ok {
		return DNSEvent{}, false
	}
	return DNSEvent{ClientIP: src, Name: name, QType: qtype}, true
}

// parseDNSQuestion reads the first question of a DNS query (not an answer).
func parseDNSQuestion(m []byte) (name, qtype string, ok bool) {
	if len(m) < 12 || m[2]&0x80 != 0 || binary.BigEndian.Uint16(m[4:6]) == 0 {
		return "", "", false
	}
	var labels []string
	i := 12
	for {
		if i >= len(m) {
			return "", "", false
		}
		l := int(m[i])
		i++
		if l == 0 {
			break
		}
		if l > 63 || i+l > len(m) || len(labels) > 127 {
			return "", "", false
		}
		labels = append(labels, string(m[i:i+l]))
		i += l
	}
	if len(labels) == 0 || i+2 > len(m) {
		return "", "", false
	}
	switch binary.BigEndian.Uint16(m[i : i+2]) {
	case 1:
		qtype = "A"
	case 28:
		qtype = "AAAA"
	case 65:
		qtype = "HTTPS"
	default:
		qtype = "OTHER"
	}
	return strings.ToLower(strings.Join(labels, ".")), qtype, true
}

// StartSniffer listens for the router's sniffer stream on UDP. Only the router (or
// another private address in the allow list) can feed it.
func (c *DNSCollector) StartSniffer(ctx context.Context, listen string, allow []string) error {
	c.RegisterSource(SourceSniffer, true)
	addr, err := net.ResolveUDPAddr("udp", listen)
	if err != nil {
		c.SourceError(SourceSniffer, "invalid listen address: "+err.Error())
		return err
	}
	conn, err := net.ListenUDP("udp", addr)
	if err != nil {
		c.SourceError(SourceSniffer, "cannot listen on "+listen+": "+err.Error())
		return err
	}
	allowed := parseAllowList(allow)
	logger.Info("DNS sniffer listener started", "listen", conn.LocalAddr().String())

	go func() {
		<-ctx.Done()
		conn.Close()
	}()
	go func() {
		buf := make([]byte, 65536)
		for {
			n, from, err := conn.ReadFromUDP(buf)
			if err != nil {
				if ctx.Err() != nil {
					return
				}
				time.Sleep(200 * time.Millisecond)
				continue
			}
			if !allowedSyslogSource(from.IP, allowed) {
				continue
			}
			if ev, ok := parseTZSPDNS(buf[:n]); ok {
				ev.Time = time.Now()
				c.Add(SourceSniffer, ev)
			}
		}
	}()
	return nil
}

package services

import (
	"context"
	"net"
	"regexp"
	"strings"
	"time"

	"github.com/hospital/nms-backend/pkg/logger"
)

// SourceSyslog is the name of the syslog listener in the source status.
const SourceSyslog = "syslog"

var (
	// dnsmasq and Pi-hole: "dnsmasq[812]: query[A] www.example.com from 172.16.0.5"
	reDnsmasq = regexp.MustCompile(`query\[([A-Za-z0-9]+)\]\s+(\S+)\s+from\s+(\S+)`)
	// RouterOS (dns topic): "query from 172.16.0.5: #1234 www.example.com. A"
	reRouterOS = regexp.MustCompile(`query from\s+(\S+?):\s+#\d+\s+(\S+)\s+([A-Za-z0-9]+)`)
)

// parseDNSLogLine reads one line of a resolver's query log. ok is false for lines
// that are not a client query (replies, cache notes, blocklist loading...).
func parseDNSLogLine(line string) (DNSEvent, bool) {
	if m := reDnsmasq.FindStringSubmatch(line); m != nil {
		return DNSEvent{ClientIP: m[3], Name: m[2], QType: m[1]}, true
	}
	if m := reRouterOS.FindStringSubmatch(line); m != nil {
		return DNSEvent{ClientIP: m[1], Name: m[2], QType: m[3]}, true
	}
	return DNSEvent{}, false
}

// allowedSyslogSource accepts private and loopback senders, plus any address or
// network in the allow list. A resolver on the internet cannot feed the recording.
func allowedSyslogSource(ip net.IP, allow []net.IPNet) bool {
	for i := range allow {
		if allow[i].Contains(ip) {
			return true
		}
	}
	return ip.IsLoopback() || ip.IsPrivate()
}

func parseAllowList(entries []string) []net.IPNet {
	var out []net.IPNet
	for _, e := range entries {
		if !strings.Contains(e, "/") {
			if ip := net.ParseIP(e); ip != nil {
				bits := 32
				if ip.To4() == nil {
					bits = 128
				}
				out = append(out, net.IPNet{IP: ip, Mask: net.CIDRMask(bits, bits)})
			}
			continue
		}
		if _, n, err := net.ParseCIDR(e); err == nil {
			out = append(out, *n)
		}
	}
	return out
}

// StartSyslog listens for the resolver's query log on UDP. The router or Pi-hole
// has to be told to send it (see docs/OPERATIONS.md); until then nothing arrives
// and the page says so.
func (c *DNSCollector) StartSyslog(ctx context.Context, listen string, allow []string) error {
	c.RegisterSource(SourceSyslog, true)
	addr, err := net.ResolveUDPAddr("udp", listen)
	if err != nil {
		c.SourceError(SourceSyslog, "invalid listen address: "+err.Error())
		return err
	}
	conn, err := net.ListenUDP("udp", addr)
	if err != nil {
		c.SourceError(SourceSyslog, "cannot listen on "+listen+": "+err.Error())
		return err
	}
	allowed := parseAllowList(allow)
	logger.Info("DNS syslog listener started", "listen", conn.LocalAddr().String())

	go func() {
		<-ctx.Done()
		conn.Close()
	}()
	go func() {
		buf := make([]byte, 8192)
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
			// One packet is normally one line; some senders put several in one.
			for _, line := range strings.Split(string(buf[:n]), "\n") {
				if ev, ok := parseDNSLogLine(line); ok {
					ev.Time = time.Now()
					c.Add(SourceSyslog, ev)
				}
			}
		}
	}()
	return nil
}

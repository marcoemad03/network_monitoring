package services

import (
	"context"
	"net"
	"strings"
	"sync"
	"time"

	"github.com/google/uuid"
	"github.com/hospital/nms-backend/internal/repository"
	"github.com/hospital/nms-backend/pkg/logger"
)

const (
	dnsFlushEvery  = 30 * time.Second
	dnsMaxPending  = 50000 // distinct (hour, device, site) counters held before a flush
	dnsPruneEvery  = 6 * time.Hour
	dnsStaleSource = 10 * time.Minute
)

// DNSEvent is one lookup a device made at the hospital's resolver.
type DNSEvent struct {
	Time     time.Time
	ClientIP string
	Name     string
	QType    string // "A", "AAAA"... empty when the source does not say
	Blocked  bool
}

type dnsKey struct {
	bucket time.Time
	ip     string
	site   string
}

type dnsCount struct{ queries, blocked int }

// DNSSourceStatus says whether a source is delivering lookups.
type DNSSourceStatus struct {
	Name     string     `json:"name"`
	Enabled  bool       `json:"enabled"`
	LastSeen *time.Time `json:"last_event_at,omitempty"`
	Events   int64      `json:"events"`
	Error    string     `json:"error,omitempty"`
}

// DNSCollector counts lookups per device, site and hour and stores them. Only the
// registrable domain is kept, never the full name asked for and never the answer.
type DNSCollector struct {
	repo          *repository.DNSRepository
	clients       *ClientInventoryService
	retentionDays int

	mu      sync.Mutex
	pending map[dnsKey]*dnsCount
	dropped int64
	sources map[string]*DNSSourceStatus
	orgFn   func(context.Context) ([]uuid.UUID, error)
}

func NewDNSCollector(repo *repository.DNSRepository, clients *ClientInventoryService, retentionDays int) *DNSCollector {
	if retentionDays <= 0 {
		retentionDays = 30
	}
	return &DNSCollector{
		repo: repo, clients: clients, retentionDays: retentionDays,
		pending: map[dnsKey]*dnsCount{}, sources: map[string]*DNSSourceStatus{},
	}
}

// RegisterSource makes a source show up in the status even before it delivers anything.
func (c *DNSCollector) RegisterSource(name string, enabled bool) {
	c.mu.Lock()
	defer c.mu.Unlock()
	if _, ok := c.sources[name]; !ok {
		c.sources[name] = &DNSSourceStatus{Name: name, Enabled: enabled}
	}
}

// SourceError records why a source cannot deliver ("" clears it).
func (c *DNSCollector) SourceError(name, msg string) {
	c.mu.Lock()
	defer c.mu.Unlock()
	if s, ok := c.sources[name]; ok {
		s.Error = msg
	}
}

// Sources returns the state of every source.
func (c *DNSCollector) Sources() []DNSSourceStatus {
	c.mu.Lock()
	defer c.mu.Unlock()
	out := make([]DNSSourceStatus, 0, len(c.sources))
	for _, s := range c.sources {
		cp := *s
		if cp.LastSeen != nil && time.Since(*cp.LastSeen) > dnsStaleSource && cp.Error == "" {
			cp.Error = "no lookups received for a while"
		}
		out = append(out, cp)
	}
	return out
}

// Add counts one lookup. It is cheap and never blocks on the database.
func (c *DNSCollector) Add(source string, ev DNSEvent) {
	if !countsAsVisit(ev.QType) {
		return
	}
	ip := net.ParseIP(strings.TrimSpace(ev.ClientIP))
	if ip == nil || ip.IsLoopback() || ip.IsUnspecified() {
		return
	}
	site, ok := registrableDomain(ev.Name)
	if !ok {
		return
	}
	t := ev.Time
	if t.IsZero() {
		t = time.Now()
	}
	key := dnsKey{bucket: t.UTC().Truncate(time.Hour), ip: ip.String(), site: site}

	c.mu.Lock()
	defer c.mu.Unlock()
	if s, ok := c.sources[source]; ok {
		now := time.Now()
		s.LastSeen, s.Events = &now, s.Events+1
		s.Error = ""
	}
	n := c.pending[key]
	if n == nil {
		if len(c.pending) >= dnsMaxPending {
			c.dropped++
			return
		}
		n = &dnsCount{}
		c.pending[key] = n
	}
	n.queries++
	if ev.Blocked {
		n.blocked++
	}
}

// countsAsVisit: a page view makes an A and an AAAA lookup (and often HTTPS), so
// counting only A keeps the numbers close to "times a site was looked up".
func countsAsVisit(qtype string) bool {
	switch strings.ToUpper(strings.TrimSpace(qtype)) {
	case "", "A":
		return true
	}
	return false
}

// Start flushes the counters regularly and prunes old rows. org picks the
// organization the lookups belong to (the hospital has one).
func (c *DNSCollector) Start(ctx context.Context, orgs func(context.Context) ([]uuid.UUID, error)) {
	c.orgFn = orgs
	go func() {
		flush := time.NewTicker(dnsFlushEvery)
		prune := time.NewTicker(dnsPruneEvery)
		defer flush.Stop()
		defer prune.Stop()
		for {
			select {
			case <-ctx.Done():
				c.Flush(context.Background())
				return
			case <-flush.C:
				c.Flush(ctx)
			case <-prune.C:
				if err := c.repo.PruneDNS(ctx, time.Now().AddDate(0, 0, -c.retentionDays)); err != nil {
					logger.Warn("DNS activity prune failed", "error", err)
				}
			}
		}
	}()
}

// Flush stores what was counted. If the database or the organization is not
// available the counters are kept for the next try.
func (c *DNSCollector) Flush(ctx context.Context) {
	c.mu.Lock()
	if len(c.pending) == 0 {
		c.mu.Unlock()
		return
	}
	batch := c.pending
	c.pending = map[dnsKey]*dnsCount{}
	dropped := c.dropped
	c.dropped = 0
	c.mu.Unlock()

	if dropped > 0 {
		logger.Warn("DNS lookups were not counted because too many were waiting", "dropped", dropped)
	}
	orgID, ok := c.organization(ctx)
	if !ok {
		c.restore(batch)
		return
	}
	macs := c.macsByIP(ctx, orgID)
	rows := make([]repository.DNSRow, 0, len(batch))
	for k, n := range batch {
		rows = append(rows, repository.DNSRow{Bucket: k.bucket, IP: k.ip, MAC: macs[k.ip], Site: k.site, Queries: n.queries, Blocked: n.blocked})
	}
	if err := c.repo.UpsertActivity(ctx, orgID, rows); err != nil {
		logger.Warn("DNS activity not stored, will retry", "error", err)
		c.restore(batch)
	}
}

func (c *DNSCollector) restore(batch map[dnsKey]*dnsCount) {
	c.mu.Lock()
	defer c.mu.Unlock()
	for k, n := range batch {
		if cur := c.pending[k]; cur != nil {
			cur.queries += n.queries
			cur.blocked += n.blocked
		} else if len(c.pending) < dnsMaxPending {
			c.pending[k] = n
		}
	}
}

func (c *DNSCollector) organization(ctx context.Context) (uuid.UUID, bool) {
	if c.orgFn == nil {
		return uuid.Nil, false
	}
	orgs, err := c.orgFn(ctx)
	if err != nil || len(orgs) == 0 {
		return uuid.Nil, false
	}
	return orgs[0], true
}

// macsByIP maps the addresses devices have now to their MAC, so a device keeps its
// history when DHCP gives it another address.
func (c *DNSCollector) macsByIP(ctx context.Context, orgID uuid.UUID) map[string]string {
	out := map[string]string{}
	if c.clients == nil {
		return out
	}
	list, err := c.clients.List(ctx, orgID)
	if err != nil {
		return out
	}
	for _, cl := range list.Clients {
		if cl.Online && cl.IP != "" && cl.MAC != "" {
			out[cl.IP] = cl.MAC
		}
	}
	return out
}

package services

import (
	"context"
	"net"
	"sort"
	"strings"
	"sync"
	"time"
)

const (
	resolverTTL        = 20 * time.Minute
	resolverLookupTime = 4 * time.Second
	resolverWorkers    = 8
	resolverManyIPs    = 24
)

// ResolvedSite is what blocking one typed site by address would do.
type ResolvedSite struct {
	Target         string    `json:"target"`
	Kind           SiteKind  `json:"kind"`
	IPs            []string  `json:"ips"`
	Shared         []string  `json:"shared,omitempty"`
	SharedProvider string    `json:"shared_provider,omitempty"`
	Many           bool      `json:"many_addresses,omitempty"`
	Error          string    `json:"error,omitempty"`
	ResolvedAt     time.Time `json:"resolved_at"`
}

// Blockable is true when at least one address can be blocked safely.
func (r ResolvedSite) Blockable() bool { return len(r.IPs) > 0 }

type cachedLookup struct {
	ips []net.IP
	err string
	at  time.Time
}

// SiteResolver turns website names into the addresses to block. Routers only see
// addresses, so a block by name is a block of the addresses the name points to
// today. Answers are kept for 20 minutes, and an old answer is used when the name
// server cannot be reached.
type SiteResolver struct {
	lookup func(ctx context.Context, host string) ([]net.IP, error)
	now    func() time.Time

	mu    sync.Mutex
	cache map[string]cachedLookup
}

func NewSiteResolver() *SiteResolver {
	return &SiteResolver{
		lookup: func(ctx context.Context, host string) ([]net.IP, error) {
			return net.DefaultResolver.LookupIP(ctx, "ip4", host)
		},
		now:   time.Now,
		cache: map[string]cachedLookup{},
	}
}

// hostsFor lists the names to look up for a blocked domain: the name itself and, for
// a main domain, its www form.
func hostsFor(domain string) []string {
	hosts := []string{domain}
	if isMainDomain(domain) {
		hosts = append(hosts, "www."+domain)
	}
	return hosts
}

// LookupIPs returns every IPv4 address of one name, from the cache when fresh.
func (r *SiteResolver) LookupIPs(ctx context.Context, host string) ([]net.IP, error) {
	r.mu.Lock()
	c, ok := r.cache[host]
	r.mu.Unlock()
	if ok && r.now().Sub(c.at) < resolverTTL && c.err == "" {
		return c.ips, nil
	}
	lctx, cancel := context.WithTimeout(ctx, resolverLookupTime)
	defer cancel()
	ips, err := r.lookup(lctx, host)
	if err != nil {
		if ok && len(c.ips) > 0 {
			return c.ips, nil // keep using the last good answer
		}
		r.mu.Lock()
		r.cache[host] = cachedLookup{err: err.Error(), at: r.now()}
		r.mu.Unlock()
		return nil, err
	}
	var v4 []net.IP
	for _, ip := range ips {
		if ip4 := ip.To4(); ip4 != nil {
			v4 = append(v4, ip4)
		}
	}
	r.mu.Lock()
	r.cache[host] = cachedLookup{ips: v4, at: r.now()}
	r.mu.Unlock()
	return v4, nil
}

// Resolve works out what blocking one typed site means.
func (r *SiteResolver) Resolve(ctx context.Context, target string) ResolvedSite {
	out := ResolvedSite{Target: target, ResolvedAt: r.now(), IPs: []string{}}
	v, kind, err := NormalizeSite(target)
	if err != nil {
		out.Error = err.Error()
		return out
	}
	out.Target, out.Kind = v, kind
	if kind != SiteDomain {
		out.IPs = []string{v}
		return out
	}
	seen := map[string]bool{}
	var firstErr string
	var found int
	providers := map[string]bool{}
	for _, host := range hostsFor(v) {
		ips, err := r.LookupIPs(ctx, host)
		if err != nil {
			if firstErr == "" {
				firstErr = lookupMessage(err)
			}
			continue
		}
		for _, ip := range ips {
			s := ip.String()
			if seen[s] {
				continue
			}
			seen[s] = true
			found++
			if ip.IsPrivate() || ip.IsLoopback() || ip.IsUnspecified() {
				out.Error = "the name points to a private address, so something is already filtering it"
				continue
			}
			if p := sharedProvider(ip); p != "" {
				providers[p] = true
				out.Shared = append(out.Shared, s)
				continue
			}
			out.IPs = append(out.IPs, s)
		}
	}
	sort.Strings(out.IPs)
	sort.Strings(out.Shared)
	for p := range providers {
		out.SharedProvider = p
	}
	out.Many = len(out.IPs) > resolverManyIPs
	switch {
	case found == 0 && firstErr != "":
		out.Error = firstErr
	case found == 0:
		out.Error = "the name does not point to any address"
	case len(out.IPs) == 0 && out.Error == "" && out.SharedProvider != "":
		out.Error = describeShared(out.SharedProvider)
	}
	if len(out.IPs) > 0 {
		out.Error = ""
	}
	return out
}

func lookupMessage(err error) string {
	if dns, ok := err.(*net.DNSError); ok && dns.IsNotFound {
		return "the name does not exist"
	}
	if strings.Contains(err.Error(), "timeout") || strings.Contains(err.Error(), "deadline") {
		return "the name server did not answer in time"
	}
	return "the name could not be looked up"
}

// ResolveAll resolves many sites at once, a few at a time.
func (r *SiteResolver) ResolveAll(ctx context.Context, targets []string) map[string]ResolvedSite {
	out := make(map[string]ResolvedSite, len(targets))
	var mu sync.Mutex
	var wg sync.WaitGroup
	sem := make(chan struct{}, resolverWorkers)
	for _, t := range targets {
		wg.Add(1)
		sem <- struct{}{}
		go func(t string) {
			defer wg.Done()
			defer func() { <-sem }()
			res := r.Resolve(ctx, t)
			mu.Lock()
			out[t] = res
			mu.Unlock()
		}(t)
	}
	wg.Wait()
	return out
}

// AllowedAddresses resolves the always-allowed websites to the addresses a group's
// blocks must let through. Shared ranges are kept here on purpose: that is the point.
func (r *SiteResolver) AllowedAddresses(ctx context.Context, domains []string) []string {
	seen := map[string]bool{}
	var mu sync.Mutex
	var wg sync.WaitGroup
	sem := make(chan struct{}, resolverWorkers)
	for _, d := range domains {
		wg.Add(1)
		sem <- struct{}{}
		go func(d string) {
			defer wg.Done()
			defer func() { <-sem }()
			// A main domain also means its www form; a longer name is looked up as it is.
			for _, host := range hostsFor(d) {
				ips, err := r.LookupIPs(ctx, host)
				if err != nil {
					continue
				}
				mu.Lock()
				for _, ip := range ips {
					if !ip.IsPrivate() && !ip.IsLoopback() && !ip.IsUnspecified() {
						seen[ip.String()] = true
					}
				}
				mu.Unlock()
			}
		}(d)
	}
	wg.Wait()
	out := make([]string, 0, len(seen))
	for ip := range seen {
		out = append(out, ip)
	}
	sort.Strings(out)
	return out
}

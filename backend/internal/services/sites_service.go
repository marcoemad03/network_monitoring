package services

import (
	"context"
	"errors"
	"fmt"
	"sort"
	"strings"
	"time"

	"github.com/google/uuid"
	"github.com/hospital/nms-backend/internal/repository"
)

// ErrSiteExists is returned when a domain already belongs to another catalog entry.
var ErrSiteExists = errors.New("this domain is already in the catalog")

// SitesService turns the recorded lookups into sites with names, categories and
// logos, and manages the catalog the hospital keeps.
type SitesService struct {
	repo      *repository.DNSRepository
	collector *DNSCollector
	clients   *ClientInventoryService
}

func NewSitesService(repo *repository.DNSRepository, collector *DNSCollector, clients *ClientInventoryService) *SitesService {
	return &SitesService{repo: repo, collector: collector, clients: clients}
}

// SiteView is a site as the page shows it: all domains of one organisation or
// service together, with the name and logo the hospital gave it.
type SiteView struct {
	Key       string    `json:"key"` // the first domain; asks for the logo and details
	Name      string    `json:"name"`
	Category  string    `json:"category"`
	Domains   []string  `json:"domains"`
	Named     bool      `json:"named"`      // in the hospital's catalog
	BuiltIn   bool      `json:"built_in"`   // recognised from the built-in list
	CatalogID string    `json:"catalog_id"` // set when Named
	HasLogo   bool      `json:"has_logo"`
	Queries   int64     `json:"queries"`
	Blocked   int64     `json:"blocked"`
	Devices   int       `json:"devices"`
	LastSeen  time.Time `json:"last_seen"`
}

type siteIdentity struct {
	name, category, catalogID string
	domains                   []string
	named, builtIn, hasLogo   bool
}

type siteIndex struct {
	byDomain map[string]*siteIdentity
}

func (s *SitesService) index(ctx context.Context, orgID uuid.UUID) (*siteIndex, []repository.CatalogEntry, error) {
	entries, err := s.repo.Catalog(ctx, orgID)
	if err != nil {
		return nil, nil, err
	}
	idx := &siteIndex{byDomain: map[string]*siteIdentity{}}
	for _, def := range builtInSites {
		id := &siteIdentity{name: def.Name, category: def.Category, domains: def.Domains, builtIn: true}
		for _, d := range def.Domains {
			if _, taken := idx.byDomain[d]; !taken {
				idx.byDomain[d] = id
			}
		}
	}
	for _, e := range entries { // the hospital's own names win over the built-in ones
		id := &siteIdentity{name: e.Name, category: e.Category, domains: e.Domains, named: true, catalogID: e.ID.String(), hasLogo: e.HasLogo}
		for _, d := range e.Domains {
			idx.byDomain[d] = id
		}
	}
	return idx, entries, nil
}

// group merges per-domain counts into per-site rows.
func (idx *siteIndex) group(rows []repository.SiteUse) []SiteView {
	byKey := map[string]*SiteView{}
	order := []string{}
	for _, r := range rows {
		id := idx.byDomain[r.Site]
		key := r.Site
		if id != nil {
			key = id.name + "|" + id.catalogID
		}
		v := byKey[key]
		if v == nil {
			v = &SiteView{Key: r.Site, Name: r.Site, Category: CategoryOther, Domains: []string{}}
			if id != nil {
				v.Name, v.Category, v.Named, v.BuiltIn, v.CatalogID, v.HasLogo = id.name, id.category, id.named, id.builtIn && !id.named, id.catalogID, id.hasLogo
			}
			byKey[key] = v
			order = append(order, key)
		}
		v.Domains = append(v.Domains, r.Site)
		v.Queries += r.Queries
		v.Blocked += r.Blocked
		if r.Devices > v.Devices {
			v.Devices = r.Devices // the busiest domain of the site: a lower bound for the whole site
		}
		if r.LastSeen.After(v.LastSeen) {
			v.LastSeen = r.LastSeen
		}
	}
	out := make([]SiteView, 0, len(order))
	for _, k := range order {
		out = append(out, *byKey[k])
	}
	return out
}

// SitesOverview is the response of the sites endpoint.
type SitesOverview struct {
	Recording  bool                      `json:"recording"` // any lookups stored at all
	Sources    []DNSSourceStatus         `json:"sources"`
	Since      time.Time                 `json:"since"`
	Hours      int                       `json:"hours"`
	First      *time.Time                `json:"first_recorded_at,omitempty"`
	Last       *time.Time                `json:"last_recorded_at,omitempty"`
	Queries    int64                     `json:"queries"`
	Devices    int                       `json:"devices"`
	Retention  int                       `json:"retention_days"`
	Sites      []SiteView                `json:"sites"`
	ByCategory map[string]int            `json:"sites_by_category"`
	Unnamed    int                       `json:"unnamed_in_view"`
	Categories []string                  `json:"categories"`
	Catalog    []repository.CatalogEntry `json:"catalog"`
	Hidden     map[string]int            `json:"hidden"`
}

// Overview ranks the sites devices asked for in the last `hours`. Background
// services (updates, telemetry, content delivery) are left out unless asked for.
func (s *SitesService) Overview(ctx context.Context, orgID uuid.UUID, hours int, withBackground bool, retention int) (SitesOverview, error) {
	if hours < 1 {
		hours = 24
	}
	if hours > 24*90 {
		hours = 24 * 90
	}
	since := time.Now().Add(-time.Duration(hours) * time.Hour)
	out := SitesOverview{
		Sources: s.collector.Sources(), Since: since, Hours: hours, Retention: retention, Sites: []SiteView{},
		ByCategory: map[string]int{}, Categories: SiteCategories(), Hidden: map[string]int{},
	}
	idx, entries, err := s.index(ctx, orgID)
	if err != nil {
		return out, err
	}
	out.Catalog = entries
	cov, err := s.repo.Coverage(ctx, orgID)
	if err != nil {
		return out, err
	}
	out.Recording = cov.Queries > 0
	if !cov.First.IsZero() {
		first, last := cov.First, cov.Last
		out.First, out.Last = &first, &last
	}
	rows, err := s.repo.TopSites(ctx, orgID, since, 2000)
	if err != nil {
		return out, err
	}
	all := idx.group(rows)
	for _, v := range all {
		out.Queries += v.Queries
	}
	devices := map[string]struct{}{}
	if devs, err := s.repo.SiteDevices(ctx, orgID, domainsOf(all), since, 5000); err == nil {
		for _, d := range devs {
			devices[firstNonBlank(d.MAC, d.IP)] = struct{}{}
		}
	}
	out.Devices = len(devices)

	for _, v := range all {
		if v.Category == CategoryBackground && !withBackground {
			out.Hidden[CategoryBackground] += int(v.Queries)
			continue
		}
		out.ByCategory[v.Category]++
		if !v.Named && !v.BuiltIn {
			out.Unnamed++
		}
		out.Sites = append(out.Sites, v)
	}
	sort.SliceStable(out.Sites, func(i, j int) bool {
		a, b := out.Sites[i], out.Sites[j]
		if a.Devices != b.Devices {
			return a.Devices > b.Devices
		}
		return a.Queries > b.Queries
	})
	if len(out.Sites) > 200 {
		out.Sites = out.Sites[:200]
	}
	return out, nil
}

func domainsOf(sites []SiteView) []string {
	var out []string
	for _, s := range sites {
		out = append(out, s.Domains...)
	}
	return out
}

func firstNonBlank(a, b string) string {
	if a != "" {
		return a
	}
	return b
}

// DeviceSites is what one device looked up, for the device dialog.
type DeviceSitesResult struct {
	Name      string     `json:"name"`
	Kind      string     `json:"kind"`
	IP        string     `json:"ip"`
	MAC       string     `json:"mac"`
	Hours     int        `json:"hours"`
	Sites     []SiteView `json:"sites"`
	Hidden    int64      `json:"hidden_background_queries"`
	Recording bool       `json:"recording"`
}

// DeviceSites lists the sites one device (MAC or IP) asked for.
func (s *SitesService) DeviceSites(ctx context.Context, orgID uuid.UUID, key string, hours int, withBackground bool) (DeviceSitesResult, error) {
	if hours < 1 {
		hours = 24
	}
	if hours > 24*90 {
		hours = 24 * 90
	}
	res := DeviceSitesResult{Hours: hours, Sites: []SiteView{}}
	mac, ip := "", ""
	if strings.Contains(key, ":") && len(key) == 17 {
		mac = strings.ToUpper(key)
	} else {
		ip = key
	}
	if list, err := s.clients.List(ctx, orgID); err == nil {
		for _, c := range list.Clients {
			if (mac != "" && strings.EqualFold(c.MAC, mac)) || (mac == "" && c.IP == ip) {
				res.Name, res.Kind, res.IP, res.MAC = c.DisplayName, c.Kind, c.IP, c.MAC
				mac = c.MAC
				break
			}
		}
	}
	if res.Name == "" {
		res.Name, res.IP, res.MAC, res.Kind = firstNonBlank(ip, mac), ip, mac, "unknown"
	}
	idx, _, err := s.index(ctx, orgID)
	if err != nil {
		return res, err
	}
	rows, err := s.repo.DeviceSites(ctx, orgID, mac, ip, time.Now().Add(-time.Duration(hours)*time.Hour), 1000)
	if err != nil {
		return res, err
	}
	res.Recording = len(rows) > 0
	for _, v := range idx.group(rows) {
		if v.Category == CategoryBackground && !withBackground {
			res.Hidden += v.Queries
			continue
		}
		v.Devices = 1
		res.Sites = append(res.Sites, v)
	}
	sort.SliceStable(res.Sites, func(i, j int) bool { return res.Sites[i].Queries > res.Sites[j].Queries })
	if len(res.Sites) > 100 {
		res.Sites = res.Sites[:100]
	}
	return res, nil
}

// SiteDevice is a device that asked for a site.
type SiteDevice struct {
	MAC      string    `json:"mac"`
	IP       string    `json:"ip"`
	Name     string    `json:"name"`
	Kind     string    `json:"kind"`
	Queries  int64     `json:"queries"`
	Blocked  int64     `json:"blocked"`
	LastSeen time.Time `json:"last_seen"`
}

// SiteDetail is one site and the devices that asked for it.
type SiteDetail struct {
	Site    SiteView     `json:"site"`
	Devices []SiteDevice `json:"devices"`
	Hours   int          `json:"hours"`
}

// SiteDevices says which devices asked for a site (any of the domains of its catalog entry).
func (s *SitesService) SiteDevices(ctx context.Context, orgID uuid.UUID, domain string, hours int) (SiteDetail, error) {
	if hours < 1 {
		hours = 24
	}
	site, err := CleanSiteDomain(domain)
	if err != nil {
		return SiteDetail{}, err
	}
	idx, _, err := s.index(ctx, orgID)
	if err != nil {
		return SiteDetail{}, err
	}
	domains := []string{site}
	if id := idx.byDomain[site]; id != nil {
		domains = id.domains
	}
	since := time.Now().Add(-time.Duration(hours) * time.Hour)
	rows, err := s.repo.SiteDevices(ctx, orgID, domains, since, 200)
	if err != nil {
		return SiteDetail{}, err
	}
	detail := SiteDetail{Hours: hours, Devices: []SiteDevice{}}
	sites, _ := s.repo.TopSites(ctx, orgID, since, 2000)
	var mine []repository.SiteUse
	for _, r := range sites {
		for _, d := range domains {
			if r.Site == d {
				mine = append(mine, r)
			}
		}
	}
	if grouped := idx.group(mine); len(grouped) > 0 {
		detail.Site = grouped[0]
	} else {
		detail.Site = SiteView{Key: site, Name: site, Category: CategoryOther, Domains: domains}
		if id := idx.byDomain[site]; id != nil {
			detail.Site.Name, detail.Site.Category, detail.Site.Named, detail.Site.CatalogID, detail.Site.HasLogo = id.name, id.category, id.named, id.catalogID, id.hasLogo
		}
	}
	detail.Site.Devices = len(rows)

	names := map[string]ClientView{}
	if list, err := s.clients.List(ctx, orgID); err == nil {
		for _, c := range list.Clients {
			names[c.MAC] = c
			if c.IP != "" {
				if _, ok := names["ip:"+c.IP]; !ok {
					names["ip:"+c.IP] = c
				}
			}
		}
	}
	for _, r := range rows {
		d := SiteDevice{MAC: r.MAC, IP: r.IP, Name: firstNonBlank(r.IP, r.MAC), Kind: "unknown", Queries: r.Queries, Blocked: r.Blocked, LastSeen: r.LastSeen}
		c, ok := names[r.MAC]
		if !ok || r.MAC == "" {
			c, ok = names["ip:"+r.IP]
		}
		if ok {
			d.Name, d.Kind = c.DisplayName, c.Kind
		}
		detail.Devices = append(detail.Devices, d)
	}
	return detail, nil
}

// ---------------------------------------------------------------------------
// Catalog

// CatalogInput is what a person gives to name a site.
type CatalogInput struct {
	Name     string
	Category string
	Domains  []string
}

func (s *SitesService) clean(in CatalogInput) (CatalogInput, error) {
	in.Name = strings.TrimSpace(in.Name)
	if in.Name == "" || len([]rune(in.Name)) > 120 {
		return in, errors.New("give the site a name of up to 120 characters")
	}
	if in.Category == "" {
		in.Category = CategoryOther
	}
	if !validCategory(in.Category) {
		return in, fmt.Errorf("unknown category %q", in.Category)
	}
	seen := map[string]bool{}
	var domains []string
	for _, raw := range in.Domains {
		d, err := CleanSiteDomain(raw)
		if err != nil {
			return in, err
		}
		if !seen[d] {
			seen[d] = true
			domains = append(domains, d)
		}
	}
	if len(domains) == 0 {
		return in, errors.New("add at least one domain")
	}
	if len(domains) > 20 {
		return in, errors.New("a site can have up to 20 domains")
	}
	in.Domains = domains
	return in, nil
}

// checkFree makes sure no other catalog entry lists one of the domains.
func (s *SitesService) checkFree(entries []repository.CatalogEntry, domains []string, except uuid.UUID) error {
	for _, e := range entries {
		if e.ID == except {
			continue
		}
		for _, have := range e.Domains {
			for _, want := range domains {
				if have == want {
					return fmt.Errorf("%w: %s is listed under %q", ErrSiteExists, want, e.Name)
				}
			}
		}
	}
	return nil
}

func (s *SitesService) Create(ctx context.Context, orgID uuid.UUID, in CatalogInput) (repository.CatalogEntry, error) {
	in, err := s.clean(in)
	if err != nil {
		return repository.CatalogEntry{}, err
	}
	entries, err := s.repo.Catalog(ctx, orgID)
	if err != nil {
		return repository.CatalogEntry{}, err
	}
	if err := s.checkFree(entries, in.Domains, uuid.Nil); err != nil {
		return repository.CatalogEntry{}, err
	}
	return s.repo.CreateCatalogEntry(ctx, orgID, in.Name, in.Category, in.Domains)
}

func (s *SitesService) Update(ctx context.Context, orgID, id uuid.UUID, in CatalogInput) (repository.CatalogEntry, error) {
	in, err := s.clean(in)
	if err != nil {
		return repository.CatalogEntry{}, err
	}
	entries, err := s.repo.Catalog(ctx, orgID)
	if err != nil {
		return repository.CatalogEntry{}, err
	}
	if err := s.checkFree(entries, in.Domains, id); err != nil {
		return repository.CatalogEntry{}, err
	}
	return s.repo.UpdateCatalogEntry(ctx, orgID, id, in.Name, in.Category, in.Domains)
}

func (s *SitesService) Delete(ctx context.Context, orgID, id uuid.UUID) error {
	return s.repo.DeleteCatalogEntry(ctx, orgID, id)
}

// FetchLogo downloads the logo of a catalog entry from its own site, trying each of
// its domains in turn.
func (s *SitesService) FetchLogo(ctx context.Context, orgID, id uuid.UUID) (repository.CatalogEntry, error) {
	return s.FetchLogoFrom(ctx, orgID, id, "")
}

// FetchLogoFrom is FetchLogo, or, when imageURL is given, a download of that image.
func (s *SitesService) FetchLogoFrom(ctx context.Context, orgID, id uuid.UUID, imageURL string) (repository.CatalogEntry, error) {
	entry, err := s.repo.CatalogEntry(ctx, orgID, id)
	if err != nil {
		return entry, err
	}
	if strings.TrimSpace(imageURL) != "" {
		data, ct, err := FetchLogoImage(ctx, imageURL)
		if err != nil {
			return entry, err
		}
		if err := s.repo.SetLogo(ctx, orgID, id, data, ct, strings.TrimSpace(imageURL)); err != nil {
			return entry, err
		}
		return s.repo.CatalogEntry(ctx, orgID, id)
	}
	var lastErr error
	for _, d := range entry.Domains {
		data, ct, source, err := FetchSiteLogo(ctx, d)
		if err != nil {
			lastErr = fmt.Errorf("%s: %w", d, err)
			continue
		}
		if err := s.repo.SetLogo(ctx, orgID, id, data, ct, source); err != nil {
			return entry, err
		}
		return s.repo.CatalogEntry(ctx, orgID, id)
	}
	if lastErr == nil {
		lastErr = errors.New("no domain to fetch from")
	}
	return entry, lastErr
}

// SetLogo stores an uploaded image after checking the bytes.
func (s *SitesService) SetLogo(ctx context.Context, orgID, id uuid.UUID, data []byte) (repository.CatalogEntry, error) {
	ct, err := SniffLogo(data)
	if err != nil {
		return repository.CatalogEntry{}, err
	}
	if err := s.repo.SetLogo(ctx, orgID, id, data, ct, "upload"); err != nil {
		return repository.CatalogEntry{}, err
	}
	return s.repo.CatalogEntry(ctx, orgID, id)
}

func (s *SitesService) ClearLogo(ctx context.Context, orgID, id uuid.UUID) error {
	return s.repo.ClearLogo(ctx, orgID, id)
}

// Logo returns the logo for a domain, if its catalog entry has one.
func (s *SitesService) Logo(ctx context.Context, orgID uuid.UUID, domain string) ([]byte, string, error) {
	d, err := CleanSiteDomain(domain)
	if err != nil {
		return nil, "", repository.ErrNotFound
	}
	return s.repo.LogoFor(ctx, orgID, d)
}

// Adopt puts a site seen in the recording into the catalog. A built-in site keeps
// its name and category; any other needs a name from the person.
func (s *SitesService) Adopt(ctx context.Context, orgID uuid.UUID, domain, name, category string) (repository.CatalogEntry, error) {
	site, err := CleanSiteDomain(domain)
	if err != nil {
		return repository.CatalogEntry{}, err
	}
	in := CatalogInput{Name: name, Category: category, Domains: []string{site}}
	for _, def := range builtInSites {
		for _, d := range def.Domains {
			if d == site {
				if in.Name == "" {
					in.Name = def.Name
				}
				if in.Category == "" {
					in.Category = def.Category
				}
				in.Domains = def.Domains
			}
		}
	}
	return s.Create(ctx, orgID, in)
}

package repository

import (
	"context"
	"errors"
	"time"

	"github.com/google/uuid"
	"github.com/hospital/nms-backend/internal/database"
	"github.com/jackc/pgx/v5"
)

// ErrNotFound is returned when a catalog entry does not exist.
var ErrNotFound = errors.New("not found")

// DNSRepository stores which sites the devices asked for, and the names and logos
// the hospital gave to sites.
type DNSRepository struct {
	db *database.DB
}

func NewDNSRepository(db *database.DB) *DNSRepository {
	return &DNSRepository{db: db}
}

// DNSRow is the number of lookups one device made for one site in one hour.
type DNSRow struct {
	Bucket  time.Time
	IP, MAC string
	Site    string
	Queries int
	Blocked int
}

// SiteUse is a site ranked over a period.
type SiteUse struct {
	Site     string    `json:"site"`
	Queries  int64     `json:"queries"`
	Blocked  int64     `json:"blocked"`
	Devices  int       `json:"devices"`
	LastSeen time.Time `json:"last_seen"`
}

// DeviceSiteUse is one device's use of one site.
type DeviceSiteUse struct {
	MAC      string    `json:"mac"`
	IP       string    `json:"ip"`
	Queries  int64     `json:"queries"`
	Blocked  int64     `json:"blocked"`
	LastSeen time.Time `json:"last_seen"`
}

// DNSCoverage says what the recording holds.
type DNSCoverage struct {
	First, Last time.Time
	Queries     int64
	Clients     int
}

// UpsertActivity adds the counts to what is already stored for the same hour.
func (r *DNSRepository) UpsertActivity(ctx context.Context, orgID uuid.UUID, rows []DNSRow) error {
	if len(rows) == 0 {
		return nil
	}
	buckets := make([]time.Time, len(rows))
	ips, macs, sites := make([]string, len(rows)), make([]string, len(rows)), make([]string, len(rows))
	queries, blocked := make([]int32, len(rows)), make([]int32, len(rows))
	for i, row := range rows {
		buckets[i], ips[i], macs[i], sites[i] = row.Bucket, row.IP, row.MAC, row.Site
		queries[i], blocked[i] = int32(row.Queries), int32(row.Blocked)
	}
	_, err := r.db.Exec(ctx,
		`INSERT INTO dns_activity (organization_id, bucket, client_ip, client_mac, site, queries, blocked)
		 SELECT $1, b, ip, mac, s, q, bl FROM unnest($2::timestamptz[], $3::text[], $4::text[], $5::text[], $6::int[], $7::int[]) AS t(b, ip, mac, s, q, bl)
		 ON CONFLICT (organization_id, bucket, client_ip, site)
		 DO UPDATE SET queries = dns_activity.queries + EXCLUDED.queries,
		               blocked = dns_activity.blocked + EXCLUDED.blocked,
		               client_mac = CASE WHEN EXCLUDED.client_mac <> '' THEN EXCLUDED.client_mac ELSE dns_activity.client_mac END`,
		orgID, buckets, ips, macs, sites, queries, blocked)
	return err
}

// TopSites ranks sites by the number of devices that asked for them, then lookups.
func (r *DNSRepository) TopSites(ctx context.Context, orgID uuid.UUID, since time.Time, limit int) ([]SiteUse, error) {
	rows, err := r.db.Query(ctx,
		`SELECT site, SUM(queries), SUM(blocked), COUNT(DISTINCT CASE WHEN client_mac <> '' THEN client_mac ELSE client_ip END), MAX(bucket)
		   FROM dns_activity WHERE organization_id = $1 AND bucket >= $2
		  GROUP BY site ORDER BY 4 DESC, 2 DESC LIMIT $3`, orgID, since, limit)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	out := []SiteUse{}
	for rows.Next() {
		var s SiteUse
		if err := rows.Scan(&s.Site, &s.Queries, &s.Blocked, &s.Devices, &s.LastSeen); err != nil {
			return nil, err
		}
		out = append(out, s)
	}
	return out, rows.Err()
}

// DeviceSites ranks the sites one device asked for. The device is given by MAC or,
// when there is none, by IP.
func (r *DNSRepository) DeviceSites(ctx context.Context, orgID uuid.UUID, mac, ip string, since time.Time, limit int) ([]SiteUse, error) {
	rows, err := r.db.Query(ctx,
		`SELECT site, SUM(queries), SUM(blocked), 1, MAX(bucket)
		   FROM dns_activity
		  WHERE organization_id = $1 AND bucket >= $2 AND (($3 <> '' AND client_mac = $3) OR ($3 = '' AND client_ip = $4))
		  GROUP BY site ORDER BY 2 DESC LIMIT $5`, orgID, since, mac, ip, limit)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	out := []SiteUse{}
	for rows.Next() {
		var s SiteUse
		if err := rows.Scan(&s.Site, &s.Queries, &s.Blocked, &s.Devices, &s.LastSeen); err != nil {
			return nil, err
		}
		out = append(out, s)
	}
	return out, rows.Err()
}

// SiteDevices lists the devices that asked for any of the given sites.
func (r *DNSRepository) SiteDevices(ctx context.Context, orgID uuid.UUID, sites []string, since time.Time, limit int) ([]DeviceSiteUse, error) {
	rows, err := r.db.Query(ctx,
		`SELECT client_mac, client_ip, SUM(queries), SUM(blocked), MAX(bucket)
		   FROM dns_activity WHERE organization_id = $1 AND bucket >= $2 AND site = ANY($3)
		  GROUP BY client_mac, client_ip ORDER BY 3 DESC LIMIT $4`, orgID, since, sites, limit)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	out := []DeviceSiteUse{}
	for rows.Next() {
		var d DeviceSiteUse
		if err := rows.Scan(&d.MAC, &d.IP, &d.Queries, &d.Blocked, &d.LastSeen); err != nil {
			return nil, err
		}
		out = append(out, d)
	}
	return out, rows.Err()
}

// Coverage reports the span and size of the recording since a time.
func (r *DNSRepository) Coverage(ctx context.Context, orgID uuid.UUID) (DNSCoverage, error) {
	var c DNSCoverage
	var first, last *time.Time
	err := r.db.QueryRow(ctx,
		`SELECT MIN(bucket), MAX(bucket), COALESCE(SUM(queries), 0),
		        COUNT(DISTINCT CASE WHEN client_mac <> '' THEN client_mac ELSE client_ip END)
		   FROM dns_activity WHERE organization_id = $1`, orgID).Scan(&first, &last, &c.Queries, &c.Clients)
	if first != nil {
		c.First = *first
	}
	if last != nil {
		c.Last = *last
	}
	return c, err
}

// PruneDNS deletes activity older than the retention window.
func (r *DNSRepository) PruneDNS(ctx context.Context, before time.Time) error {
	_, err := r.db.Exec(ctx, `DELETE FROM dns_activity WHERE bucket < $1`, before)
	return err
}

// ---------------------------------------------------------------------------
// Catalog

// CatalogEntry is a site the hospital has named.
type CatalogEntry struct {
	ID            uuid.UUID  `json:"id"`
	Name          string     `json:"name"`
	Category      string     `json:"category"`
	Domains       []string   `json:"domains"`
	HasLogo       bool       `json:"has_logo"`
	LogoSource    string     `json:"logo_source,omitempty"`
	LogoUpdatedAt *time.Time `json:"logo_updated_at,omitempty"`
}

const catalogColumns = `id, name, category, domains, (logo IS NOT NULL), COALESCE(logo_source, ''), logo_updated_at`

func scanCatalog(row pgx.Row) (CatalogEntry, error) {
	var e CatalogEntry
	err := row.Scan(&e.ID, &e.Name, &e.Category, &e.Domains, &e.HasLogo, &e.LogoSource, &e.LogoUpdatedAt)
	return e, err
}

func (r *DNSRepository) Catalog(ctx context.Context, orgID uuid.UUID) ([]CatalogEntry, error) {
	rows, err := r.db.Query(ctx, `SELECT `+catalogColumns+` FROM site_catalog WHERE organization_id = $1 ORDER BY lower(name)`, orgID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	out := []CatalogEntry{}
	for rows.Next() {
		e, err := scanCatalog(rows)
		if err != nil {
			return nil, err
		}
		out = append(out, e)
	}
	return out, rows.Err()
}

func (r *DNSRepository) CatalogEntry(ctx context.Context, orgID, id uuid.UUID) (CatalogEntry, error) {
	e, err := scanCatalog(r.db.QueryRow(ctx, `SELECT `+catalogColumns+` FROM site_catalog WHERE organization_id = $1 AND id = $2`, orgID, id))
	if errors.Is(err, pgx.ErrNoRows) {
		return e, ErrNotFound
	}
	return e, err
}

func (r *DNSRepository) CreateCatalogEntry(ctx context.Context, orgID uuid.UUID, name, category string, domains []string) (CatalogEntry, error) {
	return scanCatalog(r.db.QueryRow(ctx,
		`INSERT INTO site_catalog (organization_id, name, category, domains) VALUES ($1,$2,$3,$4) RETURNING `+catalogColumns,
		orgID, name, category, domains))
}

func (r *DNSRepository) UpdateCatalogEntry(ctx context.Context, orgID, id uuid.UUID, name, category string, domains []string) (CatalogEntry, error) {
	e, err := scanCatalog(r.db.QueryRow(ctx,
		`UPDATE site_catalog SET name = $3, category = $4, domains = $5, updated_at = NOW()
		  WHERE organization_id = $1 AND id = $2 RETURNING `+catalogColumns, orgID, id, name, category, domains))
	if errors.Is(err, pgx.ErrNoRows) {
		return e, ErrNotFound
	}
	return e, err
}

func (r *DNSRepository) DeleteCatalogEntry(ctx context.Context, orgID, id uuid.UUID) error {
	tag, err := r.db.Exec(ctx, `DELETE FROM site_catalog WHERE organization_id = $1 AND id = $2`, orgID, id)
	if err == nil && tag.RowsAffected() == 0 {
		return ErrNotFound
	}
	return err
}

// SetLogo stores the image and where it came from ("upload" or the address it was fetched from).
func (r *DNSRepository) SetLogo(ctx context.Context, orgID, id uuid.UUID, image []byte, contentType, source string) error {
	tag, err := r.db.Exec(ctx,
		`UPDATE site_catalog SET logo = $3, logo_type = $4, logo_source = $5, logo_updated_at = NOW(), updated_at = NOW()
		  WHERE organization_id = $1 AND id = $2`, orgID, id, image, contentType, source)
	if err == nil && tag.RowsAffected() == 0 {
		return ErrNotFound
	}
	return err
}

func (r *DNSRepository) ClearLogo(ctx context.Context, orgID, id uuid.UUID) error {
	_, err := r.db.Exec(ctx,
		`UPDATE site_catalog SET logo = NULL, logo_type = NULL, logo_source = NULL, logo_updated_at = NULL WHERE organization_id = $1 AND id = $2`, orgID, id)
	return err
}

// LogoFor returns the logo of the catalog entry that lists the domain.
func (r *DNSRepository) LogoFor(ctx context.Context, orgID uuid.UUID, domain string) ([]byte, string, error) {
	var image []byte
	var contentType string
	err := r.db.QueryRow(ctx,
		`SELECT logo, COALESCE(logo_type, '') FROM site_catalog WHERE organization_id = $1 AND $2 = ANY(domains) AND logo IS NOT NULL LIMIT 1`,
		orgID, domain).Scan(&image, &contentType)
	if errors.Is(err, pgx.ErrNoRows) {
		return nil, "", ErrNotFound
	}
	return image, contentType, err
}

// LogoOfEntry returns the logo of one catalog entry.
func (r *DNSRepository) LogoOfEntry(ctx context.Context, orgID, id uuid.UUID) ([]byte, string, error) {
	var image []byte
	var contentType string
	err := r.db.QueryRow(ctx,
		`SELECT logo, COALESCE(logo_type, '') FROM site_catalog WHERE organization_id = $1 AND id = $2 AND logo IS NOT NULL`,
		orgID, id).Scan(&image, &contentType)
	if errors.Is(err, pgx.ErrNoRows) {
		return nil, "", ErrNotFound
	}
	return image, contentType, err
}

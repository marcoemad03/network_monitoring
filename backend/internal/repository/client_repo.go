package repository

import (
	"context"
	"time"

	"github.com/google/uuid"
	"github.com/hospital/nms-backend/internal/database"
)

// ClientRepository stores the network device inventory.
type ClientRepository struct {
	db *database.DB
}

func NewClientRepository(db *database.DB) *ClientRepository {
	return &ClientRepository{db: db}
}

// SeenClient is a device observed on the network right now.
type SeenClient struct {
	MAC           string
	IP            string
	Hostname      string
	RouterComment string
	Network       string
}

// KnownClient is what is remembered about a device between polls.
type KnownClient struct {
	MAC           string
	FirstSeen     time.Time
	LastSeen      time.Time
	LastIP        string
	Hostname      string
	RouterComment string
	Network       string
}

// ClientNote is what a person wrote about a device.
type ClientNote struct {
	DisplayName  string
	Note         string
	KindOverride string
	UpdatedAt    time.Time
}

// NotePatch changes only the fields that are set.
type NotePatch struct {
	DisplayName  *string
	Note         *string
	KindOverride *string
}

// ClientUsage is the data a device moved in a period. Download is data the
// device received, upload is data it sent.
type ClientUsage struct {
	TodayDown, TodayUp int64
	MonthDown, MonthUp int64
}

// ClientDay is one day of a device's usage.
type ClientDay struct {
	Day  time.Time `json:"day"`
	Down int64     `json:"download_bytes"`
	Up   int64     `json:"upload_bytes"`
}

// MarkSeen records the devices seen in the latest poll.
func (r *ClientRepository) MarkSeen(ctx context.Context, orgID uuid.UUID, at time.Time, seen []SeenClient) error {
	if len(seen) == 0 {
		return nil
	}
	macs := make([]string, len(seen))
	ips := make([]string, len(seen))
	hosts := make([]string, len(seen))
	comments := make([]string, len(seen))
	networks := make([]string, len(seen))
	for i, s := range seen {
		macs[i], ips[i], hosts[i], comments[i], networks[i] = s.MAC, s.IP, s.Hostname, s.RouterComment, s.Network
	}
	_, err := r.db.Exec(ctx,
		`INSERT INTO client_devices (organization_id, mac, first_seen, last_seen, last_ip, hostname, router_comment, network_name)
		 SELECT $1, m, $2, $2, i, h, c, n
		   FROM unnest($3::text[], $4::text[], $5::text[], $6::text[], $7::text[]) AS t(m, i, h, c, n)
		 ON CONFLICT (organization_id, mac) DO UPDATE SET
		   last_seen = EXCLUDED.last_seen,
		   last_ip = EXCLUDED.last_ip,
		   hostname = CASE WHEN EXCLUDED.hostname <> '' THEN EXCLUDED.hostname ELSE client_devices.hostname END,
		   router_comment = EXCLUDED.router_comment,
		   network_name = EXCLUDED.network_name`,
		orgID, at, macs, ips, hosts, comments, networks)
	return err
}

// AddUsage adds bytes to a day's totals. The slices are parallel.
func (r *ClientRepository) AddUsage(ctx context.Context, orgID uuid.UUID, day time.Time, macs []string, down, up []int64) error {
	if len(macs) == 0 {
		return nil
	}
	_, err := r.db.Exec(ctx,
		`INSERT INTO client_usage_daily (organization_id, mac, day, download_bytes, upload_bytes)
		 SELECT $1, m, $2::date, d, u FROM unnest($3::text[], $4::bigint[], $5::bigint[]) AS t(m, d, u)
		 ON CONFLICT (organization_id, mac, day) DO UPDATE SET
		   download_bytes = client_usage_daily.download_bytes + EXCLUDED.download_bytes,
		   upload_bytes = client_usage_daily.upload_bytes + EXCLUDED.upload_bytes`,
		orgID, day, macs, down, up)
	return err
}

// Known returns every remembered device, newest first.
func (r *ClientRepository) Known(ctx context.Context, orgID uuid.UUID, limit int) ([]KnownClient, error) {
	rows, err := r.db.Query(ctx,
		`SELECT mac, first_seen, last_seen, last_ip, hostname, router_comment, network_name
		   FROM client_devices WHERE organization_id = $1 ORDER BY last_seen DESC LIMIT $2`, orgID, limit)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var out []KnownClient
	for rows.Next() {
		var k KnownClient
		if err := rows.Scan(&k.MAC, &k.FirstSeen, &k.LastSeen, &k.LastIP, &k.Hostname, &k.RouterComment, &k.Network); err != nil {
			return nil, err
		}
		out = append(out, k)
	}
	return out, rows.Err()
}

// Usage returns today's and this month's totals per device.
func (r *ClientRepository) Usage(ctx context.Context, orgID uuid.UUID, today, monthStart time.Time) (map[string]ClientUsage, error) {
	rows, err := r.db.Query(ctx,
		`SELECT mac,
		        COALESCE(SUM(download_bytes) FILTER (WHERE day = $2::date), 0),
		        COALESCE(SUM(upload_bytes)   FILTER (WHERE day = $2::date), 0),
		        COALESCE(SUM(download_bytes), 0), COALESCE(SUM(upload_bytes), 0)
		   FROM client_usage_daily WHERE organization_id = $1 AND day >= $3::date GROUP BY mac`,
		orgID, today, monthStart)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	out := make(map[string]ClientUsage)
	for rows.Next() {
		var mac string
		var u ClientUsage
		if err := rows.Scan(&mac, &u.TodayDown, &u.TodayUp, &u.MonthDown, &u.MonthUp); err != nil {
			return nil, err
		}
		out[mac] = u
	}
	return out, rows.Err()
}

// Daily returns one device's usage per day since the given day.
func (r *ClientRepository) Daily(ctx context.Context, orgID uuid.UUID, mac string, since time.Time) ([]ClientDay, error) {
	rows, err := r.db.Query(ctx,
		`SELECT day::timestamptz, download_bytes, upload_bytes FROM client_usage_daily
		  WHERE organization_id = $1 AND mac = $2 AND day >= $3::date ORDER BY day`, orgID, mac, since)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	out := []ClientDay{}
	for rows.Next() {
		var d ClientDay
		if err := rows.Scan(&d.Day, &d.Down, &d.Up); err != nil {
			return nil, err
		}
		out = append(out, d)
	}
	return out, rows.Err()
}

// Notes returns the notes of all devices, by MAC.
func (r *ClientRepository) Notes(ctx context.Context, orgID uuid.UUID) (map[string]ClientNote, error) {
	rows, err := r.db.Query(ctx,
		`SELECT mac, display_name, note, kind_override, updated_at FROM client_device_notes WHERE organization_id = $1`, orgID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	out := make(map[string]ClientNote)
	for rows.Next() {
		var mac string
		var n ClientNote
		if err := rows.Scan(&mac, &n.DisplayName, &n.Note, &n.KindOverride, &n.UpdatedAt); err != nil {
			return nil, err
		}
		out[mac] = n
	}
	return out, rows.Err()
}

// SaveNote changes the given fields of a device's note and returns the result.
func (r *ClientRepository) SaveNote(ctx context.Context, orgID uuid.UUID, mac string, p NotePatch) (ClientNote, error) {
	var n ClientNote
	err := r.db.QueryRow(ctx,
		`INSERT INTO client_device_notes (organization_id, mac, display_name, note, kind_override, updated_at)
		 VALUES ($1, $2, COALESCE($3, ''), COALESCE($4, ''), COALESCE($5, ''), NOW())
		 ON CONFLICT (organization_id, mac) DO UPDATE SET
		   display_name = COALESCE($3, client_device_notes.display_name),
		   note = COALESCE($4, client_device_notes.note),
		   kind_override = COALESCE($5, client_device_notes.kind_override),
		   updated_at = NOW()
		 RETURNING display_name, note, kind_override, updated_at`,
		orgID, mac, p.DisplayName, p.Note, p.KindOverride).
		Scan(&n.DisplayName, &n.Note, &n.KindOverride, &n.UpdatedAt)
	return n, err
}

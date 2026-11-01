package repository

import (
	"context"
	"time"

	"github.com/google/uuid"
	"github.com/hospital/nms-backend/internal/database"
)

// SecurityRepository stores the results of security scans.
type SecurityRepository struct {
	db *database.DB
}

func NewSecurityRepository(db *database.DB) *SecurityRepository {
	return &SecurityRepository{db: db}
}

// ScanRecord is the summary of one scan.
type ScanRecord struct {
	ID              int64
	TakenAt         time.Time
	Connections     int
	Devices         int
	DurationMs      int
	RouterCPUBefore int
	RouterCPUAfter  int
}

// FlowRow is what one device exchanged with one destination in a scan.
type FlowRow struct {
	MAC, IP, Label, Kind string
	Down, Up             int64
	Connections          int
}

// FindingRow is a finding stored with a scan.
type FindingRow struct {
	MAC, IP, Severity, Code, Title, Detail string
}

// PopularLabel is a destination ranked over a period.
type PopularLabel struct {
	Label       string `json:"label"`
	Kind        string `json:"kind"`
	Devices     int    `json:"devices"`
	Scans       int    `json:"scans"`
	Connections int64  `json:"connections"`
	Bytes       int64  `json:"bytes"`
}

// InsertScan stores a scan and its rows together.
func (r *SecurityRepository) InsertScan(ctx context.Context, orgID uuid.UUID, s ScanRecord, flows []FlowRow, findings []FindingRow) (int64, error) {
	var id int64
	err := r.db.QueryRow(ctx,
		`INSERT INTO security_scans (organization_id, taken_at, connections, devices, duration_ms, router_cpu_before, router_cpu_after)
		 VALUES ($1,$2,$3,$4,$5,$6,$7) RETURNING id`,
		orgID, s.TakenAt, s.Connections, s.Devices, s.DurationMs, s.RouterCPUBefore, s.RouterCPUAfter).Scan(&id)
	if err != nil {
		return 0, err
	}

	if len(flows) > 0 {
		macs, ips, labels, kinds := make([]string, len(flows)), make([]string, len(flows)), make([]string, len(flows)), make([]string, len(flows))
		down, up, conns := make([]int64, len(flows)), make([]int64, len(flows)), make([]int32, len(flows))
		for i, f := range flows {
			macs[i], ips[i], labels[i], kinds[i], down[i], up[i], conns[i] = f.MAC, f.IP, f.Label, f.Kind, f.Down, f.Up, int32(f.Connections)
		}
		if _, err := r.db.Exec(ctx,
			`INSERT INTO security_flow_stats (scan_id, mac, ip, label, label_kind, bytes_down, bytes_up, connections)
			 SELECT $1, m, i, l, k, d, u, c
			   FROM unnest($2::text[], $3::text[], $4::text[], $5::text[], $6::bigint[], $7::bigint[], $8::int[]) AS t(m, i, l, k, d, u, c)`,
			id, macs, ips, labels, kinds, down, up, conns); err != nil {
			return id, err
		}
	}
	if len(findings) > 0 {
		macs, ips, sev, codes, titles, details := make([]string, len(findings)), make([]string, len(findings)), make([]string, len(findings)),
			make([]string, len(findings)), make([]string, len(findings)), make([]string, len(findings))
		for i, f := range findings {
			macs[i], ips[i], sev[i], codes[i], titles[i], details[i] = f.MAC, f.IP, f.Severity, f.Code, f.Title, f.Detail
		}
		if _, err := r.db.Exec(ctx,
			`INSERT INTO security_findings (scan_id, mac, ip, severity, code, title, detail)
			 SELECT $1, m, i, s, c, t, d FROM unnest($2::text[], $3::text[], $4::text[], $5::text[], $6::text[], $7::text[]) AS x(m, i, s, c, t, d)`,
			id, macs, ips, sev, codes, titles, details); err != nil {
			return id, err
		}
	}
	return id, nil
}

// LastScan returns the newest scan summary, or nil when none was taken.
func (r *SecurityRepository) LastScan(ctx context.Context, orgID uuid.UUID) (*ScanRecord, error) {
	rows, err := r.db.Query(ctx,
		`SELECT id, taken_at, connections, devices, duration_ms, router_cpu_before, router_cpu_after
		   FROM security_scans WHERE organization_id = $1 ORDER BY taken_at DESC LIMIT 1`, orgID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	if !rows.Next() {
		return nil, rows.Err()
	}
	var s ScanRecord
	if err := rows.Scan(&s.ID, &s.TakenAt, &s.Connections, &s.Devices, &s.DurationMs, &s.RouterCPUBefore, &s.RouterCPUAfter); err != nil {
		return nil, err
	}
	return &s, nil
}

// ScanFlows returns the stored destination rows of a scan.
func (r *SecurityRepository) ScanFlows(ctx context.Context, scanID int64) ([]FlowRow, error) {
	rows, err := r.db.Query(ctx,
		`SELECT mac, ip, label, label_kind, bytes_down, bytes_up, connections FROM security_flow_stats WHERE scan_id = $1`, scanID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var out []FlowRow
	for rows.Next() {
		var f FlowRow
		if err := rows.Scan(&f.MAC, &f.IP, &f.Label, &f.Kind, &f.Down, &f.Up, &f.Connections); err != nil {
			return nil, err
		}
		out = append(out, f)
	}
	return out, rows.Err()
}

// ScanFindings returns the stored findings of a scan.
func (r *SecurityRepository) ScanFindings(ctx context.Context, scanID int64) ([]FindingRow, error) {
	rows, err := r.db.Query(ctx,
		`SELECT mac, ip, severity, code, title, detail FROM security_findings WHERE scan_id = $1`, scanID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var out []FindingRow
	for rows.Next() {
		var f FindingRow
		if err := rows.Scan(&f.MAC, &f.IP, &f.Severity, &f.Code, &f.Title, &f.Detail); err != nil {
			return nil, err
		}
		out = append(out, f)
	}
	return out, rows.Err()
}

// Popular ranks destinations since the given time by how many devices used
// them, then by how many scans they showed up in.
func (r *SecurityRepository) Popular(ctx context.Context, orgID uuid.UUID, since time.Time, limit int) ([]PopularLabel, error) {
	return r.popular(ctx, orgID, "", since, limit)
}

// DeviceLabels ranks the destinations one device used since the given time.
func (r *SecurityRepository) DeviceLabels(ctx context.Context, orgID uuid.UUID, mac string, since time.Time, limit int) ([]PopularLabel, error) {
	return r.popular(ctx, orgID, mac, since, limit)
}

func (r *SecurityRepository) popular(ctx context.Context, orgID uuid.UUID, mac string, since time.Time, limit int) ([]PopularLabel, error) {
	rows, err := r.db.Query(ctx,
		`SELECT f.label, f.label_kind, COUNT(DISTINCT NULLIF(f.mac, '')), COUNT(DISTINCT f.scan_id),
		        COALESCE(SUM(f.connections), 0), COALESCE(SUM(f.bytes_down + f.bytes_up), 0)
		   FROM security_flow_stats f JOIN security_scans s ON s.id = f.scan_id
		  WHERE s.organization_id = $1 AND s.taken_at >= $2 AND ($3 = '' OR f.mac = $3)
		    AND f.label_kind <> 'internal'
		  GROUP BY f.label, f.label_kind
		  ORDER BY 3 DESC, 4 DESC, 6 DESC LIMIT $4`, orgID, since, mac, limit)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	out := []PopularLabel{}
	for rows.Next() {
		var p PopularLabel
		if err := rows.Scan(&p.Label, &p.Kind, &p.Devices, &p.Scans, &p.Connections, &p.Bytes); err != nil {
			return nil, err
		}
		out = append(out, p)
	}
	return out, rows.Err()
}

// Prune deletes scans (and their rows) older than the retention window.
func (r *SecurityRepository) Prune(ctx context.Context, before time.Time) error {
	_, err := r.db.Exec(ctx, `DELETE FROM security_scans WHERE taken_at < $1`, before)
	return err
}

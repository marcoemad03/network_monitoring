package main

import (
	"context"
	"fmt"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/google/uuid"
)

func main() {
	dsn := "postgres://nms_admin:changeme@localhost:5432/hospital_nms?sslmode=disable"
	pool, err := pgxpool.New(context.Background(), dsn)
	if err != nil {
		fmt.Printf("pool error: %v\n", err)
		return
	}
	defer pool.Close()

	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	// Test scan query
	id := uuid.MustParse("f89bedb5-4449-47b3-8f16-b47750e2b935")
	query := `SELECT id, organization_id, type, status, name, target_subnet, initiated_by, total_hosts, discovered_hosts, active_hosts, duration_seconds, progress, error_message, started_at, completed_at, created_at FROM network_scans WHERE id = $1`
	row := pool.QueryRow(ctx, query, id)

	var (
		scanID, orgID uuid.UUID
		scanType, status string
		name *string
		targetSubnet string
		initiatedBy *uuid.UUID
		totalHosts, discoveredHosts, activeHosts int
		durationSeconds *int
		progress *float64
		errMsg *string
		startedAt, createdAt time.Time
		completedAt *time.Time
	)

	if err := row.Scan(
		&scanID, &orgID, &scanType, &status, &name,
		&targetSubnet, &initiatedBy, &totalHosts, &discoveredHosts,
		&activeHosts, &durationSeconds, &progress, &errMsg,
		&startedAt, &completedAt, &createdAt,
	); err != nil {
		fmt.Printf("SCAN QUERY ERROR: %v\n", err)
	} else {
		fmt.Printf("SCAN OK: id=%s status=%s discovered=%d\n", scanID, status, discoveredHosts)
	}

	// Test devices query
	devQuery := `SELECT COUNT(*) FROM devices WHERE organization_id = $1`
	var count int
	if err := pool.QueryRow(ctx, devQuery, orgID).Scan(&count); err != nil {
		fmt.Printf("DEV COUNT ERROR: %v\n", err)
	} else {
		fmt.Printf("DEVICES COUNT: %d\n", count)
	}

	fmt.Println("DONE")
}

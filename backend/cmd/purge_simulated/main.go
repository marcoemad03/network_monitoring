// Command purge_simulated removes the random demo readings that the monitor used
// to store for every device (CPU, memory, traffic and speed tests).
//
// Those tables were only ever filled by the simulator, so everything in them is
// made up. Real data is not touched: ping results, devices, alerts, groups and
// the router's own usage measurements live in other tables.
//
// It reports what it would delete and deletes nothing unless -confirm is given:
//
//	go run ./cmd/purge_simulated            # dry run: counts only
//	go run ./cmd/purge_simulated -confirm   # delete
package main

import (
	"context"
	"flag"
	"fmt"
	"os"
	"time"

	"github.com/hospital/nms-backend/internal/config"
	"github.com/hospital/nms-backend/internal/database"
	"github.com/hospital/nms-backend/pkg/logger"
)

var tables = []struct{ name, description string }{
	{"device_metrics", "CPU, memory, disk and temperature readings"},
	{"device_traffic", "per-device traffic readings"},
	{"device_speed_tests", "speed test results"},
}

func main() {
	confirm := flag.Bool("confirm", false, "delete the rows (without it only counts are shown)")
	beforeFlag := flag.String("before", "", "only rows older than this time (RFC3339); default: now")
	flag.Parse()

	cfg, err := config.Load(0)
	if err != nil {
		fmt.Println("config:", err)
		os.Exit(1)
	}
	logger.Init("error", "json")

	if cfg.MonitorSimulateMetrics {
		fmt.Println("MONITOR_SIMULATE_METRICS is on: the monitor would refill these tables right away. Turn it off first.")
		os.Exit(1)
	}

	before := time.Now()
	if *beforeFlag != "" {
		before, err = time.Parse(time.RFC3339, *beforeFlag)
		if err != nil {
			fmt.Println("-before must look like 2026-11-01T12:00:00+02:00")
			os.Exit(2)
		}
	}

	ctx := context.Background()
	db, err := database.NewPostgresDB(cfg)
	if err != nil {
		fmt.Println("database:", err)
		os.Exit(1)
	}
	defer db.Close()

	fmt.Printf("Database %s on %s:%d, rows older than %s\n\n", cfg.DBName, cfg.DBHost, cfg.DBPort, before.Format(time.RFC3339))
	var total int64
	for _, t := range tables {
		var n int64
		var oldest, newest *time.Time
		query := fmt.Sprintf(`SELECT COUNT(*), MIN(timestamp), MAX(timestamp) FROM %s WHERE timestamp < $1`, t.name)
		if err := db.QueryRow(ctx, query, before).Scan(&n, &oldest, &newest); err != nil {
			fmt.Printf("  %-20s could not be read: %v\n", t.name, err)
			os.Exit(1)
		}
		span := ""
		if oldest != nil && newest != nil {
			span = fmt.Sprintf("  (%s to %s)", oldest.Format("2006-01-02"), newest.Format("2006-01-02"))
		}
		fmt.Printf("  %-20s %10d rows  %s%s\n", t.name, n, t.description, span)
		total += n
	}
	fmt.Printf("\n  total: %d rows\n\n", total)

	if !*confirm {
		fmt.Println("Nothing was deleted. Run again with -confirm to delete these rows.")
		return
	}

	for _, t := range tables {
		var removed int64
		stmt := fmt.Sprintf(`DELETE FROM %[1]s WHERE ctid IN (SELECT ctid FROM %[1]s WHERE timestamp < $1 LIMIT 50000)`, t.name)
		for {
			tag, err := db.Exec(ctx, stmt, before)
			if err != nil {
				fmt.Printf("  %-20s stopped after %d rows: %v\n", t.name, removed, err)
				os.Exit(1)
			}
			if tag.RowsAffected() == 0 {
				break
			}
			removed += tag.RowsAffected()
		}
		fmt.Printf("  %-20s deleted %d rows\n", t.name, removed)
	}
	fmt.Println("\nDone.")
}

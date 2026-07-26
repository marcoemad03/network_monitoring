package database

import (
	"context"
	"fmt"
	"os"
	"path/filepath"
	"sort"
	"strings"

	"github.com/hospital/nms-backend/pkg/logger"
)

func (db *DB) RunMigrations(ctx context.Context, migrationsDir string) error {
	entries, err := os.ReadDir(migrationsDir)
	if err != nil {
		return fmt.Errorf("read migrations dir: %w", err)
	}

	var sqlFiles []string
	for _, e := range entries {
		if !e.IsDir() && strings.HasSuffix(e.Name(), ".sql") {
			sqlFiles = append(sqlFiles, e.Name())
		}
	}
	sort.Strings(sqlFiles)

	appliedTable := `CREATE TABLE IF NOT EXISTS schema_migrations (
		version VARCHAR(100) PRIMARY KEY,
		applied_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
	)`
	if _, err := db.Exec(ctx, appliedTable); err != nil {
		return fmt.Errorf("create migrations table: %w", err)
	}

	for _, f := range sqlFiles {
		var count int
		db.QueryRow(ctx, "SELECT COUNT(*) FROM schema_migrations WHERE version = $1", f).Scan(&count)
		if count > 0 {
			continue
		}

		content, err := os.ReadFile(filepath.Join(migrationsDir, f))
		if err != nil {
			return fmt.Errorf("read migration %s: %w", f, err)
		}

		statements := strings.Split(string(content), ";")
		for _, stmt := range statements {
			stmt = strings.TrimSpace(stmt)
			if stmt == "" {
				continue
			}
			if _, err := db.Exec(ctx, stmt); err != nil {
				logger.Warn("Migration statement failed (may be OK if column already exists)",
					"file", f,
					"error", err,
					"statement", stmt[:min(len(stmt), 200)],
				)
			}
		}

		if _, err := db.Exec(ctx, "INSERT INTO schema_migrations (version) VALUES ($1)", f); err != nil {
			return fmt.Errorf("record migration %s: %w", f, err)
		}

		logger.Info("Applied migration", "file", f)
	}

	return nil
}

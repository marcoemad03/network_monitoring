package database

import (
	"context"
	"fmt"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/hospital/nms-backend/internal/config"
	"github.com/hospital/nms-backend/pkg/logger"
)

type DB struct {
	Pool *pgxpool.Pool
}

func NewPostgresDB(cfg *config.Config) (*DB, error) {
	dsn := fmt.Sprintf(
		"postgres://%s:%s@%s:%d/%s?sslmode=%s&pool_max_conns=%d&pool_max_conn_lifetime=%s",
		cfg.DBUser,
		cfg.DBPassword,
		cfg.DBHost,
		cfg.DBPort,
		cfg.DBName,
		cfg.DBSSLMode,
		cfg.DBMaxConns,
		cfg.DBMaxLifetime.String(),
	)

	poolCfg, err := pgxpool.ParseConfig(dsn)
	if err != nil {
		return nil, fmt.Errorf("failed to parse database config: %w", err)
	}

	poolCfg.MaxConns = int32(cfg.DBMaxConns)
	poolCfg.MinConns = int32(cfg.DBMaxIdle)
	poolCfg.MaxConnLifetime = cfg.DBMaxLifetime
	poolCfg.HealthCheckPeriod = 30 * time.Second

	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()

	pool, err := pgxpool.NewWithConfig(ctx, poolCfg)
	if err != nil {
		return nil, fmt.Errorf("failed to create connection pool: %w", err)
	}

	if err := pool.Ping(ctx); err != nil {
		return nil, fmt.Errorf("failed to ping database: %w", err)
	}

	logger.Info("Connected to PostgreSQL database",
		"host", cfg.DBHost,
		"port", cfg.DBPort,
		"database", cfg.DBName,
		"max_conns", cfg.DBMaxConns,
	)

	return &DB{Pool: pool}, nil
}

func (db *DB) Close() {
	db.Pool.Close()
	logger.Info("Database connection closed")
}

func (db *DB) Exec(ctx context.Context, sql string, args ...interface{}) error {
	_, err := db.Pool.Exec(ctx, sql, args...)
	return err
}

func (db *DB) Query(ctx context.Context, sql string, args ...interface{}) (pgxpool.Rows, error) {
	return db.Pool.Query(ctx, sql, args...)
}

func (db *DB) QueryRow(ctx context.Context, sql string, args ...interface{}) pgxpool.Row {
	return db.Pool.QueryRow(ctx, sql, args...)
}

package repository

import (
	"context"
	"fmt"
	"time"

	"github.com/google/uuid"
	"github.com/hospital/nms-backend/internal/database"
	"github.com/hospital/nms-backend/internal/models"
)

type SessionRepository struct {
	db *database.DB
}

func NewSessionRepository(db *database.DB) *SessionRepository {
	return &SessionRepository{db: db}
}

func (r *SessionRepository) Create(ctx context.Context, session *models.UserSession) error {
	session.ID = uuid.New()
	session.CreatedAt = time.Now()
	session.LastActivity = time.Now()
	_, err := r.db.Exec(ctx,
		`INSERT INTO user_sessions (id, user_id, token_hash, refresh_token_hash, ip_address, user_agent, last_activity, expires_at, is_revoked, created_at) VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10)`,
		session.ID, session.UserID, session.TokenHash, session.RefreshTokenHash,
		session.IPAddress, session.UserAgent, session.LastActivity, session.ExpiresAt,
		session.IsRevoked, session.CreatedAt,
	)
	return err
}

func (r *SessionRepository) GetByTokenHash(ctx context.Context, hash string) (*models.UserSession, error) {
	row := r.db.QueryRow(ctx, `SELECT * FROM user_sessions WHERE token_hash = $1 AND is_revoked = false`, hash)
	return r.scanSession(row)
}

func (r *SessionRepository) GetByRefreshTokenHash(ctx context.Context, hash string) (*models.UserSession, error) {
	row := r.db.QueryRow(ctx, `SELECT * FROM user_sessions WHERE refresh_token_hash = $1 AND is_revoked = false`, hash)
	return r.scanSession(row)
}

func (r *SessionRepository) ListByUser(ctx context.Context, userID uuid.UUID) ([]models.UserSession, error) {
	rows, err := r.db.Query(ctx,
		`SELECT * FROM user_sessions WHERE user_id = $1 AND is_revoked = false ORDER BY created_at DESC`,
		userID,
	)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var sessions []models.UserSession
	for rows.Next() {
		var s models.UserSession
		if err := r.scanSessionRows(rows, &s); err != nil {
			return nil, err
		}
		sessions = append(sessions, s)
	}
	return sessions, nil
}

func (r *SessionRepository) Revoke(ctx context.Context, sessionID uuid.UUID) error {
	_, err := r.db.Exec(ctx, `UPDATE user_sessions SET is_revoked = true WHERE id = $1`, sessionID)
	return err
}

func (r *SessionRepository) RevokeAllByUser(ctx context.Context, userID uuid.UUID) error {
	_, err := r.db.Exec(ctx, `UPDATE user_sessions SET is_revoked = true WHERE user_id = $1`, userID)
	return err
}

func (r *SessionRepository) UpdateActivity(ctx context.Context, sessionID uuid.UUID) error {
	_, err := r.db.Exec(ctx, `UPDATE user_sessions SET last_activity = $1 WHERE id = $2`, time.Now(), sessionID)
	return err
}

func (r *SessionRepository) CleanupExpired(ctx context.Context) error {
	_, err := r.db.Exec(ctx, `DELETE FROM user_sessions WHERE expires_at < $1`, time.Now())
	return err
}

func (r *SessionRepository) scanSession(row interface{ Scan(dest ...interface{}) error }) (*models.UserSession, error) {
	var s models.UserSession
	err := row.Scan(&s.ID, &s.UserID, &s.TokenHash, &s.RefreshTokenHash, &s.IPAddress, &s.UserAgent, &s.LastActivity, &s.ExpiresAt, &s.IsRevoked, &s.CreatedAt)
	if err != nil {
		return nil, fmt.Errorf("scan session: %w", err)
	}
	return &s, nil
}

func (r *SessionRepository) scanSessionRows(rows interface{ Scan(dest ...interface{}) error }, s *models.UserSession) error {
	return rows.Scan(&s.ID, &s.UserID, &s.TokenHash, &s.RefreshTokenHash, &s.IPAddress, &s.UserAgent, &s.LastActivity, &s.ExpiresAt, &s.IsRevoked, &s.CreatedAt)
}

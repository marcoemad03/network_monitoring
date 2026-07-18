package repository

import (
	"context"
	"crypto/sha256"
	"encoding/hex"
	"fmt"
	"time"

	"github.com/google/uuid"
	"github.com/hospital/nms-backend/internal/database"
	"github.com/hospital/nms-backend/internal/models"
)

type UserRepository struct {
	db *database.DB
}

func NewUserRepository(db *database.DB) *UserRepository {
	return &UserRepository{db: db}
}

func (r *UserRepository) GetByUsername(ctx context.Context, username string) (*models.User, error) {
	query := `SELECT * FROM users WHERE username = $1`
	row := r.db.QueryRow(ctx, query, username)
	return r.scanUser(row)
}

func (r *UserRepository) GetByEmail(ctx context.Context, email string) (*models.User, error) {
	query := `SELECT * FROM users WHERE email = $1`
	row := r.db.QueryRow(ctx, query, email)
	return r.scanUser(row)
}

func (r *UserRepository) GetByID(ctx context.Context, id uuid.UUID) (*models.User, error) {
	query := `SELECT * FROM users WHERE id = $1`
	row := r.db.QueryRow(ctx, query, id)
	return r.scanUser(row)
}

func (r *UserRepository) UpdateLastLogin(ctx context.Context, id uuid.UUID, ip string) error {
	now := time.Now()
	_, err := r.db.Exec(ctx,
		`UPDATE users SET last_login_at=$1, last_login_ip=$2, failed_login_attempts=0 WHERE id=$3`,
		now, ip, id,
	)
	return err
}

func (r *UserRepository) IncrementFailedAttempts(ctx context.Context, id uuid.UUID) error {
	_, err := r.db.Exec(ctx,
		`UPDATE users SET failed_login_attempts = failed_login_attempts + 1 WHERE id = $1`, id,
	)
	return err
}

func (r *UserRepository) LockAccount(ctx context.Context, id uuid.UUID, duration time.Duration) error {
	until := time.Now().Add(duration)
	_, err := r.db.Exec(ctx,
		`UPDATE users SET is_locked=true, locked_until=$1 WHERE id=$2`, until, id,
	)
	return err
}

func (r *UserRepository) List(ctx context.Context, orgID uuid.UUID, page, limit int, search string) ([]models.User, int, error) {
	offset := (page - 1) * limit
	query := `SELECT * FROM users WHERE organization_id = $1`
	countQuery := `SELECT COUNT(*) FROM users WHERE organization_id = $1`
	args := []interface{}{orgID}
	argIdx := 2

	if search != "" {
		query += fmt.Sprintf(` AND (username ILIKE $%d OR email ILIKE $%d OR display_name ILIKE $%d)`, argIdx, argIdx, argIdx)
		countQuery += fmt.Sprintf(` AND (username ILIKE $%d OR email ILIKE $%d OR display_name ILIKE $%d)`, argIdx, argIdx, argIdx)
		args = append(args, "%"+search+"%")
		argIdx++
	}

	query += fmt.Sprintf(` ORDER BY created_at DESC LIMIT $%d OFFSET $%d`, argIdx, argIdx+1)
	args = append(args, limit, offset)

	rows, err := r.db.Query(ctx, query, args...)
	if err != nil {
		return nil, 0, err
	}
	defer rows.Close()

	var users []models.User
	for rows.Next() {
		var u models.User
		if err := scanUserRows(rows, &u); err != nil {
			return nil, 0, err
		}
		users = append(users, u)
	}

	var total int
	r.db.QueryRow(ctx, countQuery, args[:len(args)-2]...).Scan(&total)

	return users, total, nil
}

func (r *UserRepository) Create(ctx context.Context, user *models.User) error {
	user.ID = uuid.New()
	user.CreatedAt = time.Now()
	user.UpdatedAt = time.Now()
	return r.db.Exec(ctx,
		`INSERT INTO users (id, organization_id, username, email, password_hash, display_name, first_name, last_name, role, department, title, phone, is_active, is_locked, created_at, updated_at) VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14,$15,$16)`,
		user.ID, user.OrganizationID, user.Username, user.Email, user.PasswordHash,
		user.DisplayName, user.FirstName, user.LastName, user.Role, user.Department,
		user.Title, user.Phone, user.IsActive, user.IsLocked, user.CreatedAt, user.UpdatedAt,
	)
}

func (r *UserRepository) Update(ctx context.Context, user *models.User) error {
	user.UpdatedAt = time.Now()
	return r.db.Exec(ctx,
		`UPDATE users SET username=$1, email=$2, display_name=$3, first_name=$4, last_name=$5, role=$6, department=$7, title=$8, phone=$9, is_active=$10, updated_at=$11 WHERE id=$12`,
		user.Username, user.Email, user.DisplayName, user.FirstName, user.LastName,
		user.Role, user.Department, user.Title, user.Phone, user.IsActive, user.UpdatedAt, user.ID,
	)
}

func (r *UserRepository) Delete(ctx context.Context, id uuid.UUID) error {
	return r.db.Exec(ctx, `DELETE FROM users WHERE id = $1`, id)
}

func (r *UserRepository) UpdatePassword(ctx context.Context, id uuid.UUID, hash string) error {
	now := time.Now()
	return r.db.Exec(ctx,
		`UPDATE users SET password_hash=$1, password_changed_at=$2, updated_at=$3 WHERE id=$4`,
		hash, now, now, id,
	)
}

func (r *UserRepository) SetPasswordResetToken(ctx context.Context, id uuid.UUID, token string, expiresAt time.Time) error {
	tokenHash := hashToken(token)
	return r.db.Exec(ctx,
		`UPDATE users SET password_reset_token=$1, password_reset_expires_at=$2 WHERE id=$3`,
		tokenHash, expiresAt, id,
	)
}

func (r *UserRepository) GetByPasswordResetToken(ctx context.Context, token string) (*models.User, error) {
	tokenHash := hashToken(token)
	row := r.db.QueryRow(ctx,
		`SELECT * FROM users WHERE password_reset_token = $1 AND password_reset_expires_at > NOW()`,
		tokenHash,
	)
	return r.scanUser(row)
}

func hashToken(token string) string {
	hash := sha256.Sum256([]byte(token))
	return hex.EncodeToString(hash[:])
}

func (r *UserRepository) ClearPasswordResetToken(ctx context.Context, id uuid.UUID) error {
	return r.db.Exec(ctx,
		`UPDATE users SET password_reset_token=NULL, password_reset_expires_at=NULL WHERE id=$1`,
		id,
	)
}

func (r *UserRepository) GetUserPermissions(ctx context.Context, userID uuid.UUID) ([]string, error) {
	rows, err := r.db.Query(ctx,
		`SELECT p.slug FROM permissions p
		 INNER JOIN role_permissions rp ON p.id = rp.permission_id
		 INNER JOIN roles r ON r.id = rp.role_id
		 INNER JOIN users u ON u.role = r.slug
		 WHERE u.id = $1`,
		userID,
	)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var slugs []string
	for rows.Next() {
		var slug string
		if err := rows.Scan(&slug); err != nil {
			return nil, err
		}
		slugs = append(slugs, slug)
	}
	return slugs, nil
}

func (r *UserRepository) scanUser(row interface{ Scan(dest ...interface{}) error }) (*models.User, error) {
	var u models.User
	err := row.Scan(
		&u.ID, &u.OrganizationID, &u.Username, &u.Email, &u.PasswordHash,
		&u.DisplayName, &u.FirstName, &u.LastName, &u.Role, &u.Department,
		&u.Title, &u.Phone, &u.AvatarURL, &u.IsActive, &u.IsLocked, &u.IsMfaEnabled,
		&u.MFASecret, &u.FailedLoginAttempts, &u.LockedUntil, &u.LastLoginAt,
		&u.LastLoginIP, &u.PasswordChangedAt, &u.PasswordResetToken,
		&u.PasswordResetExpiresAt, &u.PasswordHistory, &u.CreatedAt, &u.UpdatedAt,
	)
	if err != nil {
		return nil, fmt.Errorf("scan user: %w", err)
	}
	return &u, nil
}

func scanUserRows(row interface{ Scan(dest ...interface{}) error }, u *models.User) error {
	return row.Scan(
		&u.ID, &u.OrganizationID, &u.Username, &u.Email, &u.PasswordHash,
		&u.DisplayName, &u.FirstName, &u.LastName, &u.Role, &u.Department,
		&u.Title, &u.Phone, &u.AvatarURL, &u.IsActive, &u.IsLocked, &u.IsMfaEnabled,
		&u.MFASecret, &u.FailedLoginAttempts, &u.LockedUntil, &u.LastLoginAt,
		&u.LastLoginIP, &u.PasswordChangedAt, &u.PasswordResetToken,
		&u.PasswordResetExpiresAt, &u.PasswordHistory, &u.CreatedAt, &u.UpdatedAt,
	)
}

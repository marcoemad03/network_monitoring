package repository

import (
	"context"
	"fmt"
	"time"

	"github.com/google/uuid"
	"github.com/hospital/nms-backend/internal/database"
	"github.com/hospital/nms-backend/internal/models"
)

type PermissionRepository struct {
	db *database.DB
}

func NewPermissionRepository(db *database.DB) *PermissionRepository {
	return &PermissionRepository{db: db}
}

func (r *PermissionRepository) GetRoleByID(ctx context.Context, id uuid.UUID) (*models.Role, error) {
	row := r.db.QueryRow(ctx, `SELECT * FROM roles WHERE id = $1`, id)
	var role models.Role
	err := row.Scan(&role.ID, &role.Name, &role.Slug, &role.Description, &role.PermissionLevel, &role.IsSystemRole, &role.CreatedAt, &role.UpdatedAt)
	if err != nil {
		return nil, fmt.Errorf("scan role: %w", err)
	}
	return &role, nil
}

func (r *PermissionRepository) GetRoleBySlug(ctx context.Context, slug string) (*models.Role, error) {
	row := r.db.QueryRow(ctx, `SELECT * FROM roles WHERE slug = $1`, slug)
	var role models.Role
	err := row.Scan(&role.ID, &role.Name, &role.Slug, &role.Description, &role.PermissionLevel, &role.IsSystemRole, &role.CreatedAt, &role.UpdatedAt)
	if err != nil {
		return nil, fmt.Errorf("scan role: %w", err)
	}
	return &role, nil
}

func (r *PermissionRepository) ListRoles(ctx context.Context) ([]models.Role, error) {
	rows, err := r.db.Query(ctx, `SELECT * FROM roles ORDER BY permission_level DESC`)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var roles []models.Role
	for rows.Next() {
		var role models.Role
		if err := rows.Scan(&role.ID, &role.Name, &role.Slug, &role.Description, &role.PermissionLevel, &role.IsSystemRole, &role.CreatedAt, &role.UpdatedAt); err != nil {
			return nil, err
		}
		roles = append(roles, role)
	}
	return roles, nil
}

func (r *PermissionRepository) CreateRole(ctx context.Context, role *models.Role) error {
	role.ID = uuid.New()
	role.CreatedAt = time.Now()
	role.UpdatedAt = time.Now()
	return r.db.Exec(ctx,
		`INSERT INTO roles (id, name, slug, description, permission_level, is_system_role, created_at, updated_at) VALUES ($1,$2,$3,$4,$5,$6,$7,$8)`,
		role.ID, role.Name, role.Slug, role.Description, role.PermissionLevel, role.IsSystemRole, role.CreatedAt, role.UpdatedAt,
	)
}

func (r *PermissionRepository) UpdateRole(ctx context.Context, role *models.Role) error {
	role.UpdatedAt = time.Now()
	return r.db.Exec(ctx,
		`UPDATE roles SET name=$1, description=$2, permission_level=$3, updated_at=$4 WHERE id=$5`,
		role.Name, role.Description, role.PermissionLevel, role.UpdatedAt, role.ID,
	)
}

func (r *PermissionRepository) DeleteRole(ctx context.Context, id uuid.UUID) error {
	return r.db.Exec(ctx, `DELETE FROM roles WHERE id = $1 AND is_system_role = false`, id)
}

func (r *PermissionRepository) ListPermissions(ctx context.Context) ([]models.Permission, error) {
	rows, err := r.db.Query(ctx, `SELECT * FROM permissions ORDER BY module, name`)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var perms []models.Permission
	for rows.Next() {
		var p models.Permission
		if err := rows.Scan(&p.ID, &p.Name, &p.Slug, &p.Description, &p.Module, &p.CreatedAt); err != nil {
			return nil, err
		}
		perms = append(perms, p)
	}
	return perms, nil
}

func (r *PermissionRepository) GetRolePermissions(ctx context.Context, roleID uuid.UUID) ([]models.Permission, error) {
	rows, err := r.db.Query(ctx,
		`SELECT p.* FROM permissions p INNER JOIN role_permissions rp ON p.id = rp.permission_id WHERE rp.role_id = $1 ORDER BY p.module, p.name`,
		roleID,
	)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var perms []models.Permission
	for rows.Next() {
		var p models.Permission
		if err := rows.Scan(&p.ID, &p.Name, &p.Slug, &p.Description, &p.Module, &p.CreatedAt); err != nil {
			return nil, err
		}
		perms = append(perms, p)
	}
	return perms, nil
}

func (r *PermissionRepository) AssignPermissionToRole(ctx context.Context, roleID, permID uuid.UUID) error {
	return r.db.Exec(ctx,
		`INSERT INTO role_permissions (role_id, permission_id) VALUES ($1, $2) ON CONFLICT DO NOTHING`,
		roleID, permID,
	)
}

func (r *PermissionRepository) RemovePermissionFromRole(ctx context.Context, roleID, permID uuid.UUID) error {
	return r.db.Exec(ctx,
		`DELETE FROM role_permissions WHERE role_id = $1 AND permission_id = $2`,
		roleID, permID,
	)
}

func (r *PermissionRepository) UserHasPermission(ctx context.Context, userID uuid.UUID, permissionSlug string) (bool, error) {
	var exists bool
	err := r.db.QueryRow(ctx,
		`SELECT EXISTS(
			SELECT 1 FROM users u
			INNER JOIN roles r ON u.role = r.slug
			INNER JOIN role_permissions rp ON r.id = rp.role_id
			INNER JOIN permissions p ON p.id = rp.permission_id
			WHERE u.id = $1 AND p.slug = $2
		)`, userID, permissionSlug,
	).Scan(&exists)
	return exists, err
}

func (r *PermissionRepository) ListPermissionsByModule(ctx context.Context) (map[string][]models.Permission, error) {
	perms, err := r.ListPermissions(ctx)
	if err != nil {
		return nil, err
	}
	result := make(map[string][]models.Permission)
	for _, p := range perms {
		result[p.Module] = append(result[p.Module], p)
	}
	return result, nil
}

func (r *PermissionRepository) GetRoleWithPermissions(ctx context.Context, roleID uuid.UUID) (*models.Role, []models.Permission, error) {
	role, err := r.GetRoleByID(ctx, roleID)
	if err != nil {
		return nil, nil, err
	}
	perms, err := r.GetRolePermissions(ctx, roleID)
	if err != nil {
		return nil, nil, err
	}
	return role, perms, nil
}

package services

import (
	"context"
	"errors"
	"fmt"

	"github.com/google/uuid"
	"github.com/hospital/nms-backend/internal/models"
	"github.com/hospital/nms-backend/internal/repository"
)

var (
	ErrRoleNotFound      = errors.New("role not found")
	ErrPermissionDenied  = errors.New("permission denied")
	ErrCannotModifySystemRole = errors.New("cannot modify system role")
)

type PermissionService struct {
	permRepo *repository.PermissionRepository
	userRepo *repository.UserRepository
}

func NewPermissionService(permRepo *repository.PermissionRepository, userRepo *repository.UserRepository) *PermissionService {
	return &PermissionService{permRepo: permRepo, userRepo: userRepo}
}

func (s *PermissionService) ListRoles(ctx context.Context) ([]models.Role, error) {
	return s.permRepo.ListRoles(ctx)
}

func (s *PermissionService) GetRole(ctx context.Context, id uuid.UUID) (*models.Role, []models.Permission, error) {
	role, err := s.permRepo.GetRoleByID(ctx, id)
	if err != nil {
		return nil, nil, ErrRoleNotFound
	}
	perms, err := s.permRepo.GetRolePermissions(ctx, id)
	if err != nil {
		return nil, nil, err
	}
	return role, perms, nil
}

func (s *PermissionService) CreateRole(ctx context.Context, role *models.Role) error {
	role.IsSystemRole = false
	return s.permRepo.CreateRole(ctx, role)
}

func (s *PermissionService) UpdateRole(ctx context.Context, role *models.Role) error {
	existing, err := s.permRepo.GetRoleByID(ctx, role.ID)
	if err != nil {
		return ErrRoleNotFound
	}
	if existing.IsSystemRole {
		return ErrCannotModifySystemRole
	}
	return s.permRepo.UpdateRole(ctx, role)
}

func (s *PermissionService) DeleteRole(ctx context.Context, id uuid.UUID) error {
	existing, err := s.permRepo.GetRoleByID(ctx, id)
	if err != nil {
		return ErrRoleNotFound
	}
	if existing.IsSystemRole {
		return ErrCannotModifySystemRole
	}
	return s.permRepo.DeleteRole(ctx, id)
}

func (s *PermissionService) ListPermissions(ctx context.Context) ([]models.Permission, error) {
	return s.permRepo.ListPermissions(ctx)
}

func (s *PermissionService) GetRolePermissions(ctx context.Context, roleID uuid.UUID) ([]models.Permission, error) {
	return s.permRepo.GetRolePermissions(ctx, roleID)
}

func (s *PermissionService) AssignPermission(ctx context.Context, roleID, permID uuid.UUID) error {
	if _, err := s.permRepo.GetRoleByID(ctx, roleID); err != nil {
		return ErrRoleNotFound
	}
	return s.permRepo.AssignPermissionToRole(ctx, roleID, permID)
}

func (s *PermissionService) RemovePermission(ctx context.Context, roleID, permID uuid.UUID) error {
	existing, err := s.permRepo.GetRoleByID(ctx, roleID)
	if err != nil {
		return ErrRoleNotFound
	}
	if existing.IsSystemRole {
		return ErrCannotModifySystemRole
	}
	return s.permRepo.RemovePermissionFromRole(ctx, roleID, permID)
}

func (s *PermissionService) GetUserPermissions(ctx context.Context, userID uuid.UUID) ([]string, error) {
	return s.userRepo.GetUserPermissions(ctx, userID)
}

func (s *PermissionService) CheckPermission(ctx context.Context, userID uuid.UUID, permissionSlug string) (bool, error) {
	return s.permRepo.UserHasPermission(ctx, userID, permissionSlug)
}

type RoleWithPermissions struct {
	Role        models.Role         `json:"role"`
	Permissions []models.Permission `json:"permissions"`
}

func (s *PermissionService) GetAllRolesWithPermissions(ctx context.Context) ([]RoleWithPermissions, error) {
	roles, err := s.permRepo.ListRoles(ctx)
	if err != nil {
		return nil, err
	}

	var result []RoleWithPermissions
	for _, role := range roles {
		perms, err := s.permRepo.GetRolePermissions(ctx, role.ID)
		if err != nil {
			return nil, fmt.Errorf("get permissions for role %s: %w", role.Slug, err)
		}
		result = append(result, RoleWithPermissions{Role: role, Permissions: perms})
	}
	return result, nil
}

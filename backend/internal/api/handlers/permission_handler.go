package handlers

import (
	"net/http"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
	"github.com/hospital/nms-backend/internal/models"
	"github.com/hospital/nms-backend/internal/services"
	"github.com/hospital/nms-backend/pkg/utils"
)

type PermissionHandler struct {
	permService *services.PermissionService
}

func NewPermissionHandler(permService *services.PermissionService) *PermissionHandler {
	return &PermissionHandler{permService: permService}
}

func (h *PermissionHandler) ListRoles(c *gin.Context) {
	roles, err := h.permService.ListRoles(c.Request.Context())
	if err != nil {
		utils.Error(c, http.StatusInternalServerError, "Failed to list roles", "DB_ERROR", nil)
		return
	}
	utils.Success(c, http.StatusOK, roles, "Roles retrieved")
}

func (h *PermissionHandler) GetRole(c *gin.Context) {
	id, err := uuid.Parse(c.Param("id"))
	if err != nil {
		utils.Error(c, http.StatusBadRequest, "Invalid role ID", "VALIDATION_ERROR", nil)
		return
	}

	role, perms, err := h.permService.GetRole(c.Request.Context(), id)
	if err != nil {
		if err == services.ErrRoleNotFound {
			utils.Error(c, http.StatusNotFound, "Role not found", "NOT_FOUND", nil)
			return
		}
		utils.Error(c, http.StatusInternalServerError, "Failed to get role", "DB_ERROR", nil)
		return
	}

	utils.Success(c, http.StatusOK, gin.H{"role": role, "permissions": perms}, "Role retrieved")
}

type createRoleRequest struct {
	Name        string  `json:"name" binding:"required"`
	Slug        string  `json:"slug" binding:"required"`
	Description *string `json:"description"`
}

func (h *PermissionHandler) CreateRole(c *gin.Context) {
	var req createRoleRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		utils.Error(c, http.StatusBadRequest, "Invalid request body: "+err.Error(), "VALIDATION_ERROR", nil)
		return
	}

	role := &models.Role{
		Name:        req.Name,
		Slug:        req.Slug,
		Description: req.Description,
	}

	if err := h.permService.CreateRole(c.Request.Context(), role); err != nil {
		utils.Error(c, http.StatusInternalServerError, "Failed to create role", "DB_ERROR", nil)
		return
	}

	utils.Success(c, http.StatusCreated, role, "Role created")
}

type updateRoleRequest struct {
	Name        *string `json:"name"`
	Description *string `json:"description"`
}

func (h *PermissionHandler) UpdateRole(c *gin.Context) {
	id, err := uuid.Parse(c.Param("id"))
	if err != nil {
		utils.Error(c, http.StatusBadRequest, "Invalid role ID", "VALIDATION_ERROR", nil)
		return
	}

	var req updateRoleRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		utils.Error(c, http.StatusBadRequest, "Invalid request body", "VALIDATION_ERROR", nil)
		return
	}

	role, _, err := h.permService.GetRole(c.Request.Context(), id)
	if err != nil {
		utils.Error(c, http.StatusNotFound, "Role not found", "NOT_FOUND", nil)
		return
	}

	if req.Name != nil {
		role.Name = *req.Name
	}
	if req.Description != nil {
		role.Description = req.Description
	}

	if err := h.permService.UpdateRole(c.Request.Context(), role); err != nil {
		if err == services.ErrCannotModifySystemRole {
			utils.Error(c, http.StatusForbidden, "Cannot modify system role", "FORBIDDEN", nil)
			return
		}
		utils.Error(c, http.StatusInternalServerError, "Failed to update role", "DB_ERROR", nil)
		return
	}

	utils.Success(c, http.StatusOK, role, "Role updated")
}

func (h *PermissionHandler) DeleteRole(c *gin.Context) {
	id, err := uuid.Parse(c.Param("id"))
	if err != nil {
		utils.Error(c, http.StatusBadRequest, "Invalid role ID", "VALIDATION_ERROR", nil)
		return
	}

	if err := h.permService.DeleteRole(c.Request.Context(), id); err != nil {
		if err == services.ErrCannotModifySystemRole {
			utils.Error(c, http.StatusForbidden, "Cannot delete system role", "FORBIDDEN", nil)
			return
		}
		utils.Error(c, http.StatusInternalServerError, "Failed to delete role", "DB_ERROR", nil)
		return
	}

	utils.Success(c, http.StatusOK, nil, "Role deleted")
}

func (h *PermissionHandler) ListPermissions(c *gin.Context) {
	perms, err := h.permService.ListPermissions(c.Request.Context())
	if err != nil {
		utils.Error(c, http.StatusInternalServerError, "Failed to list permissions", "DB_ERROR", nil)
		return
	}
	utils.Success(c, http.StatusOK, perms, "Permissions retrieved")
}

type assignPermissionRequest struct {
	PermissionID string `json:"permission_id" binding:"required"`
}

func (h *PermissionHandler) AssignPermission(c *gin.Context) {
	roleID, err := uuid.Parse(c.Param("id"))
	if err != nil {
		utils.Error(c, http.StatusBadRequest, "Invalid role ID", "VALIDATION_ERROR", nil)
		return
	}

	var req assignPermissionRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		utils.Error(c, http.StatusBadRequest, "Invalid request body", "VALIDATION_ERROR", nil)
		return
	}

	permID, err := uuid.Parse(req.PermissionID)
	if err != nil {
		utils.Error(c, http.StatusBadRequest, "Invalid permission ID", "VALIDATION_ERROR", nil)
		return
	}

	if err := h.permService.AssignPermission(c.Request.Context(), roleID, permID); err != nil {
		if err == services.ErrRoleNotFound {
			utils.Error(c, http.StatusNotFound, "Role not found", "NOT_FOUND", nil)
			return
		}
		utils.Error(c, http.StatusInternalServerError, "Failed to assign permission", "DB_ERROR", nil)
		return
	}

	utils.Success(c, http.StatusOK, nil, "Permission assigned")
}

func (h *PermissionHandler) RemovePermission(c *gin.Context) {
	roleID, err := uuid.Parse(c.Param("id"))
	if err != nil {
		utils.Error(c, http.StatusBadRequest, "Invalid role ID", "VALIDATION_ERROR", nil)
		return
	}

	permID, err := uuid.Parse(c.Param("permissionId"))
	if err != nil {
		utils.Error(c, http.StatusBadRequest, "Invalid permission ID", "VALIDATION_ERROR", nil)
		return
	}

	if err := h.permService.RemovePermission(c.Request.Context(), roleID, permID); err != nil {
		if err == services.ErrCannotModifySystemRole {
			utils.Error(c, http.StatusForbidden, "Cannot modify system role permissions", "FORBIDDEN", nil)
			return
		}
		utils.Error(c, http.StatusInternalServerError, "Failed to remove permission", "DB_ERROR", nil)
		return
	}

	utils.Success(c, http.StatusOK, nil, "Permission removed")
}

func (h *PermissionHandler) GetUserPermissions(c *gin.Context) {
	userID := ctxUUID(c, "user_id")
	perms, err := h.permService.GetUserPermissions(c.Request.Context(), userID)
	if err != nil {
		utils.Error(c, http.StatusInternalServerError, "Failed to get user permissions", "DB_ERROR", nil)
		return
	}
	utils.Success(c, http.StatusOK, perms, "User permissions retrieved")
}

func (h *PermissionHandler) GetAllRolesWithPermissions(c *gin.Context) {
	result, err := h.permService.GetAllRolesWithPermissions(c.Request.Context())
	if err != nil {
		utils.Error(c, http.StatusInternalServerError, "Failed to get roles with permissions", "DB_ERROR", nil)
		return
	}
	utils.Success(c, http.StatusOK, result, "Roles with permissions retrieved")
}

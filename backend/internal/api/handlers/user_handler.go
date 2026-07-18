package handlers

import (
	"net/http"
	"strconv"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
	"github.com/hospital/nms-backend/internal/models"
	"github.com/hospital/nms-backend/internal/repository"
	"github.com/hospital/nms-backend/pkg/utils"
	"golang.org/x/crypto/bcrypt"
)

type UserHandler struct {
	userRepo *repository.UserRepository
}

func NewUserHandler(userRepo *repository.UserRepository) *UserHandler {
	return &UserHandler{userRepo: userRepo}
}

func (h *UserHandler) List(c *gin.Context) {
	orgID := c.MustGet("org_id").(uuid.UUID)
	page, _ := strconv.Atoi(c.DefaultQuery("page", "1"))
	limit, _ := strconv.Atoi(c.DefaultQuery("limit", "20"))
	search := c.Query("search")

	if page < 1 {
		page = 1
	}
	if limit < 1 || limit > 100 {
		limit = 20
	}

	users, total, err := h.userRepo.List(c.Request.Context(), orgID, page, limit, search)
	if err != nil {
		utils.Error(c, http.StatusInternalServerError, "Failed to list users", "DB_ERROR", nil)
		return
	}

	sanitized := make([]models.User, len(users))
	for i, u := range users {
		u.Sanitize()
		sanitized[i] = u
	}

	totalPages := (total + limit - 1) / limit
	utils.SuccessWithMeta(c, http.StatusOK, sanitized, &utils.Meta{
		Page:       page,
		Limit:      limit,
		Total:      total,
		TotalPages: totalPages,
	})
}

func (h *UserHandler) Get(c *gin.Context) {
	id, err := uuid.Parse(c.Param("id"))
	if err != nil {
		utils.Error(c, http.StatusBadRequest, "Invalid user ID", "VALIDATION_ERROR", nil)
		return
	}

	user, err := h.userRepo.GetByID(c.Request.Context(), id)
	if err != nil {
		utils.Error(c, http.StatusNotFound, "User not found", "NOT_FOUND", nil)
		return
	}

	utils.Success(c, http.StatusOK, user.Sanitize(), "User retrieved")
}

type createUserRequest struct {
	Username    string  `json:"username" binding:"required"`
	Email       string  `json:"email" binding:"required"`
	Password    string  `json:"password" binding:"required,min=8"`
	DisplayName *string `json:"display_name"`
	FirstName   *string `json:"first_name"`
	LastName    *string `json:"last_name"`
	Role        string  `json:"role" binding:"required"`
	Department  *string `json:"department"`
	Title       *string `json:"title"`
	Phone       *string `json:"phone"`
	IsActive    *bool   `json:"is_active"`
}

func (h *UserHandler) Create(c *gin.Context) {
	var req createUserRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		utils.Error(c, http.StatusBadRequest, "Invalid request body: "+err.Error(), "VALIDATION_ERROR", nil)
		return
	}

	orgID := c.MustGet("org_id").(uuid.UUID)
	hash, err := bcrypt.GenerateFromPassword([]byte(req.Password), bcrypt.DefaultCost)
	if err != nil {
		utils.Error(c, http.StatusInternalServerError, "Failed to hash password", "INTERNAL_ERROR", nil)
		return
	}

	isActive := true
	if req.IsActive != nil {
		isActive = *req.IsActive
	}

	user := &models.User{
		OrganizationID: orgID,
		Username:       req.Username,
		Email:          req.Email,
		PasswordHash:   string(hash),
		DisplayName:    req.DisplayName,
		FirstName:      req.FirstName,
		LastName:       req.LastName,
		Role:           req.Role,
		Department:     req.Department,
		Title:          req.Title,
		Phone:          req.Phone,
		IsActive:       isActive,
	}

	if err := h.userRepo.Create(c.Request.Context(), user); err != nil {
		utils.Error(c, http.StatusConflict, "Failed to create user: "+err.Error(), "CONFLICT", nil)
		return
	}

	utils.Success(c, http.StatusCreated, user.Sanitize(), "User created")
}

type updateUserRequest struct {
	Username    *string `json:"username"`
	Email       *string `json:"email"`
	DisplayName *string `json:"display_name"`
	FirstName   *string `json:"first_name"`
	LastName    *string `json:"last_name"`
	Role        *string `json:"role"`
	Department  *string `json:"department"`
	Title       *string `json:"title"`
	Phone       *string `json:"phone"`
	IsActive    *bool   `json:"is_active"`
}

func (h *UserHandler) Update(c *gin.Context) {
	id, err := uuid.Parse(c.Param("id"))
	if err != nil {
		utils.Error(c, http.StatusBadRequest, "Invalid user ID", "VALIDATION_ERROR", nil)
		return
	}

	var req updateUserRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		utils.Error(c, http.StatusBadRequest, "Invalid request body", "VALIDATION_ERROR", nil)
		return
	}

	existing, err := h.userRepo.GetByID(c.Request.Context(), id)
	if err != nil {
		utils.Error(c, http.StatusNotFound, "User not found", "NOT_FOUND", nil)
		return
	}

	if req.Username != nil {
		existing.Username = *req.Username
	}
	if req.Email != nil {
		existing.Email = *req.Email
	}
	if req.DisplayName != nil {
		existing.DisplayName = req.DisplayName
	}
	if req.FirstName != nil {
		existing.FirstName = req.FirstName
	}
	if req.LastName != nil {
		existing.LastName = req.LastName
	}
	if req.Role != nil {
		existing.Role = *req.Role
	}
	if req.Department != nil {
		existing.Department = req.Department
	}
	if req.Title != nil {
		existing.Title = req.Title
	}
	if req.Phone != nil {
		existing.Phone = req.Phone
	}
	if req.IsActive != nil {
		existing.IsActive = *req.IsActive
	}

	if err := h.userRepo.Update(c.Request.Context(), existing); err != nil {
		utils.Error(c, http.StatusInternalServerError, "Failed to update user", "DB_ERROR", nil)
		return
	}

	utils.Success(c, http.StatusOK, existing.Sanitize(), "User updated")
}

func (h *UserHandler) Delete(c *gin.Context) {
	id, err := uuid.Parse(c.Param("id"))
	if err != nil {
		utils.Error(c, http.StatusBadRequest, "Invalid user ID", "VALIDATION_ERROR", nil)
		return
	}

	currentUserID := c.MustGet("user_id").(uuid.UUID)
	if id == currentUserID {
		utils.Error(c, http.StatusBadRequest, "Cannot delete yourself", "VALIDATION_ERROR", nil)
		return
	}

	if err := h.userRepo.Delete(c.Request.Context(), id); err != nil {
		utils.Error(c, http.StatusInternalServerError, "Failed to delete user", "DB_ERROR", nil)
		return
	}

	utils.Success(c, http.StatusOK, nil, "User deleted")
}

type changePasswordRequest struct {
	CurrentPassword string `json:"current_password" binding:"required"`
	NewPassword     string `json:"new_password" binding:"required,min=8"`
}

func (h *UserHandler) ChangePassword(c *gin.Context) {
	userID := c.MustGet("user_id").(uuid.UUID)

	var req changePasswordRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		utils.Error(c, http.StatusBadRequest, "Invalid request: "+err.Error(), "VALIDATION_ERROR", nil)
		return
	}

	user, err := h.userRepo.GetByID(c.Request.Context(), userID)
	if err != nil {
		utils.Error(c, http.StatusNotFound, "User not found", "NOT_FOUND", nil)
		return
	}

	if err := bcrypt.CompareHashAndPassword([]byte(user.PasswordHash), []byte(req.CurrentPassword)); err != nil {
		utils.Error(c, http.StatusBadRequest, "Current password is incorrect", "VALIDATION_ERROR", nil)
		return
	}

	hash, err := bcrypt.GenerateFromPassword([]byte(req.NewPassword), bcrypt.DefaultCost)
	if err != nil {
		utils.Error(c, http.StatusInternalServerError, "Failed to hash password", "INTERNAL_ERROR", nil)
		return
	}

	if err := h.userRepo.UpdatePassword(c.Request.Context(), userID, string(hash)); err != nil {
		utils.Error(c, http.StatusInternalServerError, "Failed to update password", "DB_ERROR", nil)
		return
	}

	utils.Success(c, http.StatusOK, nil, "Password changed successfully")
}

func (h *UserHandler) GetPermissions(c *gin.Context) {
	userID := c.MustGet("user_id").(uuid.UUID)
	perms, err := h.userRepo.GetUserPermissions(c.Request.Context(), userID)
	if err != nil {
		utils.Error(c, http.StatusInternalServerError, "Failed to get permissions", "DB_ERROR", nil)
		return
	}
	utils.Success(c, http.StatusOK, perms, "Permissions retrieved")
}

type adminResetPasswordRequest struct {
	NewPassword string `json:"new_password" binding:"required,min=8"`
}

func (h *UserHandler) AdminResetPassword(c *gin.Context) {
	targetID, err := uuid.Parse(c.Param("id"))
	if err != nil {
		utils.Error(c, http.StatusBadRequest, "Invalid user ID", "VALIDATION_ERROR", nil)
		return
	}

	var req adminResetPasswordRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		utils.Error(c, http.StatusBadRequest, "Invalid request: "+err.Error(), "VALIDATION_ERROR", nil)
		return
	}

	if _, err := h.userRepo.GetByID(c.Request.Context(), targetID); err != nil {
		utils.Error(c, http.StatusNotFound, "User not found", "NOT_FOUND", nil)
		return
	}

	hash, err := bcrypt.GenerateFromPassword([]byte(req.NewPassword), bcrypt.DefaultCost)
	if err != nil {
		utils.Error(c, http.StatusInternalServerError, "Failed to hash password", "INTERNAL_ERROR", nil)
		return
	}

	if err := h.userRepo.UpdatePassword(c.Request.Context(), targetID, string(hash)); err != nil {
		utils.Error(c, http.StatusInternalServerError, "Failed to reset password", "DB_ERROR", nil)
		return
	}

	utils.Success(c, http.StatusOK, nil, "Password reset successfully")
}

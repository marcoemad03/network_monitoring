package handlers

import (
	"net/http"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
	"github.com/hospital/nms-backend/internal/repository"
	"github.com/hospital/nms-backend/internal/services"
	"github.com/hospital/nms-backend/pkg/utils"
)

type AuthHandler struct {
	authService *services.AuthService
	userRepo    *repository.UserRepository
}

func NewAuthHandler(authService *services.AuthService, userRepo *repository.UserRepository) *AuthHandler {
	return &AuthHandler{authService: authService, userRepo: userRepo}
}

type loginRequest struct {
	Username string `json:"username" binding:"required"`
	Password string `json:"password" binding:"required"`
}

type refreshRequest struct {
	RefreshToken string `json:"refresh_token" binding:"required"`
}

type forgotPasswordRequest struct {
	Email string `json:"email" binding:"required"`
}

type resetPasswordRequest struct {
	Token       string `json:"token" binding:"required"`
	NewPassword string `json:"new_password" binding:"required,min=8"`
}

func (h *AuthHandler) Login(c *gin.Context) {
	var req loginRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		utils.Error(c, http.StatusBadRequest, "Invalid request body", "VALIDATION_ERROR", nil)
		return
	}

	ip := c.ClientIP()
	userAgent := c.GetHeader("User-Agent")
	result, err := h.authService.Login(c.Request.Context(), req.Username, req.Password, ip, userAgent)
	if err != nil {
		status := http.StatusUnauthorized
		code := "AUTH_ERROR"
		if err == services.ErrAccountLocked {
			status = http.StatusTooManyRequests
			code = "ACCOUNT_LOCKED"
		}
		utils.Error(c, status, err.Error(), code, nil)
		return
	}

	utils.Success(c, http.StatusOK, gin.H{
		"access_token":  result.AccessToken,
		"refresh_token": result.RefreshToken,
		"token_type":    result.TokenType,
		"expires_in":    result.ExpiresIn,
		"user":          result.User,
	}, "Login successful")
}

func (h *AuthHandler) RefreshToken(c *gin.Context) {
	var req refreshRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		utils.Error(c, http.StatusBadRequest, "Refresh token is required", "VALIDATION_ERROR", nil)
		return
	}

	userAgent := c.GetHeader("User-Agent")
	result, err := h.authService.RefreshToken(c.Request.Context(), req.RefreshToken, userAgent)
	if err != nil {
		utils.Error(c, http.StatusUnauthorized, err.Error(), "TOKEN_ERROR", nil)
		return
	}

	utils.Success(c, http.StatusOK, gin.H{
		"access_token":  result.AccessToken,
		"refresh_token": result.RefreshToken,
		"token_type":    result.TokenType,
		"expires_in":    result.ExpiresIn,
	}, "Token refreshed")
}

func (h *AuthHandler) Logout(c *gin.Context) {
	authHeader := c.GetHeader("Authorization")
	if len(authHeader) > 7 {
		token := authHeader[7:]
		h.authService.Logout(c.Request.Context(), token)
	}
	utils.Success(c, http.StatusOK, nil, "Logged out successfully")
}

func (h *AuthHandler) GetCurrentUser(c *gin.Context) {
	userIDStr := c.GetString("user_id")
	userID, err := uuid.Parse(userIDStr)
	if err != nil {
		utils.Error(c, http.StatusUnauthorized, "Invalid user", "AUTH_ERROR", nil)
		return
	}

	user, err := h.userRepo.GetByID(c.Request.Context(), userID)
	if err != nil {
		utils.Error(c, http.StatusNotFound, "User not found", "NOT_FOUND", nil)
		return
	}

	permissions, _ := h.userRepo.GetUserPermissions(c.Request.Context(), userID)

	utils.Success(c, http.StatusOK, gin.H{
		"user":        user.Sanitize(),
		"permissions": permissions,
	}, "User retrieved")
}

func (h *AuthHandler) ForgotPassword(c *gin.Context) {
	var req forgotPasswordRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		utils.Error(c, http.StatusBadRequest, "Email is required", "VALIDATION_ERROR", nil)
		return
	}

	h.authService.ForgotPassword(c.Request.Context(), req.Email)
	utils.Success(c, http.StatusOK, nil, "Password reset email sent if account exists")
}

func (h *AuthHandler) ResetPassword(c *gin.Context) {
	var req resetPasswordRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		utils.Error(c, http.StatusBadRequest, "Token and new password are required", "VALIDATION_ERROR", nil)
		return
	}

	if err := h.authService.ResetPassword(c.Request.Context(), req.Token, req.NewPassword); err != nil {
		utils.Error(c, http.StatusBadRequest, err.Error(), "RESET_ERROR", nil)
		return
	}

	utils.Success(c, http.StatusOK, nil, "Password reset successfully")
}

func (h *AuthHandler) ListSessions(c *gin.Context) {
	userID := c.MustGet("user_id").(uuid.UUID)
	sessions, err := h.authService.ListSessions(c.Request.Context(), userID)
	if err != nil {
		utils.Error(c, http.StatusInternalServerError, "Failed to list sessions", "DB_ERROR", nil)
		return
	}
	utils.Success(c, http.StatusOK, sessions, "Sessions retrieved")
}

func (h *AuthHandler) RevokeSession(c *gin.Context) {
	sessionID, err := uuid.Parse(c.Param("id"))
	if err != nil {
		utils.Error(c, http.StatusBadRequest, "Invalid session ID", "VALIDATION_ERROR", nil)
		return
	}

	userID := c.MustGet("user_id").(uuid.UUID)
	if err := h.authService.RevokeSession(c.Request.Context(), userID, sessionID); err != nil {
		utils.Error(c, http.StatusInternalServerError, "Failed to revoke session", "DB_ERROR", nil)
		return
	}

	utils.Success(c, http.StatusOK, nil, "Session revoked")
}

func (h *AuthHandler) RevokeAllSessions(c *gin.Context) {
	userID := c.MustGet("user_id").(uuid.UUID)
	if err := h.authService.RevokeAllSessions(c.Request.Context(), userID); err != nil {
		utils.Error(c, http.StatusInternalServerError, "Failed to revoke all sessions", "DB_ERROR", nil)
		return
	}

	utils.Success(c, http.StatusOK, nil, "All sessions revoked")
}

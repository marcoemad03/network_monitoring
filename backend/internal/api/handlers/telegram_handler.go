package handlers

import (
	"net/http"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
	"github.com/hospital/nms-backend/internal/models"
	"github.com/hospital/nms-backend/internal/services"
)

type TelegramHandler struct {
	service *services.TelegramService
}

func NewTelegramHandler(service *services.TelegramService) *TelegramHandler {
	return &TelegramHandler{service: service}
}

func (h *TelegramHandler) orgID(c *gin.Context) (uuid.UUID, bool) {
	orgID, err := uuid.Parse(c.GetString("org_id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "message": "Invalid organization ID", "error_code": "VALIDATION_ERROR"})
		return uuid.Nil, false
	}
	return orgID, true
}

func (h *TelegramHandler) GetConfig(c *gin.Context) {
	orgID, ok := h.orgID(c)
	if !ok {
		return
	}
	cfg, err := h.service.GetConfig(c.Request.Context(), orgID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"success": false, "message": "Failed to load Telegram config", "error_code": "SERVER_ERROR"})
		return
	}
	cfg.BotToken = maskToken(cfg.BotToken)
	c.JSON(http.StatusOK, gin.H{"success": true, "data": cfg})
}

func (h *TelegramHandler) SaveConfig(c *gin.Context) {
	orgID, ok := h.orgID(c)
	if !ok {
		return
	}
	var cfg models.TelegramConfig
	if err := c.ShouldBindJSON(&cfg); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "message": "Invalid request body", "error_code": "VALIDATION_ERROR"})
		return
	}
	cfg.OrganizationID = orgID

	current, _ := h.service.GetConfig(c.Request.Context(), orgID)
	if current != nil && cfg.BotToken == maskToken(current.BotToken) {
		cfg.BotToken = current.BotToken
	}

	if err := h.service.SaveConfig(c.Request.Context(), &cfg); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "message": err.Error(), "error_code": "VALIDATION_ERROR"})
		return
	}
	c.JSON(http.StatusOK, gin.H{"success": true, "data": cfg, "message": "Telegram configuration saved"})
}

func (h *TelegramHandler) Test(c *gin.Context) {
	orgID, ok := h.orgID(c)
	if !ok {
		return
	}
	var req struct {
		BotToken string `json:"bot_token"`
		ChatID   string `json:"chat_id"`
	}
	if err := c.ShouldBindJSON(&req); err != nil || req.BotToken == "" || req.ChatID == "" {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "message": "bot_token and chat_id are required", "error_code": "VALIDATION_ERROR"})
		return
	}
	cfg := &models.TelegramConfig{OrganizationID: orgID, BotToken: req.BotToken, ChatID: req.ChatID, Enabled: true}
	if err := h.service.SaveConfig(c.Request.Context(), cfg); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "message": err.Error(), "error_code": "VALIDATION_ERROR"})
		return
	}
	if err := h.service.Notify(c.Request.Context(), orgID, models.TelegramEventConnect, "", "Test Notification", "", ""); err != nil {
		c.JSON(http.StatusBadGateway, gin.H{"success": false, "message": "Telegram test failed: " + err.Error(), "error_code": "TELEGRAM_ERROR"})
		return
	}
	c.JSON(http.StatusOK, gin.H{"success": true, "message": "Test notification sent to Telegram"})
}

func maskToken(token string) string {
	if len(token) < 8 {
		return token
	}
	return token[:4] + "..." + token[len(token)-4:]
}

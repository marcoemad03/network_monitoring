package handlers

import (
	"net/http"
	"strings"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
	"github.com/hospital/nms-backend/internal/models"
	"github.com/hospital/nms-backend/internal/services"
)

type HotspotWelcomeHandler struct {
	service *services.HotspotWelcomeService
}

func NewHotspotWelcomeHandler(service *services.HotspotWelcomeService) *HotspotWelcomeHandler {
	return &HotspotWelcomeHandler{service: service}
}

func (h *HotspotWelcomeHandler) organizationID(c *gin.Context) (uuid.UUID, bool) {
	orgID, err := uuid.Parse(c.GetString("org_id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "message": "Invalid organization ID", "error_code": "VALIDATION_ERROR"})
		return uuid.Nil, false
	}
	return orgID, true
}

func (h *HotspotWelcomeHandler) Get(c *gin.Context) {
	orgID, ok := h.organizationID(c)
	if !ok {
		return
	}
	config, err := h.service.Get(c.Request.Context(), orgID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"success": false, "message": "Failed to load hotspot welcome configuration", "error_code": "SERVER_ERROR"})
		return
	}
	c.JSON(http.StatusOK, gin.H{"success": true, "data": config})
}

func (h *HotspotWelcomeHandler) Update(c *gin.Context) {
	orgID, ok := h.organizationID(c)
	if !ok {
		return
	}
	var config models.HotspotWelcomeConfig
	if err := c.ShouldBindJSON(&config); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "message": "Invalid request body", "error_code": "VALIDATION_ERROR"})
		return
	}
	config.OrganizationID = orgID
	if config.Announcements == nil {
		config.Announcements = []string{}
	}
	if err := h.service.Save(c.Request.Context(), &config); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "message": err.Error(), "error_code": "VALIDATION_ERROR"})
		return
	}
	c.JSON(http.StatusOK, gin.H{"success": true, "data": config, "message": "Hotspot welcome configuration saved"})
}

func (h *HotspotWelcomeHandler) Download(c *gin.Context) {
	orgID, ok := h.organizationID(c)
	if !ok {
		return
	}
	content, err := h.service.Generate(c.Request.Context(), orgID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"success": false, "message": "Failed to generate login.html", "error_code": "SERVER_ERROR"})
		return
	}
	c.Header("Content-Disposition", `attachment; filename="login.html"`)
	c.Data(http.StatusOK, "text/html; charset=utf-8", content)
}

func (h *HotspotWelcomeHandler) ConfigureProfile(c *gin.Context) {
	var request struct {
		Endpoint      string `json:"endpoint"`
		Username      string `json:"username"`
		Password      string `json:"password"`
		Profile       string `json:"profile"`
		HTMLDirectory string `json:"html_directory"`
	}
	if err := c.ShouldBindJSON(&request); err != nil || strings.TrimSpace(request.Endpoint) == "" || strings.TrimSpace(request.Username) == "" {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "message": "Endpoint, username, profile, and HTML directory are required", "error_code": "VALIDATION_ERROR"})
		return
	}
	result, err := h.service.ConfigureProfile(request.Endpoint, request.Username, request.Password, request.Profile, request.HTMLDirectory)
	if err != nil {
		c.JSON(http.StatusBadGateway, gin.H{"success": false, "message": "RouterOS profile was not configured: " + err.Error(), "error_code": "ROUTEROS_ERROR", "data": models.HotspotProfileResult{FileUploaded: false}})
		return
	}
	c.JSON(http.StatusOK, gin.H{"success": true, "data": result})
}

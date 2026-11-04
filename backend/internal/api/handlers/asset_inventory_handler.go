package handlers

import (
	"net/http"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/hospital/nms-backend/internal/services"
)

type AssetInventoryHandler struct {
	service *services.AssetInventoryService
}

func NewAssetInventoryHandler(service *services.AssetInventoryService) *AssetInventoryHandler {
	return &AssetInventoryHandler{service: service}
}

func (h *AssetInventoryHandler) Get(c *gin.Context) {
	orgID, err := parseUUID(c.GetString("org_id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "message": "Invalid organization", "error_code": "VALIDATION_ERROR"})
		return
	}
	inv, err := h.service.Get(c.Request.Context(), orgID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"success": false, "message": "Failed to load the inventory", "error_code": "SERVER_ERROR"})
		return
	}
	c.JSON(http.StatusOK, gin.H{"success": true, "data": inv, "message": "Inventory retrieved"})
}

func (h *AssetInventoryHandler) Scan(c *gin.Context) {
	orgID, err := parseUUID(c.GetString("org_id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "message": "Invalid organization", "error_code": "VALIDATION_ERROR"})
		return
	}
	st, err := h.service.StartScan(c.Request.Context(), orgID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"success": false, "message": "Failed to start the scan", "error_code": "SERVER_ERROR"})
		return
	}
	c.JSON(http.StatusAccepted, gin.H{"success": true, "data": st, "message": "Scan started"})
}

func (h *AssetInventoryHandler) Export(c *gin.Context) {
	orgID, err := parseUUID(c.GetString("org_id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "message": "Invalid organization", "error_code": "VALIDATION_ERROR"})
		return
	}
	inv, err := h.service.Get(c.Request.Context(), orgID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"success": false, "message": "Failed to load the inventory", "error_code": "SERVER_ERROR"})
		return
	}
	now := time.Now()
	c.Header("Content-Disposition", `attachment; filename="`+services.InventoryFileName(now)+`"`)
	c.Header("X-Content-Type-Options", "nosniff")
	c.Data(http.StatusOK, "text/csv; charset=utf-8", services.ExportInventoryCSV(inv, now))
}

package handlers

import (
	"context"
	"net/http"
	"strconv"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
	"github.com/hospital/nms-backend/internal/models"
	"github.com/hospital/nms-backend/internal/repository"
	"github.com/hospital/nms-backend/internal/services"
)

type ScanHandler struct {
	scanRepo    *repository.ScanRepository
	discService *services.DiscoveryService
	internetSvc *services.InternetService
}

func NewScanHandler(scanRepo *repository.ScanRepository, discService *services.DiscoveryService, internetSvc *services.InternetService) *ScanHandler {
	return &ScanHandler{
		scanRepo:    scanRepo,
		discService: discService,
		internetSvc: internetSvc,
	}
}

type startScanRequest struct {
	TargetSubnet string   `json:"target_subnet" binding:"required"`
	Name         string   `json:"name"`
	PortRange    string   `json:"port_range"`
	Ports        []int    `json:"ports"`
	VendorID     string   `json:"vendor_id"`
}

func (h *ScanHandler) List(c *gin.Context) {
	orgID, err := parseUUID(c.GetString("org_id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "message": "Invalid organization ID", "error_code": "VALIDATION_ERROR"})
		return
	}
	page, _ := strconv.Atoi(c.DefaultQuery("page", "1"))
	limit, _ := strconv.Atoi(c.DefaultQuery("limit", "20"))

	scans, total, err := h.scanRepo.List(c.Request.Context(), orgID, page, limit)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{
			"success": false, "message": "Failed to fetch scans",
			"error_code": "SERVER_ERROR",
		})
		return
	}

	totalPages := (total + limit - 1) / limit
	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"data":    scans,
		"message": "Scans retrieved",
		"meta": gin.H{
			"page": page, "limit": limit,
			"total": total, "total_pages": totalPages,
		},
	})
}

func (h *ScanHandler) Start(c *gin.Context) {
	orgID, err := parseUUID(c.GetString("org_id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "message": "Invalid organization ID", "error_code": "VALIDATION_ERROR"})
		return
	}

	var req startScanRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{
			"success": false, "message": "target_subnet is required",
			"error_code": "VALIDATION_ERROR",
		})
		return
	}

	scan := &models.NetworkScan{
		ID:             uuid.New(),
		OrganizationID: orgID,
		Type:           "vendor_discovery",
		Status:         "running",
		Name:           &req.Name,
		TargetSubnet:   req.TargetSubnet,
		StartedAt:      time.Now().UTC(),
		CreatedAt:      time.Now().UTC(),
		Progress:       float64Ptr(0),
	}

	if err := h.scanRepo.Create(c.Request.Context(), scan); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{
			"success": false, "message": "Failed to create scan",
			"error_code": "SERVER_ERROR",
		})
		return
	}

	if req.VendorID != "" {
		vendorID, err := uuid.Parse(req.VendorID)
		if err == nil {
			vendor, err := h.internetSvc.GetVendorIntegrationByID(c.Request.Context(), vendorID)
			if err == nil && vendor.VendorType == "mikrotik" && vendor.IsActive {
				go func() {
					bgCtx := context.Background()
					h.discService.StartMikroTikDiscovery(bgCtx, scan, vendor)
				}()
			}
		}
	}

	c.JSON(http.StatusCreated, gin.H{
		"success": true,
		"data":    scan,
		"message": "Scan started",
	})
}

func (h *ScanHandler) Get(c *gin.Context) {
	id, err := uuid.Parse(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{
			"success": false, "message": "Invalid scan ID",
			"error_code": "VALIDATION_ERROR",
		})
		return
	}

	scan, err := h.scanRepo.GetByID(c.Request.Context(), id)
	if err != nil {
		c.JSON(http.StatusNotFound, gin.H{
			"success": false, "message": "Scan not found",
			"error_code": "NOT_FOUND",
		})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"data":    scan,
		"message": "Scan retrieved",
	})
}

func (h *ScanHandler) Cancel(c *gin.Context) {
	id, err := uuid.Parse(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{
			"success": false, "message": "Invalid scan ID",
			"error_code": "VALIDATION_ERROR",
		})
		return
	}

	if err := h.scanRepo.Fail(c.Request.Context(), id, "cancelled by user"); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{
			"success": false, "message": "Failed to cancel scan",
			"error_code": "SERVER_ERROR",
		})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"message": "Scan cancelled",
	})
}

func (h *ScanHandler) GetScanDevices(c *gin.Context) {
	id, err := uuid.Parse(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{
			"success": false, "message": "Invalid scan ID",
			"error_code": "VALIDATION_ERROR",
		})
		return
	}

	results, err := h.scanRepo.ListScanResultsByScanID(c.Request.Context(), id)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{
			"success": false, "message": "Failed to fetch scan results",
			"error_code": "SERVER_ERROR",
		})
		return
	}
	if results == nil {
		results = []models.ScanResult{}
	}

	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"data":    results,
		"message": "Scan results retrieved",
	})
}

func float64Ptr(v float64) *float64 {
	return &v
}

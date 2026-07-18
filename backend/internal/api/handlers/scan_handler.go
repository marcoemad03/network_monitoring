package handlers

import (
	"net/http"
	"strconv"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
	"github.com/hospital/nms-backend/internal/repository"
)

type ScanHandler struct {
	scanRepo *repository.ScanRepository
}

func NewScanHandler(scanRepo *repository.ScanRepository) *ScanHandler {
	return &ScanHandler{scanRepo: scanRepo}
}

type startScanRequest struct {
	TargetSubnet string   `json:"target_subnet" binding:"required"`
	Name         string   `json:"name"`
	PortRange    string   `json:"port_range"`
	Ports        []int    `json:"ports"`
}

func (h *ScanHandler) List(c *gin.Context) {
	orgID := uuid.MustParse(c.GetString("org_id"))
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
	var req startScanRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{
			"success": false, "message": "target_subnet is required",
			"error_code": "VALIDATION_ERROR",
		})
		return
	}

	c.JSON(http.StatusCreated, gin.H{
		"success": true,
		"data": gin.H{
			"id":             uuid.New(),
			"type":           "ping",
			"status":         "running",
			"target_subnet":  req.TargetSubnet,
			"name":           req.Name,
			"progress":       0,
			"started_at":     "2024-01-01T00:00:00Z",
		},
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

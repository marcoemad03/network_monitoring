package handlers

import (
	"errors"
	"net/http"

	"github.com/gin-gonic/gin"
	"github.com/hospital/nms-backend/internal/services"
)

// NetworkMapHandler serves the network map.
type NetworkMapHandler struct {
	service *services.NetworkMapService
}

func NewNetworkMapHandler(service *services.NetworkMapService) *NetworkMapHandler {
	return &NetworkMapHandler{service: service}
}

// Get returns every device with its type, name, address and place. ?refresh=1 asks
// for a fresh read of the router's wiring.
func (h *NetworkMapHandler) Get(c *gin.Context) {
	orgID, err := parseUUID(c.GetString("org_id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "message": "Invalid organization", "error_code": "VALIDATION_ERROR"})
		return
	}
	m, err := h.service.Build(c.Request.Context(), orgID, c.Query("refresh") == "1")
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"success": false, "message": "Failed to load the network map", "error_code": "SERVER_ERROR"})
		return
	}
	c.JSON(http.StatusOK, gin.H{"success": true, "data": m, "message": "Network map retrieved"})
}

// SavePlace names a router port.
func (h *NetworkMapHandler) SavePlace(c *gin.Context) {
	orgID, err := parseUUID(c.GetString("org_id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "message": "Invalid organization", "error_code": "VALIDATION_ERROR"})
		return
	}
	var req struct {
		Label string `json:"label"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "message": "Invalid request", "error_code": "VALIDATION_ERROR"})
		return
	}
	if err := h.service.SavePlace(c.Request.Context(), orgID, c.Param("port"), req.Label); err != nil {
		var input *services.ClientNoteError
		if errors.As(err, &input) {
			c.JSON(http.StatusBadRequest, gin.H{"success": false, "message": input.Message, "error_code": "VALIDATION_ERROR"})
			return
		}
		c.JSON(http.StatusInternalServerError, gin.H{"success": false, "message": "Failed to save", "error_code": "SERVER_ERROR"})
		return
	}
	c.JSON(http.StatusOK, gin.H{"success": true, "message": "Saved"})
}

// SaveDevicePlaces says where several devices are in one call.
func (h *NetworkMapHandler) SaveDevicePlaces(c *gin.Context) {
	orgID, err := parseUUID(c.GetString("org_id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "message": "Invalid organization", "error_code": "VALIDATION_ERROR"})
		return
	}
	var req struct {
		MACs  []string `json:"macs"`
		Place string   `json:"place"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "message": "Invalid request", "error_code": "VALIDATION_ERROR"})
		return
	}
	n, err := h.service.SaveDevicePlaces(c.Request.Context(), orgID, req.MACs, req.Place)
	if err != nil {
		var input *services.ClientNoteError
		if errors.As(err, &input) {
			c.JSON(http.StatusBadRequest, gin.H{"success": false, "message": input.Message, "error_code": "VALIDATION_ERROR"})
			return
		}
		c.JSON(http.StatusInternalServerError, gin.H{"success": false, "message": "Failed to save", "error_code": "SERVER_ERROR"})
		return
	}
	c.JSON(http.StatusOK, gin.H{"success": true, "data": gin.H{"updated": n}, "message": "Saved"})
}

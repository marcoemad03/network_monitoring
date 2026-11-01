package handlers

import (
	"errors"
	"net/http"
	"strconv"

	"github.com/gin-gonic/gin"
	"github.com/hospital/nms-backend/internal/services"
)

// ClientHandler serves the inventory of devices on the network.
type ClientHandler struct {
	service *services.ClientInventoryService
}

func NewClientHandler(service *services.ClientInventoryService) *ClientHandler {
	return &ClientHandler{service: service}
}

func (h *ClientHandler) fail(c *gin.Context, err error, fallback string) {
	var input *services.ClientNoteError
	if errors.As(err, &input) {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "message": input.Message, "error_code": "VALIDATION_ERROR"})
		return
	}
	c.JSON(http.StatusInternalServerError, gin.H{"success": false, "message": fallback, "error_code": "SERVER_ERROR"})
}

// List returns the devices on the network with type, usage and notes.
func (h *ClientHandler) List(c *gin.Context) {
	orgID, err := parseUUID(c.GetString("org_id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "message": "Invalid organization", "error_code": "VALIDATION_ERROR"})
		return
	}
	list, err := h.service.List(c.Request.Context(), orgID)
	if err != nil {
		h.fail(c, err, "Failed to load devices")
		return
	}
	c.JSON(http.StatusOK, gin.H{"success": true, "data": list, "message": "Devices retrieved"})
}

// UpdateNote saves the name, comment and type the user gave a device.
func (h *ClientHandler) UpdateNote(c *gin.Context) {
	orgID, err := parseUUID(c.GetString("org_id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "message": "Invalid organization", "error_code": "VALIDATION_ERROR"})
		return
	}
	var req struct {
		DisplayName *string `json:"display_name"`
		Note        *string `json:"note"`
		Kind        *string `json:"kind"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "message": "Invalid request", "error_code": "VALIDATION_ERROR"})
		return
	}
	note, err := h.service.SaveNote(c.Request.Context(), orgID, c.Param("mac"), services.NoteInput{
		DisplayName: req.DisplayName, Note: req.Note, Kind: req.Kind,
	})
	if err != nil {
		h.fail(c, err, "Failed to save")
		return
	}
	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"data": gin.H{
			"display_name": note.DisplayName, "note": note.Note, "kind": note.KindOverride, "updated_at": note.UpdatedAt,
		},
		"message": "Saved",
	})
}

// Usage returns one device's usage per day.
func (h *ClientHandler) Usage(c *gin.Context) {
	orgID, err := parseUUID(c.GetString("org_id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "message": "Invalid organization", "error_code": "VALIDATION_ERROR"})
		return
	}
	days, _ := strconv.Atoi(c.DefaultQuery("days", "7"))
	rows, err := h.service.Usage(c.Request.Context(), orgID, c.Param("mac"), days)
	if err != nil {
		h.fail(c, err, "Failed to load usage")
		return
	}
	c.JSON(http.StatusOK, gin.H{"success": true, "data": rows, "message": "Usage retrieved"})
}

package handlers

import (
	"errors"
	"net/http"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
	"github.com/hospital/nms-backend/internal/models"
	"github.com/hospital/nms-backend/internal/services"
)

type MarcoGroupHandler struct {
	service *services.MarcoGroupService
}

func NewMarcoGroupHandler(service *services.MarcoGroupService) *MarcoGroupHandler {
	return &MarcoGroupHandler{service: service}
}

func (h *MarcoGroupHandler) orgID(c *gin.Context) (uuid.UUID, bool) {
	orgID, err := parseUUID(c.GetString("org_id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "message": "Invalid organization", "error_code": "VALIDATION_ERROR"})
		return uuid.Nil, false
	}
	return orgID, true
}

func (h *MarcoGroupHandler) ListPlatforms(c *gin.Context) {
	c.JSON(http.StatusOK, gin.H{"success": true, "data": services.MarcoPlatforms, "message": "Platforms retrieved"})
}

func (h *MarcoGroupHandler) ListGroups(c *gin.Context) {
	orgID, ok := h.orgID(c)
	if !ok {
		return
	}
	groups, err := h.service.ListGroups(c.Request.Context(), orgID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"success": false, "message": err.Error(), "error_code": "SERVER_ERROR"})
		return
	}
	c.JSON(http.StatusOK, gin.H{"success": true, "data": groups, "dry_run": h.service.DryRun(), "message": "Groups retrieved"})
}

func (h *MarcoGroupHandler) GetGroup(c *gin.Context) {
	orgID, ok := h.orgID(c)
	if !ok {
		return
	}
	id, err := uuid.Parse(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "message": "Invalid group ID", "error_code": "VALIDATION_ERROR"})
		return
	}
	group, err := h.service.GetGroup(c.Request.Context(), orgID, id)
	if err != nil {
		c.JSON(http.StatusNotFound, gin.H{"success": false, "message": "Group not found", "error_code": "NOT_FOUND"})
		return
	}
	c.JSON(http.StatusOK, gin.H{"success": true, "data": group, "message": "Group retrieved"})
}

func (h *MarcoGroupHandler) CreateGroup(c *gin.Context) {
	orgID, ok := h.orgID(c)
	if !ok {
		return
	}
	var req services.CreateGroupRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "message": "Invalid request body", "error_code": "VALIDATION_ERROR"})
		return
	}
	group, err := h.service.CreateGroup(c.Request.Context(), orgID, req)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "message": err.Error(), "error_code": "VALIDATION_ERROR"})
		return
	}
	c.JSON(http.StatusCreated, gin.H{"success": true, "data": group, "message": "Group created"})
}

func (h *MarcoGroupHandler) UpdateGroup(c *gin.Context) {
	orgID, ok := h.orgID(c)
	if !ok {
		return
	}
	id, err := uuid.Parse(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "message": "Invalid group ID", "error_code": "VALIDATION_ERROR"})
		return
	}
	var req services.UpdateGroupRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "message": "Invalid request body", "error_code": "VALIDATION_ERROR"})
		return
	}
	group, err := h.service.UpdateGroup(c.Request.Context(), orgID, id, req)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "message": err.Error(), "error_code": "VALIDATION_ERROR"})
		return
	}
	c.JSON(http.StatusOK, gin.H{"success": true, "data": group, "message": "Group updated"})
}

func (h *MarcoGroupHandler) DeleteGroup(c *gin.Context) {
	orgID, ok := h.orgID(c)
	if !ok {
		return
	}
	id, err := uuid.Parse(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "message": "Invalid group ID", "error_code": "VALIDATION_ERROR"})
		return
	}
	if err := h.service.DeleteGroup(c.Request.Context(), orgID, id); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"success": false, "message": err.Error(), "error_code": "SYNC_ERROR"})
		return
	}
	c.JSON(http.StatusOK, gin.H{"success": true, "dry_run": h.service.DryRun(), "message": "Group deleted"})
}

func (h *MarcoGroupHandler) AddMembers(c *gin.Context) {
	orgID, ok := h.orgID(c)
	if !ok {
		return
	}
	id, err := uuid.Parse(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "message": "Invalid group ID", "error_code": "VALIDATION_ERROR"})
		return
	}
	var req struct {
		MacAddresses []string `json:"mac_addresses" binding:"required"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "message": "mac_addresses required", "error_code": "VALIDATION_ERROR"})
		return
	}
	added, err := h.service.AddMembers(c.Request.Context(), orgID, id, req.MacAddresses)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"success": false, "message": err.Error(), "error_code": "SYNC_ERROR"})
		return
	}
	c.JSON(http.StatusOK, gin.H{"success": true, "data": added, "dry_run": h.service.DryRun(), "message": "Members added and policies applied"})
}

func (h *MarcoGroupHandler) RemoveMember(c *gin.Context) {
	orgID, ok := h.orgID(c)
	if !ok {
		return
	}
	id, err := uuid.Parse(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "message": "Invalid group ID", "error_code": "VALIDATION_ERROR"})
		return
	}
	deviceID, err := uuid.Parse(c.Param("deviceId"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "message": "Invalid device ID", "error_code": "VALIDATION_ERROR"})
		return
	}
	if err := h.service.RemoveMember(c.Request.Context(), orgID, id, deviceID); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"success": false, "message": err.Error(), "error_code": "SYNC_ERROR"})
		return
	}
	c.JSON(http.StatusOK, gin.H{"success": true, "dry_run": h.service.DryRun(), "message": "Member removed and policies applied"})
}

func (h *MarcoGroupHandler) UpdatePolicy(c *gin.Context) {
	orgID, ok := h.orgID(c)
	if !ok {
		return
	}
	id, err := uuid.Parse(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "message": "Invalid group ID", "error_code": "VALIDATION_ERROR"})
		return
	}
	var req models.MarcoGroupPolicy
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "message": "Invalid policy payload", "error_code": "VALIDATION_ERROR"})
		return
	}
	if err := h.service.UpdatePolicy(c.Request.Context(), orgID, id, req); err != nil {
		status := http.StatusInternalServerError
		code := "SYNC_ERROR"
		if errors.Is(err, services.ErrPolicyUnsupported) {
			status = http.StatusUnprocessableEntity
			code = "POLICY_UNSUPPORTED"
		}
		c.JSON(status, gin.H{"success": false, "message": err.Error(), "error_code": code})
		return
	}
	message := "Policy applied and synchronized"
	if h.service.DryRun() {
		message = "Policy saved. Router writes are disabled, nothing was changed on the router"
	}
	c.JSON(http.StatusOK, gin.H{"success": true, "dry_run": h.service.DryRun(), "message": message})
}

func (h *MarcoGroupHandler) Sync(c *gin.Context) {
	orgID, ok := h.orgID(c)
	if !ok {
		return
	}
	var req struct {
		ConfirmRemovals bool `json:"confirm_removals"`
	}
	_ = c.ShouldBindJSON(&req) // the body is optional
	summary, err := h.service.Sync(c.Request.Context(), orgID, req.ConfirmRemovals)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"success": false, "message": err.Error(), "error_code": "SYNC_ERROR"})
		return
	}
	message := "Marco policies synchronized"
	if summary.DryRun {
		message = "Dry-run only: router writes are disabled, nothing was changed on the router"
	}
	c.JSON(http.StatusOK, gin.H{"success": true, "data": summary, "message": message})
}

func (h *MarcoGroupHandler) ListLogs(c *gin.Context) {
	orgID, ok := h.orgID(c)
	if !ok {
		return
	}
	logs, err := h.service.ListLogs(c.Request.Context(), orgID, 100)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"success": false, "message": err.Error(), "error_code": "SERVER_ERROR"})
		return
	}
	c.JSON(http.StatusOK, gin.H{"success": true, "data": logs, "message": "Policy logs retrieved"})
}

func (h *MarcoGroupHandler) DeviceStatuses(c *gin.Context) {
	orgID, ok := h.orgID(c)
	if !ok {
		return
	}
	statuses, err := h.service.DeviceStatuses(c.Request.Context(), orgID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"success": false, "message": err.Error(), "error_code": "SERVER_ERROR"})
		return
	}
	c.JSON(http.StatusOK, gin.H{"success": true, "data": statuses, "message": "Device statuses retrieved"})
}

// ---------------------------------------------------------------------------
// Sites, overrides and group details

func (h *MarcoGroupHandler) fail(c *gin.Context, err error, fallback string) {
	var site *services.SiteInputError
	if errors.As(err, &site) {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "message": site.Message, "error_code": "VALIDATION_ERROR"})
		return
	}
	c.JSON(http.StatusInternalServerError, gin.H{"success": false, "message": fallback, "error_code": "SERVER_ERROR"})
}

// Catalog returns the platforms, the ready-made packs and the always-allowed sites.
func (h *MarcoGroupHandler) Catalog(c *gin.Context) {
	orgID, ok := h.orgID(c)
	if !ok {
		return
	}
	cat, err := h.service.Catalog(c.Request.Context(), orgID)
	if err != nil {
		h.fail(c, err, "Failed to load the site catalog")
		return
	}
	c.JSON(http.StatusOK, gin.H{"success": true, "data": cat, "message": "Catalog retrieved"})
}

// CheckSite says what blocking a typed site would do.
func (h *MarcoGroupHandler) CheckSite(c *gin.Context) {
	var req struct {
		Site string `json:"site"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "message": "Invalid request", "error_code": "VALIDATION_ERROR"})
		return
	}
	c.JSON(http.StatusOK, gin.H{"success": true, "data": h.service.CheckSite(c.Request.Context(), req.Site), "message": "Site checked"})
}

// SiteStatus returns what the blocked sites pointed to at the last sync.
func (h *MarcoGroupHandler) SiteStatus(c *gin.Context) {
	orgID, ok := h.orgID(c)
	if !ok {
		return
	}
	c.JSON(http.StatusOK, gin.H{"success": true, "data": h.service.SiteStatus(orgID), "message": "Site status retrieved"})
}

func (h *MarcoGroupHandler) AddAllowed(c *gin.Context) {
	orgID, ok := h.orgID(c)
	if !ok {
		return
	}
	var req struct {
		Site string `json:"site"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "message": "Invalid request", "error_code": "VALIDATION_ERROR"})
		return
	}
	v, err := h.service.AddAllowedSite(c.Request.Context(), orgID, req.Site)
	if err != nil {
		h.fail(c, err, "Failed to save")
		return
	}
	c.JSON(http.StatusOK, gin.H{"success": true, "data": gin.H{"site": v}, "message": "Saved"})
}

func (h *MarcoGroupHandler) RemoveAllowed(c *gin.Context) {
	orgID, ok := h.orgID(c)
	if !ok {
		return
	}
	if err := h.service.RemoveAllowedSite(c.Request.Context(), orgID, c.Param("domain")); err != nil {
		h.fail(c, err, "Failed to save")
		return
	}
	c.JSON(http.StatusOK, gin.H{"success": true, "message": "Saved"})
}

func (h *MarcoGroupHandler) ListOverrides(c *gin.Context) {
	orgID, ok := h.orgID(c)
	if !ok {
		return
	}
	list, err := h.service.ListOverrides(c.Request.Context(), orgID)
	if err != nil {
		h.fail(c, err, "Failed to load device controls")
		return
	}
	c.JSON(http.StatusOK, gin.H{"success": true, "data": list, "dry_run": h.service.DryRun(), "message": "Device controls retrieved"})
}

// SetOverride blocks a device or limits its speed.
func (h *MarcoGroupHandler) SetOverride(c *gin.Context) {
	orgID, ok := h.orgID(c)
	if !ok {
		return
	}
	var req services.DeviceControlInput
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "message": "Invalid request", "error_code": "VALIDATION_ERROR"})
		return
	}
	if err := h.service.SetDeviceControl(c.Request.Context(), orgID, c.Param("mac"), req); err != nil {
		h.fail(c, err, "Failed to save")
		return
	}
	c.JSON(http.StatusOK, gin.H{"success": true, "dry_run": h.service.DryRun(), "message": "Saved"})
}

func (h *MarcoGroupHandler) DeleteOverride(c *gin.Context) {
	orgID, ok := h.orgID(c)
	if !ok {
		return
	}
	if err := h.service.SetDeviceControl(c.Request.Context(), orgID, c.Param("mac"), services.DeviceControlInput{}); err != nil {
		h.fail(c, err, "Failed to save")
		return
	}
	c.JSON(http.StatusOK, gin.H{"success": true, "dry_run": h.service.DryRun(), "message": "Saved"})
}

// Details returns one group with its devices, rules in plain words and recent changes.
func (h *MarcoGroupHandler) Details(c *gin.Context) {
	orgID, ok := h.orgID(c)
	if !ok {
		return
	}
	id, err := uuid.Parse(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "message": "Invalid group ID", "error_code": "VALIDATION_ERROR"})
		return
	}
	det, err := h.service.Details(c.Request.Context(), orgID, id)
	if err != nil {
		c.JSON(http.StatusNotFound, gin.H{"success": false, "message": "Group not found", "error_code": "NOT_FOUND"})
		return
	}
	c.JSON(http.StatusOK, gin.H{"success": true, "data": det, "message": "Group retrieved"})
}

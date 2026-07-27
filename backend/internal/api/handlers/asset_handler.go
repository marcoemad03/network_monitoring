package handlers

import (
	"errors"
	"net/http"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
	"github.com/hospital/nms-backend/internal/models"
	"github.com/hospital/nms-backend/internal/services"
)

type AssetHandler struct {
	assetService      *services.AssetService
	policySyncService *services.PolicySyncService
}

func NewAssetHandler(assetService *services.AssetService, policySyncService *services.PolicySyncService) *AssetHandler {
	return &AssetHandler{
		assetService:      assetService,
		policySyncService: policySyncService,
	}
}

func (h *AssetHandler) ListGroups(c *gin.Context) {
	orgID, err := parseUUID(c.GetString("org_id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "message": "Invalid organization ID", "error_code": "VALIDATION_ERROR"})
		return
	}
	groups, err := h.assetService.ListGroups(c.Request.Context(), orgID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"success": false, "message": "Failed to fetch groups", "error_code": "SERVER_ERROR"})
		return
	}
	if groups == nil {
		groups = []models.DeviceGroup{}
	}
	c.JSON(http.StatusOK, gin.H{"success": true, "data": groups, "message": "Groups retrieved"})
}

func (h *AssetHandler) GetGroup(c *gin.Context) {
	id, err := uuid.Parse(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "message": "Invalid group ID", "error_code": "VALIDATION_ERROR"})
		return
	}
	group, err := h.assetService.GetGroup(c.Request.Context(), id)
	if err != nil {
		c.JSON(http.StatusNotFound, gin.H{"success": false, "message": "Group not found", "error_code": "NOT_FOUND"})
		return
	}
	c.JSON(http.StatusOK, gin.H{"success": true, "data": group, "message": "Group retrieved"})
}

func (h *AssetHandler) CreateGroup(c *gin.Context) {
	orgID, err := parseUUID(c.GetString("org_id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "message": "Invalid organization ID", "error_code": "VALIDATION_ERROR"})
		return
	}
	var req struct {
		Name          string     `json:"name" binding:"required"`
		Description   *string    `json:"description"`
		ParentGroupID *uuid.UUID `json:"parent_group_id"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "message": "Invalid request body", "error_code": "VALIDATION_ERROR"})
		return
	}
	group := &models.DeviceGroup{
		OrganizationID: orgID,
		Name:           req.Name,
		Description:    req.Description,
		ParentGroupID:  req.ParentGroupID,
	}
	if err := h.assetService.CreateGroup(c.Request.Context(), group); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"success": false, "message": "Failed to create group", "error_code": "SERVER_ERROR"})
		return
	}
	c.JSON(http.StatusCreated, gin.H{"success": true, "data": group, "message": "Group created"})
}

func (h *AssetHandler) UpdateGroup(c *gin.Context) {
	id, err := uuid.Parse(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "message": "Invalid group ID", "error_code": "VALIDATION_ERROR"})
		return
	}
	var req struct {
		Name          string     `json:"name" binding:"required"`
		Description   *string    `json:"description"`
		ParentGroupID *uuid.UUID `json:"parent_group_id"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "message": "Invalid request body", "error_code": "VALIDATION_ERROR"})
		return
	}
	group, err := h.assetService.GetGroup(c.Request.Context(), id)
	if err != nil {
		c.JSON(http.StatusNotFound, gin.H{"success": false, "message": "Group not found", "error_code": "NOT_FOUND"})
		return
	}
	group.Name = req.Name
	group.Description = req.Description
	group.ParentGroupID = req.ParentGroupID
	if err := h.assetService.UpdateGroup(c.Request.Context(), group); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"success": false, "message": "Failed to update group", "error_code": "SERVER_ERROR"})
		return
	}
	c.JSON(http.StatusOK, gin.H{"success": true, "data": group, "message": "Group updated"})
}

func (h *AssetHandler) DeleteGroup(c *gin.Context) {
	id, err := uuid.Parse(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "message": "Invalid group ID", "error_code": "VALIDATION_ERROR"})
		return
	}
	if err := h.assetService.DeleteGroup(c.Request.Context(), id); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"success": false, "message": "Failed to delete group", "error_code": "SERVER_ERROR"})
		return
	}
	c.JSON(http.StatusOK, gin.H{"success": true, "message": "Group deleted"})
}

func (h *AssetHandler) AssignDevicesToGroup(c *gin.Context) {
	groupID, err := uuid.Parse(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "message": "Invalid group ID", "error_code": "VALIDATION_ERROR"})
		return
	}
	var req struct {
		DeviceIDs []uuid.UUID `json:"device_ids" binding:"required"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "message": "Invalid request body", "error_code": "VALIDATION_ERROR"})
		return
	}
	if err := h.assetService.AssignDevicesToGroup(c.Request.Context(), groupID, req.DeviceIDs); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"success": false, "message": "Failed to assign devices", "error_code": "SERVER_ERROR"})
		return
	}
	c.JSON(http.StatusOK, gin.H{"success": true, "message": "Devices assigned to group"})
}

func (h *AssetHandler) RemoveDeviceFromGroup(c *gin.Context) {
	groupID, err := uuid.Parse(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "message": "Invalid group ID", "error_code": "VALIDATION_ERROR"})
		return
	}
	deviceID, err := uuid.Parse(c.Param("deviceId"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "message": "Invalid device ID", "error_code": "VALIDATION_ERROR"})
		return
	}
	if err := h.assetService.RemoveDeviceFromGroup(c.Request.Context(), groupID, deviceID); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"success": false, "message": "Failed to remove device from group", "error_code": "SERVER_ERROR"})
		return
	}
	c.JSON(http.StatusOK, gin.H{"success": true, "message": "Device removed from group"})
}

func (h *AssetHandler) GetGroupDevices(c *gin.Context) {
	groupID, err := uuid.Parse(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "message": "Invalid group ID", "error_code": "VALIDATION_ERROR"})
		return
	}
	deviceIDs, err := h.assetService.GetGroupDevices(c.Request.Context(), groupID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"success": false, "message": "Failed to fetch group devices", "error_code": "SERVER_ERROR"})
		return
	}
	if deviceIDs == nil {
		deviceIDs = []uuid.UUID{}
	}
	c.JSON(http.StatusOK, gin.H{"success": true, "data": deviceIDs, "message": "Group devices retrieved"})
}

func (h *AssetHandler) ListGroupsForDevice(c *gin.Context) {
	deviceID, err := uuid.Parse(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "message": "Invalid device ID", "error_code": "VALIDATION_ERROR"})
		return
	}
	groups, err := h.assetService.ListGroupsForDevice(c.Request.Context(), deviceID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"success": false, "message": "Failed to fetch groups for device", "error_code": "SERVER_ERROR"})
		return
	}
	if groups == nil {
		groups = []models.DeviceGroup{}
	}
	c.JSON(http.StatusOK, gin.H{"success": true, "data": groups, "message": "Groups for device retrieved"})
}

func (h *AssetHandler) ListFloorMaps(c *gin.Context) {
	orgID, err := parseUUID(c.GetString("org_id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "message": "Invalid organization ID", "error_code": "VALIDATION_ERROR"})
		return
	}
	maps, err := h.assetService.ListFloorMaps(c.Request.Context(), orgID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"success": false, "message": "Failed to fetch floor maps", "error_code": "SERVER_ERROR"})
		return
	}
	if maps == nil {
		maps = []models.FloorMap{}
	}
	c.JSON(http.StatusOK, gin.H{"success": true, "data": maps, "message": "Floor maps retrieved"})
}

func (h *AssetHandler) GetFloorMap(c *gin.Context) {
	id, err := uuid.Parse(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "message": "Invalid floor map ID", "error_code": "VALIDATION_ERROR"})
		return
	}
	fm, err := h.assetService.GetFloorMap(c.Request.Context(), id)
	if err != nil {
		c.JSON(http.StatusNotFound, gin.H{"success": false, "message": "Floor map not found", "error_code": "NOT_FOUND"})
		return
	}
	c.JSON(http.StatusOK, gin.H{"success": true, "data": fm, "message": "Floor map retrieved"})
}

func (h *AssetHandler) CreateFloorMap(c *gin.Context) {
	orgID, err := parseUUID(c.GetString("org_id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "message": "Invalid organization ID", "error_code": "VALIDATION_ERROR"})
		return
	}
	var req struct {
		Name      string `json:"name" binding:"required"`
		ImagePath string `json:"image_path"`
		Width     int    `json:"width"`
		Height    int    `json:"height"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "message": "Invalid request body", "error_code": "VALIDATION_ERROR"})
		return
	}
	if req.Width <= 0 {
		req.Width = 1000
	}
	if req.Height <= 0 {
		req.Height = 800
	}
	if req.ImagePath == "" {
		req.ImagePath = "default.png"
	}
	fm := &models.FloorMap{
		OrganizationID: orgID,
		Name:           req.Name,
		ImagePath:      req.ImagePath,
		Width:          req.Width,
		Height:         req.Height,
	}
	if err := h.assetService.CreateFloorMap(c.Request.Context(), fm); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"success": false, "message": "Failed to create floor map", "error_code": "SERVER_ERROR"})
		return
	}
	c.JSON(http.StatusCreated, gin.H{"success": true, "data": fm, "message": "Floor map created"})
}

func (h *AssetHandler) UpdateFloorMap(c *gin.Context) {
	id, err := uuid.Parse(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "message": "Invalid floor map ID", "error_code": "VALIDATION_ERROR"})
		return
	}
	var req struct {
		Name      string `json:"name" binding:"required"`
		ImagePath string `json:"image_path"`
		Width     int    `json:"width"`
		Height    int    `json:"height"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "message": "Invalid request body", "error_code": "VALIDATION_ERROR"})
		return
	}
	fm, err := h.assetService.GetFloorMap(c.Request.Context(), id)
	if err != nil {
		c.JSON(http.StatusNotFound, gin.H{"success": false, "message": "Floor map not found", "error_code": "NOT_FOUND"})
		return
	}
	fm.Name = req.Name
	if req.ImagePath != "" {
		fm.ImagePath = req.ImagePath
	}
	if req.Width > 0 {
		fm.Width = req.Width
	}
	if req.Height > 0 {
		fm.Height = req.Height
	}
	if err := h.assetService.UpdateFloorMap(c.Request.Context(), fm); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"success": false, "message": "Failed to update floor map", "error_code": "SERVER_ERROR"})
		return
	}
	c.JSON(http.StatusOK, gin.H{"success": true, "data": fm, "message": "Floor map updated"})
}

func (h *AssetHandler) DeleteFloorMap(c *gin.Context) {
	id, err := uuid.Parse(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "message": "Invalid floor map ID", "error_code": "VALIDATION_ERROR"})
		return
	}
	if err := h.assetService.DeleteFloorMap(c.Request.Context(), id); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"success": false, "message": "Failed to delete floor map", "error_code": "SERVER_ERROR"})
		return
	}
	c.JSON(http.StatusOK, gin.H{"success": true, "message": "Floor map deleted"})
}

func (h *AssetHandler) PlaceDeviceOnMap(c *gin.Context) {
	var req struct {
		FloorMapID uuid.UUID `json:"floor_map_id" binding:"required"`
		DeviceID   uuid.UUID `json:"device_id" binding:"required"`
		XCoord     float64   `json:"x_coord" binding:"required"`
		YCoord     float64   `json:"y_coord" binding:"required"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "message": "Invalid request body", "error_code": "VALIDATION_ERROR"})
		return
	}
	fmd := &models.FloorMapDevice{
		FloorMapID: req.FloorMapID,
		DeviceID:   req.DeviceID,
		XCoord:     req.XCoord,
		YCoord:     req.YCoord,
	}
	if err := h.assetService.PlaceDeviceOnMap(c.Request.Context(), fmd); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"success": false, "message": "Failed to place device on map", "error_code": "SERVER_ERROR"})
		return
	}
	c.JSON(http.StatusOK, gin.H{"success": true, "data": fmd, "message": "Device placed on map"})
}

func (h *AssetHandler) RemoveDeviceFromMap(c *gin.Context) {
	floorMapID, err := uuid.Parse(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "message": "Invalid floor map ID", "error_code": "VALIDATION_ERROR"})
		return
	}
	deviceID, err := uuid.Parse(c.Param("deviceId"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "message": "Invalid device ID", "error_code": "VALIDATION_ERROR"})
		return
	}
	if err := h.assetService.RemoveDeviceFromMap(c.Request.Context(), floorMapID, deviceID); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"success": false, "message": "Failed to remove device from map", "error_code": "SERVER_ERROR"})
		return
	}
	c.JSON(http.StatusOK, gin.H{"success": true, "message": "Device removed from map"})
}

func (h *AssetHandler) GetFloorMapDevices(c *gin.Context) {
	floorMapID, err := uuid.Parse(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "message": "Invalid floor map ID", "error_code": "VALIDATION_ERROR"})
		return
	}
	devices, err := h.assetService.GetFloorMapDevices(c.Request.Context(), floorMapID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"success": false, "message": "Failed to fetch floor map devices", "error_code": "SERVER_ERROR"})
		return
	}
	if devices == nil {
		devices = []models.FloorMapDeviceView{}
	}
	c.JSON(http.StatusOK, gin.H{"success": true, "data": devices, "message": "Floor map devices retrieved"})
}

func (h *AssetHandler) UpsertAssetDetail(c *gin.Context) {
	var req struct {
		DeviceID      uuid.UUID  `json:"device_id" binding:"required"`
		Department    *string    `json:"department"`
		FloorName     *string    `json:"floor_name"`
		Room          *string    `json:"room"`
		SwitchPort    *string    `json:"switch_port"`
		AccessPointID *uuid.UUID `json:"access_point_id"`
		Notes         *string    `json:"notes"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "message": "Invalid request body", "error_code": "VALIDATION_ERROR"})
		return
	}
	a := &models.AssetDetail{
		DeviceID:      req.DeviceID,
		Department:    req.Department,
		FloorName:     req.FloorName,
		Room:          req.Room,
		SwitchPort:    req.SwitchPort,
		AccessPointID: req.AccessPointID,
		Notes:         req.Notes,
	}
	if err := h.assetService.UpsertAssetDetail(c.Request.Context(), a); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"success": false, "message": "Failed to save asset detail", "error_code": "SERVER_ERROR"})
		return
	}
	c.JSON(http.StatusOK, gin.H{"success": true, "data": a, "message": "Asset detail saved"})
}

func (h *AssetHandler) GetAssetDetail(c *gin.Context) {
	deviceIDStr := c.Param("id")
	if deviceIDStr == "" {
		deviceIDStr = c.Param("deviceId")
	}
	deviceID, err := uuid.Parse(deviceIDStr)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "message": "Invalid device ID", "error_code": "VALIDATION_ERROR"})
		return
	}
	detail, err := h.assetService.GetAssetDetail(c.Request.Context(), deviceID)
	if err != nil {
		c.JSON(http.StatusNotFound, gin.H{"success": false, "message": "Asset detail not found", "error_code": "NOT_FOUND"})
		return
	}
	c.JSON(http.StatusOK, gin.H{"success": true, "data": detail, "message": "Asset detail retrieved"})
}

func (h *AssetHandler) ListAssetDetails(c *gin.Context) {
	orgID, err := parseUUID(c.GetString("org_id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "message": "Invalid organization ID", "error_code": "VALIDATION_ERROR"})
		return
	}
	details, err := h.assetService.ListAssetDetails(c.Request.Context(), orgID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"success": false, "message": "Failed to fetch asset details", "error_code": "SERVER_ERROR"})
		return
	}
	if details == nil {
		details = []models.AssetDetail{}
	}
	c.JSON(http.StatusOK, gin.H{"success": true, "data": details, "message": "Asset details retrieved"})
}

func (h *AssetHandler) ListPolicies(c *gin.Context) {
	orgID, err := parseUUID(c.GetString("org_id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "message": "Invalid organization ID", "error_code": "VALIDATION_ERROR"})
		return
	}
	policies, err := h.assetService.ListPolicies(c.Request.Context(), orgID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"success": false, "message": "Failed to fetch policies", "error_code": "SERVER_ERROR"})
		return
	}
	if policies == nil {
		policies = []models.Policy{}
	}
	c.JSON(http.StatusOK, gin.H{"success": true, "data": policies, "message": "Policies retrieved"})
}

func (h *AssetHandler) GetPolicy(c *gin.Context) {
	id, err := uuid.Parse(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "message": "Invalid policy ID", "error_code": "VALIDATION_ERROR"})
		return
	}
	p, err := h.assetService.GetPolicy(c.Request.Context(), id)
	if err != nil {
		c.JSON(http.StatusNotFound, gin.H{"success": false, "message": "Policy not found", "error_code": "NOT_FOUND"})
		return
	}
	c.JSON(http.StatusOK, gin.H{"success": true, "data": p, "message": "Policy retrieved"})
}

func (h *AssetHandler) CreatePolicy(c *gin.Context) {
	orgID, err := parseUUID(c.GetString("org_id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "message": "Invalid organization ID", "error_code": "VALIDATION_ERROR"})
		return
	}
	var req struct {
		Name        string                 `json:"name" binding:"required"`
		Description *string                `json:"description"`
		PolicyType  string                 `json:"policy_type" binding:"required"`
		Config      map[string]interface{} `json:"config"`
		IsActive    *bool                  `json:"is_active"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "message": "Invalid request body", "error_code": "VALIDATION_ERROR"})
		return
	}
	if req.Config == nil {
		req.Config = make(map[string]interface{})
	}
	isActive := true
	if req.IsActive != nil {
		isActive = *req.IsActive
	}
	p := &models.Policy{
		OrganizationID: orgID,
		Name:           req.Name,
		Description:    req.Description,
		PolicyType:     req.PolicyType,
		Config:         req.Config,
		IsActive:       isActive,
	}
	if err := h.assetService.CreatePolicy(c.Request.Context(), p); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"success": false, "message": "Failed to create policy", "error_code": "SERVER_ERROR"})
		return
	}
	if err := h.policySyncService.SyncPoliciesToMikroTik(c.Request.Context(), orgID); err != nil {
		if !errors.Is(err, services.ErrPolicyUnsupported) {
			c.JSON(http.StatusInternalServerError, gin.H{"success": true, "data": p, "message": "Policy created but enforcement sync failed: " + err.Error(), "error_code": "POLICY_SYNC_ERROR"})
			return
		}
	}
	c.JSON(http.StatusCreated, gin.H{"success": true, "data": p, "message": "Policy created"})
}

func (h *AssetHandler) UpdatePolicy(c *gin.Context) {
	id, err := uuid.Parse(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "message": "Invalid policy ID", "error_code": "VALIDATION_ERROR"})
		return
	}
	var req struct {
		Name        string                 `json:"name" binding:"required"`
		Description *string                `json:"description"`
		PolicyType  string                 `json:"policy_type"`
		Config      map[string]interface{} `json:"config"`
		IsActive    *bool                  `json:"is_active"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "message": "Invalid request body", "error_code": "VALIDATION_ERROR"})
		return
	}
	p, err := h.assetService.GetPolicy(c.Request.Context(), id)
	if err != nil {
		c.JSON(http.StatusNotFound, gin.H{"success": false, "message": "Policy not found", "error_code": "NOT_FOUND"})
		return
	}
	orgID := p.OrganizationID
	p.Name = req.Name
	if req.Description != nil {
		p.Description = req.Description
	}
	if req.PolicyType != "" {
		p.PolicyType = req.PolicyType
	}
	if req.Config != nil {
		p.Config = req.Config
	}
	if req.IsActive != nil {
		p.IsActive = *req.IsActive
	}
	if err := h.assetService.UpdatePolicy(c.Request.Context(), p); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"success": false, "message": "Failed to update policy", "error_code": "SERVER_ERROR"})
		return
	}
	if err := h.policySyncService.SyncPoliciesToMikroTik(c.Request.Context(), orgID); err != nil {
		if !errors.Is(err, services.ErrPolicyUnsupported) {
			c.JSON(http.StatusInternalServerError, gin.H{"success": true, "data": p, "message": "Policy updated but enforcement sync failed: " + err.Error(), "error_code": "POLICY_SYNC_ERROR"})
			return
		}
	}
	c.JSON(http.StatusOK, gin.H{"success": true, "data": p, "message": "Policy updated"})
}

func (h *AssetHandler) DeletePolicy(c *gin.Context) {
	id, err := uuid.Parse(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "message": "Invalid policy ID", "error_code": "VALIDATION_ERROR"})
		return
	}
	orgID, err2 := parseUUID(c.GetString("org_id"))
	if err2 != nil {
		if p, err3 := h.assetService.GetPolicy(c.Request.Context(), id); err3 == nil {
			orgID = p.OrganizationID
		}
	}
	if err := h.assetService.DeletePolicy(c.Request.Context(), id); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"success": false, "message": "Failed to delete policy", "error_code": "SERVER_ERROR"})
		return
	}
	if orgID != uuid.Nil {
		if err := h.policySyncService.SyncPoliciesToMikroTik(c.Request.Context(), orgID); err != nil {
			if !errors.Is(err, services.ErrPolicyUnsupported) {
				c.JSON(http.StatusInternalServerError, gin.H{"success": true, "message": "Policy deleted but enforcement sync failed: " + err.Error(), "error_code": "POLICY_SYNC_ERROR"})
				return
			}
		}
	}
	c.JSON(http.StatusOK, gin.H{"success": true, "message": "Policy deleted"})
}

func (h *AssetHandler) AssignPolicyToGroup(c *gin.Context) {
	policyID, err := uuid.Parse(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "message": "Invalid policy ID", "error_code": "VALIDATION_ERROR"})
		return
	}
	var req struct {
		GroupID uuid.UUID `json:"group_id" binding:"required"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "message": "Invalid request body", "error_code": "VALIDATION_ERROR"})
		return
	}
	if err := h.assetService.AssignPolicyToGroup(c.Request.Context(), policyID, req.GroupID); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"success": false, "message": "Failed to assign policy to group", "error_code": "SERVER_ERROR"})
		return
	}
	policy, err := h.assetService.GetPolicy(c.Request.Context(), policyID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"success": false, "message": "Policy assigned but synchronization could not resolve the organization", "error_code": "POLICY_SYNC_ERROR"})
		return
	}
	if err := h.policySyncService.SyncPoliciesToMikroTik(c.Request.Context(), policy.OrganizationID); err != nil {
		status, code := http.StatusInternalServerError, "POLICY_SYNC_ERROR"
		if errors.Is(err, services.ErrPolicyUnsupported) {
			status, code = http.StatusUnprocessableEntity, "POLICY_UNSUPPORTED"
		}
		c.JSON(status, gin.H{"success": false, "message": "Policy assigned but enforcement failed: " + err.Error(), "error_code": code})
		return
	}
	c.JSON(http.StatusOK, gin.H{"success": true, "message": "Policy assigned to group"})
}

func (h *AssetHandler) RemovePolicyFromGroup(c *gin.Context) {
	policyID, err := uuid.Parse(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "message": "Invalid policy ID", "error_code": "VALIDATION_ERROR"})
		return
	}
	groupID, err := uuid.Parse(c.Param("groupId"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "message": "Invalid group ID", "error_code": "VALIDATION_ERROR"})
		return
	}
	if err := h.assetService.RemovePolicyFromGroup(c.Request.Context(), policyID, groupID); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"success": false, "message": "Failed to remove policy from group", "error_code": "SERVER_ERROR"})
		return
	}
	policy, err := h.assetService.GetPolicy(c.Request.Context(), policyID)
	if err == nil {
		if err := h.policySyncService.SyncPoliciesToMikroTik(c.Request.Context(), policy.OrganizationID); err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"success": false, "message": "Policy removed but enforcement failed: " + err.Error(), "error_code": "POLICY_SYNC_ERROR"})
			return
		}
	}
	c.JSON(http.StatusOK, gin.H{"success": true, "message": "Policy removed from group"})
}

func (h *AssetHandler) GetPoliciesForGroup(c *gin.Context) {
	groupID, err := uuid.Parse(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "message": "Invalid group ID", "error_code": "VALIDATION_ERROR"})
		return
	}
	policies, err := h.assetService.GetPoliciesForGroup(c.Request.Context(), groupID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"success": false, "message": "Failed to fetch policies for group", "error_code": "SERVER_ERROR"})
		return
	}
	if policies == nil {
		policies = []models.Policy{}
	}
	c.JSON(http.StatusOK, gin.H{"success": true, "data": policies, "message": "Policies for group retrieved"})
}

func (h *AssetHandler) SyncPolicies(c *gin.Context) {
	orgID, err := parseUUID(c.GetString("org_id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "message": "Invalid organization ID", "error_code": "VALIDATION_ERROR"})
		return
	}
	if err := h.policySyncService.SyncPoliciesToMikroTik(c.Request.Context(), orgID); err != nil {
		status := http.StatusInternalServerError
		code := "POLICY_SYNC_ERROR"
		if errors.Is(err, services.ErrPolicyUnsupported) {
			status = http.StatusUnprocessableEntity
			code = "POLICY_UNSUPPORTED"
		}
		c.JSON(status, gin.H{"success": false, "message": err.Error(), "error_code": code})
		return
	}
	c.JSON(http.StatusOK, gin.H{"success": true, "message": "Policies synchronized"})
}

func (h *AssetHandler) ListSyncLogs(c *gin.Context) {
	orgID, err := parseUUID(c.GetString("org_id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "message": "Invalid organization ID", "error_code": "VALIDATION_ERROR"})
		return
	}
	logs, err := h.assetService.ListSyncLogs(c.Request.Context(), orgID, 50)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"success": false, "message": "Failed to fetch sync logs", "error_code": "SERVER_ERROR"})
		return
	}
	if logs == nil {
		logs = []models.SyncLog{}
	}
	c.JSON(http.StatusOK, gin.H{"success": true, "data": logs, "message": "Sync logs retrieved"})
}

package handlers

import (
	"net/http"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
	"github.com/hospital/nms-backend/internal/models"
	"github.com/hospital/nms-backend/internal/services"
)

type InternetHandler struct {
	internetService *services.InternetService
}

func NewInternetHandler(internetService *services.InternetService) *InternetHandler {
	return &InternetHandler{internetService: internetService}
}

// InternetPolicies

func (h *InternetHandler) ListPolicies(c *gin.Context) {
	orgID, err := parseUUID(c.GetString("org_id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "message": "Invalid organization ID", "error_code": "VALIDATION_ERROR"})
		return
	}

	policies, err := h.internetService.ListPolicies(c.Request.Context(), orgID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"success": false, "message": "Failed to list internet policies", "error_code": "SERVER_ERROR"})
		return
	}
	if policies == nil {
		policies = []models.InternetPolicy{}
	}
	c.JSON(http.StatusOK, gin.H{"success": true, "data": policies, "message": "Internet policies retrieved"})
}

func (h *InternetHandler) GetPolicy(c *gin.Context) {
	id, err := uuid.Parse(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "message": "Invalid policy ID", "error_code": "VALIDATION_ERROR"})
		return
	}

	policy, err := h.internetService.GetPolicyByID(c.Request.Context(), id)
	if err != nil {
		c.JSON(http.StatusNotFound, gin.H{"success": false, "message": "Internet policy not found", "error_code": "NOT_FOUND"})
		return
	}
	c.JSON(http.StatusOK, gin.H{"success": true, "data": policy, "message": "Internet policy retrieved"})
}

func (h *InternetHandler) CreatePolicy(c *gin.Context) {
	orgID, err := parseUUID(c.GetString("org_id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "message": "Invalid organization ID", "error_code": "VALIDATION_ERROR"})
		return
	}

	var req struct {
		Name            string     `json:"name"`
		Description     *string    `json:"description,omitempty"`
		Department      *string    `json:"department,omitempty"`
		IsActive        *bool      `json:"is_active"`
		UploadLimitBps  *int64     `json:"upload_limit_bps,omitempty"`
		DownloadLimitBps *int64    `json:"download_limit_bps,omitempty"`
		PolicyType      string     `json:"policy_type"`
		Priority        *int       `json:"priority"`
		CreatedBy       *uuid.UUID `json:"created_by,omitempty"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "message": "Invalid request body", "error_code": "VALIDATION_ERROR"})
		return
	}

	policy := &models.InternetPolicy{
		OrganizationID:  orgID,
		Name:            req.Name,
		Description:     req.Description,
		Department:      req.Department,
		PolicyType:      req.PolicyType,
		CreatedBy:       req.CreatedBy,
	}
	if req.IsActive != nil {
		policy.IsActive = *req.IsActive
	} else {
		policy.IsActive = true
	}
	if req.Priority != nil {
		policy.Priority = *req.Priority
	} else {
		policy.Priority = 500
	}
	policy.UploadLimitBps = req.UploadLimitBps
	policy.DownloadLimitBps = req.DownloadLimitBps

	if err := h.internetService.CreatePolicy(c.Request.Context(), policy); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"success": false, "message": "Failed to create internet policy", "error_code": "SERVER_ERROR"})
		return
	}
	c.JSON(http.StatusCreated, gin.H{"success": true, "data": policy, "message": "Internet policy created"})
}

func (h *InternetHandler) UpdatePolicy(c *gin.Context) {
	id, err := uuid.Parse(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "message": "Invalid policy ID", "error_code": "VALIDATION_ERROR"})
		return
	}

	existing, err := h.internetService.GetPolicyByID(c.Request.Context(), id)
	if err != nil {
		c.JSON(http.StatusNotFound, gin.H{"success": false, "message": "Internet policy not found", "error_code": "NOT_FOUND"})
		return
	}

	var req struct {
		Name            *string  `json:"name,omitempty"`
		Description     *string  `json:"description,omitempty"`
		Department      *string  `json:"department,omitempty"`
		IsActive        *bool    `json:"is_active,omitempty"`
		UploadLimitBps  *int64   `json:"upload_limit_bps,omitempty"`
		DownloadLimitBps *int64  `json:"download_limit_bps,omitempty"`
		PolicyType      *string  `json:"policy_type,omitempty"`
		Priority        *int     `json:"priority,omitempty"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "message": "Invalid request body", "error_code": "VALIDATION_ERROR"})
		return
	}

	if req.Name != nil {
		existing.Name = *req.Name
	}
	if req.Description != nil {
		existing.Description = req.Description
	}
	if req.Department != nil {
		existing.Department = req.Department
	}
	if req.IsActive != nil {
		existing.IsActive = *req.IsActive
	}
	if req.UploadLimitBps != nil {
		existing.UploadLimitBps = req.UploadLimitBps
	}
	if req.DownloadLimitBps != nil {
		existing.DownloadLimitBps = req.DownloadLimitBps
	}
	if req.PolicyType != nil {
		existing.PolicyType = *req.PolicyType
	}
	if req.Priority != nil {
		existing.Priority = *req.Priority
	}

	if err := h.internetService.UpdatePolicy(c.Request.Context(), existing); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"success": false, "message": "Failed to update internet policy", "error_code": "SERVER_ERROR"})
		return
	}
	c.JSON(http.StatusOK, gin.H{"success": true, "data": existing, "message": "Internet policy updated"})
}

func (h *InternetHandler) DeletePolicy(c *gin.Context) {
	id, err := uuid.Parse(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "message": "Invalid policy ID", "error_code": "VALIDATION_ERROR"})
		return
	}

	if err := h.internetService.DeletePolicy(c.Request.Context(), id); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"success": false, "message": "Failed to delete internet policy", "error_code": "SERVER_ERROR"})
		return
	}
	c.JSON(http.StatusOK, gin.H{"success": true, "message": "Internet policy deleted"})
}

// BandwidthRules

func (h *InternetHandler) ListBandwidthRules(c *gin.Context) {
	policyID, err := uuid.Parse(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "message": "Invalid policy ID", "error_code": "VALIDATION_ERROR"})
		return
	}

	rules, err := h.internetService.ListBandwidthRulesByPolicy(c.Request.Context(), policyID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"success": false, "message": "Failed to list bandwidth rules", "error_code": "SERVER_ERROR"})
		return
	}
	if rules == nil {
		rules = []models.BandwidthRule{}
	}
	c.JSON(http.StatusOK, gin.H{"success": true, "data": rules, "message": "Bandwidth rules retrieved"})
}

func (h *InternetHandler) CreateBandwidthRule(c *gin.Context) {
	policyID, err := uuid.Parse(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "message": "Invalid policy ID", "error_code": "VALIDATION_ERROR"})
		return
	}

	var req struct {
		DeviceID         *uuid.UUID `json:"device_id,omitempty"`
		UserID           *uuid.UUID `json:"user_id,omitempty"`
		Priority         *int       `json:"priority"`
		UploadLimitBps   *int64     `json:"upload_limit_bps,omitempty"`
		DownloadLimitBps *int64     `json:"download_limit_bps,omitempty"`
		RuleType         string     `json:"rule_type"`
		IsTemporary      *bool      `json:"is_temporary"`
		TempExpiresAt    *time.Time `json:"temp_expires_at,omitempty"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "message": "Invalid request body", "error_code": "VALIDATION_ERROR"})
		return
	}

	rule := &models.BandwidthRule{
		PolicyID:         policyID,
		DeviceID:         req.DeviceID,
		UserID:           req.UserID,
		RuleType:         req.RuleType,
		UploadLimitBps:   req.UploadLimitBps,
		DownloadLimitBps: req.DownloadLimitBps,
		TempExpiresAt:    req.TempExpiresAt,
		IsActive:         true,
	}
	if req.Priority != nil {
		rule.Priority = *req.Priority
	} else {
		rule.Priority = 500
	}
	if req.IsTemporary != nil {
		rule.IsTemporary = *req.IsTemporary
	}

	if err := h.internetService.CreateBandwidthRule(c.Request.Context(), rule); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"success": false, "message": "Failed to create bandwidth rule", "error_code": "SERVER_ERROR"})
		return
	}
	c.JSON(http.StatusCreated, gin.H{"success": true, "data": rule, "message": "Bandwidth rule created"})
}

func (h *InternetHandler) UpdateBandwidthRule(c *gin.Context) {
	id, err := uuid.Parse(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "message": "Invalid rule ID", "error_code": "VALIDATION_ERROR"})
		return
	}

	var req struct {
		DeviceID         *uuid.UUID  `json:"device_id,omitempty"`
		UserID           *uuid.UUID  `json:"user_id,omitempty"`
		Priority         *int        `json:"priority,omitempty"`
		UploadLimitBps   *int64      `json:"upload_limit_bps,omitempty"`
		DownloadLimitBps *int64      `json:"download_limit_bps,omitempty"`
		RuleType         *string     `json:"rule_type,omitempty"`
		IsTemporary      *bool       `json:"is_temporary,omitempty"`
		TempExpiresAt    *time.Time  `json:"temp_expires_at,omitempty"`
		IsActive         *bool       `json:"is_active,omitempty"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "message": "Invalid request body", "error_code": "VALIDATION_ERROR"})
		return
	}

	rule := &models.BandwidthRule{ID: id}
	if req.DeviceID != nil {
		rule.DeviceID = req.DeviceID
	}
	if req.UserID != nil {
		rule.UserID = req.UserID
	}
	if req.Priority != nil {
		rule.Priority = *req.Priority
	}
	if req.UploadLimitBps != nil {
		rule.UploadLimitBps = req.UploadLimitBps
	}
	if req.DownloadLimitBps != nil {
		rule.DownloadLimitBps = req.DownloadLimitBps
	}
	if req.RuleType != nil {
		rule.RuleType = *req.RuleType
	}
	if req.IsTemporary != nil {
		rule.IsTemporary = *req.IsTemporary
	}
	if req.TempExpiresAt != nil {
		rule.TempExpiresAt = req.TempExpiresAt
	}
	if req.IsActive != nil {
		rule.IsActive = *req.IsActive
	}

	if err := h.internetService.UpdateBandwidthRule(c.Request.Context(), rule); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"success": false, "message": "Failed to update bandwidth rule", "error_code": "SERVER_ERROR"})
		return
	}
	c.JSON(http.StatusOK, gin.H{"success": true, "data": rule, "message": "Bandwidth rule updated"})
}

func (h *InternetHandler) DeleteBandwidthRule(c *gin.Context) {
	id, err := uuid.Parse(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "message": "Invalid rule ID", "error_code": "VALIDATION_ERROR"})
		return
	}

	if err := h.internetService.DeleteBandwidthRule(c.Request.Context(), id); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"success": false, "message": "Failed to delete bandwidth rule", "error_code": "SERVER_ERROR"})
		return
	}
	c.JSON(http.StatusOK, gin.H{"success": true, "message": "Bandwidth rule deleted"})
}

func (h *InternetHandler) SetTemporaryBandwidth(c *gin.Context) {
	id, err := uuid.Parse(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "message": "Invalid rule ID", "error_code": "VALIDATION_ERROR"})
		return
	}

	var req struct {
		UploadLimitBps   *int64     `json:"upload_limit_bps,omitempty"`
		DownloadLimitBps *int64     `json:"download_limit_bps,omitempty"`
		ExpiresAt        time.Time  `json:"expires_at"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "message": "Invalid request body", "error_code": "VALIDATION_ERROR"})
		return
	}

	if err := h.internetService.SetTemporaryBandwidth(c.Request.Context(), id, req.UploadLimitBps, req.DownloadLimitBps, req.ExpiresAt); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"success": false, "message": "Failed to set temporary bandwidth", "error_code": "SERVER_ERROR"})
		return
	}
	c.JSON(http.StatusOK, gin.H{"success": true, "message": "Temporary bandwidth set"})
}

func (h *InternetHandler) ClearTemporaryBandwidth(c *gin.Context) {
	id, err := uuid.Parse(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "message": "Invalid rule ID", "error_code": "VALIDATION_ERROR"})
		return
	}

	if err := h.internetService.ClearTemporaryBandwidth(c.Request.Context(), id); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"success": false, "message": "Failed to clear temporary bandwidth", "error_code": "SERVER_ERROR"})
		return
	}
	c.JSON(http.StatusOK, gin.H{"success": true, "message": "Temporary bandwidth cleared"})
}

// FilteringRules

func (h *InternetHandler) ListFilteringRules(c *gin.Context) {
	policyID, err := uuid.Parse(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "message": "Invalid policy ID", "error_code": "VALIDATION_ERROR"})
		return
	}

	rules, err := h.internetService.ListFilteringRulesByPolicy(c.Request.Context(), policyID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"success": false, "message": "Failed to list filtering rules", "error_code": "SERVER_ERROR"})
		return
	}
	if rules == nil {
		rules = []models.FilteringRule{}
	}
	c.JSON(http.StatusOK, gin.H{"success": true, "data": rules, "message": "Filtering rules retrieved"})
}

func (h *InternetHandler) CreateFilteringRule(c *gin.Context) {
	policyID, err := uuid.Parse(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "message": "Invalid policy ID", "error_code": "VALIDATION_ERROR"})
		return
	}

	var req struct {
		RuleType    string  `json:"rule_type"`
		FilterType  string  `json:"filter_type"`
		Value       string  `json:"value"`
		Description *string `json:"description,omitempty"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "message": "Invalid request body", "error_code": "VALIDATION_ERROR"})
		return
	}

	rule := &models.FilteringRule{
		PolicyID:    policyID,
		RuleType:    req.RuleType,
		FilterType:  req.FilterType,
		Value:       req.Value,
		Description: req.Description,
		IsActive:    true,
	}

	if err := h.internetService.CreateFilteringRule(c.Request.Context(), rule); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"success": false, "message": "Failed to create filtering rule", "error_code": "SERVER_ERROR"})
		return
	}
	c.JSON(http.StatusCreated, gin.H{"success": true, "data": rule, "message": "Filtering rule created"})
}

func (h *InternetHandler) UpdateFilteringRule(c *gin.Context) {
	id, err := uuid.Parse(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "message": "Invalid rule ID", "error_code": "VALIDATION_ERROR"})
		return
	}

	var req struct {
		RuleType    *string `json:"rule_type,omitempty"`
		FilterType  *string `json:"filter_type,omitempty"`
		Value       *string `json:"value,omitempty"`
		Description *string `json:"description,omitempty"`
		IsActive    *bool   `json:"is_active,omitempty"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "message": "Invalid request body", "error_code": "VALIDATION_ERROR"})
		return
	}

	rule := &models.FilteringRule{ID: id}
	if req.RuleType != nil {
		rule.RuleType = *req.RuleType
	}
	if req.FilterType != nil {
		rule.FilterType = *req.FilterType
	}
	if req.Value != nil {
		rule.Value = *req.Value
	}
	if req.Description != nil {
		rule.Description = req.Description
	}
	if req.IsActive != nil {
		rule.IsActive = *req.IsActive
	}

	if err := h.internetService.UpdateFilteringRule(c.Request.Context(), rule); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"success": false, "message": "Failed to update filtering rule", "error_code": "SERVER_ERROR"})
		return
	}
	c.JSON(http.StatusOK, gin.H{"success": true, "data": rule, "message": "Filtering rule updated"})
}

func (h *InternetHandler) DeleteFilteringRule(c *gin.Context) {
	id, err := uuid.Parse(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "message": "Invalid rule ID", "error_code": "VALIDATION_ERROR"})
		return
	}

	if err := h.internetService.DeleteFilteringRule(c.Request.Context(), id); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"success": false, "message": "Failed to delete filtering rule", "error_code": "SERVER_ERROR"})
		return
	}
	c.JSON(http.StatusOK, gin.H{"success": true, "message": "Filtering rule deleted"})
}

// TimeSchedules

func (h *InternetHandler) ListSchedules(c *gin.Context) {
	policyID, err := uuid.Parse(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "message": "Invalid policy ID", "error_code": "VALIDATION_ERROR"})
		return
	}

	schedules, err := h.internetService.ListSchedulesByPolicy(c.Request.Context(), policyID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"success": false, "message": "Failed to list schedules", "error_code": "SERVER_ERROR"})
		return
	}
	if schedules == nil {
		schedules = []models.TimeSchedule{}
	}
	c.JSON(http.StatusOK, gin.H{"success": true, "data": schedules, "message": "Schedules retrieved"})
}

func (h *InternetHandler) CreateSchedule(c *gin.Context) {
	policyID, err := uuid.Parse(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "message": "Invalid policy ID", "error_code": "VALIDATION_ERROR"})
		return
	}

	var req struct {
		DayOfWeek int    `json:"day_of_week"`
		StartTime string `json:"start_time"`
		EndTime   string `json:"end_time"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "message": "Invalid request body", "error_code": "VALIDATION_ERROR"})
		return
	}

	schedule := &models.TimeSchedule{
		PolicyID:  policyID,
		DayOfWeek: req.DayOfWeek,
		StartTime: req.StartTime,
		EndTime:   req.EndTime,
		IsActive:  true,
	}

	if err := h.internetService.CreateSchedule(c.Request.Context(), schedule); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"success": false, "message": "Failed to create schedule", "error_code": "SERVER_ERROR"})
		return
	}
	c.JSON(http.StatusCreated, gin.H{"success": true, "data": schedule, "message": "Schedule created"})
}

func (h *InternetHandler) UpdateSchedule(c *gin.Context) {
	id, err := uuid.Parse(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "message": "Invalid schedule ID", "error_code": "VALIDATION_ERROR"})
		return
	}

	var req struct {
		DayOfWeek *int    `json:"day_of_week,omitempty"`
		StartTime *string `json:"start_time,omitempty"`
		EndTime   *string `json:"end_time,omitempty"`
		IsActive  *bool   `json:"is_active,omitempty"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "message": "Invalid request body", "error_code": "VALIDATION_ERROR"})
		return
	}

	schedule := &models.TimeSchedule{ID: id}
	if req.DayOfWeek != nil {
		schedule.DayOfWeek = *req.DayOfWeek
	}
	if req.StartTime != nil {
		schedule.StartTime = *req.StartTime
	}
	if req.EndTime != nil {
		schedule.EndTime = *req.EndTime
	}
	if req.IsActive != nil {
		schedule.IsActive = *req.IsActive
	}

	if err := h.internetService.UpdateSchedule(c.Request.Context(), schedule); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"success": false, "message": "Failed to update schedule", "error_code": "SERVER_ERROR"})
		return
	}
	c.JSON(http.StatusOK, gin.H{"success": true, "data": schedule, "message": "Schedule updated"})
}

func (h *InternetHandler) DeleteSchedule(c *gin.Context) {
	id, err := uuid.Parse(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "message": "Invalid schedule ID", "error_code": "VALIDATION_ERROR"})
		return
	}

	if err := h.internetService.DeleteSchedule(c.Request.Context(), id); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"success": false, "message": "Failed to delete schedule", "error_code": "SERVER_ERROR"})
		return
	}
	c.JSON(http.StatusOK, gin.H{"success": true, "message": "Schedule deleted"})
}

// DeviceBlocks

func (h *InternetHandler) ListDeviceBlocks(c *gin.Context) {
	orgID, err := parseUUID(c.GetString("org_id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "message": "Invalid organization ID", "error_code": "VALIDATION_ERROR"})
		return
	}

	blocks, err := h.internetService.ListDeviceBlocks(c.Request.Context(), orgID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"success": false, "message": "Failed to list device blocks", "error_code": "SERVER_ERROR"})
		return
	}
	if blocks == nil {
		blocks = []models.DeviceBlock{}
	}
	c.JSON(http.StatusOK, gin.H{"success": true, "data": blocks, "message": "Device blocks retrieved"})
}

func (h *InternetHandler) BlockDevice(c *gin.Context) {
	orgID, err := parseUUID(c.GetString("org_id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "message": "Invalid organization ID", "error_code": "VALIDATION_ERROR"})
		return
	}
	userID, err := parseUUID(c.GetString("user_id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "message": "Invalid user ID", "error_code": "VALIDATION_ERROR"})
		return
	}

	var req struct {
		DeviceID   *uuid.UUID `json:"device_id,omitempty"`
		MACAddress *string    `json:"mac_address,omitempty"`
		IPAddress  *string    `json:"ip_address,omitempty"`
		Reason     *string    `json:"reason,omitempty"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "message": "Invalid request body", "error_code": "VALIDATION_ERROR"})
		return
	}

	block := &models.DeviceBlock{
		OrgID:      orgID,
		DeviceID:   req.DeviceID,
		MACAddress: req.MACAddress,
		IPAddress:  req.IPAddress,
		Reason:     req.Reason,
		BlockedBy:  &userID,
		IsActive:   true,
	}

	if err := h.internetService.CreateDeviceBlock(c.Request.Context(), block); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"success": false, "message": "Failed to block device", "error_code": "SERVER_ERROR"})
		return
	}
	c.JSON(http.StatusCreated, gin.H{"success": true, "data": block, "message": "Device blocked"})
}

func (h *InternetHandler) UnblockDevice(c *gin.Context) {
	id, err := uuid.Parse(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "message": "Invalid block ID", "error_code": "VALIDATION_ERROR"})
		return
	}

	if err := h.internetService.UnblockDevice(c.Request.Context(), id); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"success": false, "message": "Failed to unblock device", "error_code": "SERVER_ERROR"})
		return
	}
	c.JSON(http.StatusOK, gin.H{"success": true, "message": "Device unblocked"})
}

// VendorIntegrations

func (h *InternetHandler) ListVendorIntegrations(c *gin.Context) {
	orgID, err := parseUUID(c.GetString("org_id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "message": "Invalid organization ID", "error_code": "VALIDATION_ERROR"})
		return
	}

	integrations, err := h.internetService.ListVendorIntegrations(c.Request.Context(), orgID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"success": false, "message": "Failed to list vendor integrations", "error_code": "SERVER_ERROR"})
		return
	}
	if integrations == nil {
		integrations = []models.VendorIntegration{}
	}
	c.JSON(http.StatusOK, gin.H{"success": true, "data": integrations, "message": "Vendor integrations retrieved"})
}

func (h *InternetHandler) GetVendorIntegration(c *gin.Context) {
	id, err := uuid.Parse(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "message": "Invalid integration ID", "error_code": "VALIDATION_ERROR"})
		return
	}

	integration, err := h.internetService.GetVendorIntegrationByID(c.Request.Context(), id)
	if err != nil {
		c.JSON(http.StatusNotFound, gin.H{"success": false, "message": "Vendor integration not found", "error_code": "NOT_FOUND"})
		return
	}
	c.JSON(http.StatusOK, gin.H{"success": true, "data": integration, "message": "Vendor integration retrieved"})
}

func (h *InternetHandler) CreateVendorIntegration(c *gin.Context) {
	orgID, err := parseUUID(c.GetString("org_id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "message": "Invalid organization ID", "error_code": "VALIDATION_ERROR"})
		return
	}

	var req struct {
		VendorType        string  `json:"vendor_type"`
		Name              string  `json:"name"`
		BaseURL           string  `json:"base_url"`
		Username          *string `json:"username,omitempty"`
		EncryptedPassword *string `json:"encrypted_password,omitempty"`
		APIKey            *string `json:"api_key,omitempty"`
		APIVersion        *string `json:"api_version,omitempty"`
		IsActive          *bool   `json:"is_active"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "message": "Invalid request body", "error_code": "VALIDATION_ERROR"})
		return
	}

	integration := &models.VendorIntegration{
		OrgID:             orgID,
		VendorType:        req.VendorType,
		Name:              req.Name,
		BaseURL:           req.BaseURL,
		Username:          req.Username,
		EncryptedPassword: req.EncryptedPassword,
		APIKey:            req.APIKey,
		APIVersion:        req.APIVersion,
	}
	if req.IsActive != nil {
		integration.IsActive = *req.IsActive
	} else {
		integration.IsActive = true
	}

	if err := h.internetService.CreateVendorIntegration(c.Request.Context(), integration); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"success": false, "message": "Failed to create vendor integration", "error_code": "SERVER_ERROR"})
		return
	}
	c.JSON(http.StatusCreated, gin.H{"success": true, "data": integration, "message": "Vendor integration created"})
}

func (h *InternetHandler) UpdateVendorIntegration(c *gin.Context) {
	id, err := uuid.Parse(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "message": "Invalid integration ID", "error_code": "VALIDATION_ERROR"})
		return
	}

	existing, err := h.internetService.GetVendorIntegrationByID(c.Request.Context(), id)
	if err != nil {
		c.JSON(http.StatusNotFound, gin.H{"success": false, "message": "Vendor integration not found", "error_code": "NOT_FOUND"})
		return
	}

	var req struct {
		VendorType        *string `json:"vendor_type,omitempty"`
		Name              *string `json:"name,omitempty"`
		BaseURL           *string `json:"base_url,omitempty"`
		Username          *string `json:"username,omitempty"`
		EncryptedPassword *string `json:"encrypted_password,omitempty"`
		APIKey            *string `json:"api_key,omitempty"`
		APIVersion        *string `json:"api_version,omitempty"`
		IsActive          *bool   `json:"is_active,omitempty"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "message": "Invalid request body", "error_code": "VALIDATION_ERROR"})
		return
	}

	if req.VendorType != nil {
		existing.VendorType = *req.VendorType
	}
	if req.Name != nil {
		existing.Name = *req.Name
	}
	if req.BaseURL != nil {
		existing.BaseURL = *req.BaseURL
	}
	if req.Username != nil {
		existing.Username = req.Username
	}
	if req.EncryptedPassword != nil {
		existing.EncryptedPassword = req.EncryptedPassword
	}
	if req.APIKey != nil {
		existing.APIKey = req.APIKey
	}
	if req.APIVersion != nil {
		existing.APIVersion = req.APIVersion
	}
	if req.IsActive != nil {
		existing.IsActive = *req.IsActive
	}

	if err := h.internetService.UpdateVendorIntegration(c.Request.Context(), existing); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"success": false, "message": "Failed to update vendor integration", "error_code": "SERVER_ERROR"})
		return
	}
	c.JSON(http.StatusOK, gin.H{"success": true, "data": existing, "message": "Vendor integration updated"})
}

func (h *InternetHandler) DeleteVendorIntegration(c *gin.Context) {
	id, err := uuid.Parse(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "message": "Invalid integration ID", "error_code": "VALIDATION_ERROR"})
		return
	}

	if err := h.internetService.DeleteVendorIntegration(c.Request.Context(), id); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"success": false, "message": "Failed to delete vendor integration", "error_code": "SERVER_ERROR"})
		return
	}
	c.JSON(http.StatusOK, gin.H{"success": true, "message": "Vendor integration deleted"})
}

func (h *InternetHandler) TestVendorConnection(c *gin.Context) {
	id, err := uuid.Parse(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "message": "Invalid integration ID", "error_code": "VALIDATION_ERROR"})
		return
	}

	_, err = h.internetService.GetVendorIntegrationByID(c.Request.Context(), id)
	if err != nil {
		c.JSON(http.StatusNotFound, gin.H{"success": false, "message": "Vendor integration not found", "error_code": "NOT_FOUND"})
		return
	}

	c.JSON(http.StatusOK, gin.H{"success": true, "message": "Connection test initiated"})
}

func (h *InternetHandler) SyncVendor(c *gin.Context) {
	id, err := uuid.Parse(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "message": "Invalid integration ID", "error_code": "VALIDATION_ERROR"})
		return
	}

	_, err = h.internetService.GetVendorIntegrationByID(c.Request.Context(), id)
	if err != nil {
		c.JSON(http.StatusNotFound, gin.H{"success": false, "message": "Vendor integration not found", "error_code": "NOT_FOUND"})
		return
	}

	if err := h.internetService.UpdateVendorSyncStatus(c.Request.Context(), id, "syncing", time.Now(), nil); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"success": false, "message": "Failed to start sync", "error_code": "SERVER_ERROR"})
		return
	}

	c.JSON(http.StatusOK, gin.H{"success": true, "message": "Sync initiated"})
}

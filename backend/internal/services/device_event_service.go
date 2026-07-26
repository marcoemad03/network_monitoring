package services

import (
	"context"
	"time"

	"github.com/google/uuid"
	"github.com/hospital/nms-backend/internal/models"
	"github.com/hospital/nms-backend/internal/repository"
)

type DeviceEventService struct {
	eventRepo    *repository.DeviceEventRepository
	deviceRepo   *repository.DeviceRepository
	alertRepo    *repository.AlertRepository
}

func NewDeviceEventService(eventRepo *repository.DeviceEventRepository, deviceRepo *repository.DeviceRepository, alertRepo *repository.AlertRepository) *DeviceEventService {
	return &DeviceEventService{
		eventRepo:  eventRepo,
		deviceRepo: deviceRepo,
		alertRepo:  alertRepo,
	}
}

func (s *DeviceEventService) LogEvent(ctx context.Context, orgID, deviceID uuid.UUID, eventType string, eventData map[string]interface{}, prevVal, newVal string) error {
	event := &models.DeviceEvent{
		ID:             uuid.New(),
		OrganizationID: orgID,
		DeviceID:       deviceID,
		EventType:      eventType,
		EventData:      eventData,
		PreviousValue:  prevVal,
		NewValue:       newVal,
	}
	return s.eventRepo.CreateEvent(ctx, event)
}

func (s *DeviceEventService) LogConnection(ctx context.Context, orgID, deviceID uuid.UUID) error {
	return s.LogEvent(ctx, orgID, deviceID, "connection", nil, "", "online")
}

func (s *DeviceEventService) LogDisconnection(ctx context.Context, orgID, deviceID uuid.UUID) error {
	return s.LogEvent(ctx, orgID, deviceID, "disconnection", nil, "online", "offline")
}

func (s *DeviceEventService) LogIPChange(ctx context.Context, orgID, deviceID uuid.UUID, oldIP, newIP string) error {
	return s.LogEvent(ctx, orgID, deviceID, "ip_change", nil, oldIP, newIP)
}

func (s *DeviceEventService) LogGroupChange(ctx context.Context, orgID, deviceID uuid.UUID, oldGroup, newGroup string) error {
	return s.LogEvent(ctx, orgID, deviceID, "group_change", nil, oldGroup, newGroup)
}

func (s *DeviceEventService) LogPolicyChange(ctx context.Context, orgID, deviceID uuid.UUID, policyName string) error {
	return s.LogEvent(ctx, orgID, deviceID, "policy_change", map[string]interface{}{
		"policy": policyName,
	}, "", "")
}

func (s *DeviceEventService) LogBandwidthUsage(ctx context.Context, orgID, deviceID uuid.UUID, downloadBps, uploadBps int64) error {
	return s.LogEvent(ctx, orgID, deviceID, "bandwidth", map[string]interface{}{
		"download_bps": downloadBps,
		"upload_bps":   uploadBps,
	}, "", "")
}

func (s *DeviceEventService) LogInternetBlock(ctx context.Context, orgID, deviceID uuid.UUID, reason string) error {
	return s.LogEvent(ctx, orgID, deviceID, "internet_block", map[string]interface{}{
		"reason": reason,
	}, "unblocked", "blocked")
}

func (s *DeviceEventService) LogWebsiteBlock(ctx context.Context, orgID, deviceID uuid.UUID, url, category string) error {
	return s.LogEvent(ctx, orgID, deviceID, "website_block", map[string]interface{}{
		"url":      url,
		"category": category,
	}, "", "")
}

func (s *DeviceEventService) LogAdminAction(ctx context.Context, orgID, deviceID uuid.UUID, action string, detail map[string]interface{}) error {
	return s.LogEvent(ctx, orgID, deviceID, "admin_action", detail, "", action)
}

func (s *DeviceEventService) GetDeviceEvents(ctx context.Context, orgID, deviceID uuid.UUID, eventType string, from, to time.Time, limit, offset int) ([]models.DeviceEvent, int, error) {
	if limit <= 0 {
		limit = 50
	}
	return s.eventRepo.ListEvents(ctx, orgID, deviceID, eventType, from, to, limit, offset)
}

func (s *DeviceEventService) GetDeviceEventSummary(ctx context.Context, orgID, deviceID uuid.UUID) (*models.DeviceEventSummary, error) {
	return s.eventRepo.GetEventSummary(ctx, orgID, deviceID)
}

func (s *DeviceEventService) GetOrganizationEvents(ctx context.Context, orgID uuid.UUID, eventType string, from, to time.Time, limit, offset int) ([]models.DeviceEvent, int, error) {
	if limit <= 0 {
		limit = 50
	}
	var zeroUUID uuid.UUID
	return s.eventRepo.ListEvents(ctx, orgID, zeroUUID, eventType, from, to, limit, offset)
}

package services

import (
	"context"
	"time"

	"github.com/google/uuid"
	"github.com/hospital/nms-backend/internal/models"
	"github.com/hospital/nms-backend/internal/repository"
)

type DeviceService struct {
	deviceRepo *repository.DeviceRepository
	alertRepo  *repository.AlertRepository
	auditRepo  *repository.AuditRepository
}

func NewDeviceService(deviceRepo *repository.DeviceRepository, alertRepo *repository.AlertRepository, auditRepo *repository.AuditRepository) *DeviceService {
	return &DeviceService{
		deviceRepo: deviceRepo,
		alertRepo:  alertRepo,
		auditRepo:  auditRepo,
	}
}

func (s *DeviceService) List(ctx context.Context, orgID uuid.UUID, page, limit int, search, status, deviceType, department, sortBy string, ascending bool) ([]models.Device, int, error) {
	return s.deviceRepo.List(ctx, orgID, page, limit, search, status, deviceType, department, sortBy, ascending)
}

func (s *DeviceService) GetByID(ctx context.Context, id uuid.UUID) (*models.Device, error) {
	return s.deviceRepo.GetByID(ctx, id)
}

func (s *DeviceService) Create(ctx context.Context, device *models.Device, userID uuid.UUID) error {
	device.ID = uuid.New()
	device.FirstSeen = time.Now()
	device.LastSeen = time.Now()
	device.CreatedAt = time.Now()
	device.UpdatedAt = time.Now()

	if device.Status == "" {
		device.Status = "unknown"
	}
	if device.DeviceType == "" {
		device.DeviceType = "unknown"
	}

	return s.deviceRepo.Create(ctx, device)
}

func (s *DeviceService) Update(ctx context.Context, device *models.Device, userID uuid.UUID) error {
	existing, err := s.deviceRepo.GetByID(ctx, device.ID)
	if err != nil {
		return err
	}

	device.OrganizationID = existing.OrganizationID
	device.CreatedAt = existing.CreatedAt
	device.FirstSeen = existing.FirstSeen
	device.LastSeen = time.Now()

	return s.deviceRepo.Update(ctx, device)
}

func (s *DeviceService) Delete(ctx context.Context, id, userID uuid.UUID) error {
	_, err := s.deviceRepo.GetByID(ctx, id)
	if err != nil {
		return err
	}
	return s.deviceRepo.Delete(ctx, id)
}

func (s *DeviceService) GetInterfaces(ctx context.Context, deviceID uuid.UUID) ([]models.Interface, error) {
	return s.deviceRepo.GetInterfaces(ctx, deviceID)
}

func (s *DeviceService) GetMetrics(ctx context.Context, deviceID uuid.UUID) (*models.DeviceMetrics, error) {
	return s.deviceRepo.GetMetrics(ctx, deviceID)
}

func (s *DeviceService) GetStatusSummary(ctx context.Context, orgID uuid.UUID) (map[string]int, error) {
	return s.deviceRepo.CountByStatus(ctx, orgID)
}

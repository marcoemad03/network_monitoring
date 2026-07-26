package services

import (
	"context"
	"fmt"
	"time"

	"github.com/google/uuid"
	"github.com/hospital/nms-backend/internal/models"
	"github.com/hospital/nms-backend/internal/repository"
)

type DeviceControlService struct {
	deviceRepo    *repository.DeviceRepository
	deviceCtrlRepo *repository.DeviceControlRepository
	monRepo       *repository.MonitoringRepository
	auditRepo     *repository.AuditRepository
}

func NewDeviceControlService(deviceRepo *repository.DeviceRepository, deviceCtrlRepo *repository.DeviceControlRepository, monRepo *repository.MonitoringRepository, auditRepo *repository.AuditRepository) *DeviceControlService {
	return &DeviceControlService{
		deviceRepo:    deviceRepo,
		deviceCtrlRepo: deviceCtrlRepo,
		monRepo:       monRepo,
		auditRepo:     auditRepo,
	}
}

func (s *DeviceControlService) DisconnectDevice(ctx context.Context, deviceID, orgID, userID uuid.UUID) error {
	return s.logControlAction(ctx, deviceID, orgID, &userID, "disconnect", "", nil)
}

func (s *DeviceControlService) ReconnectDevice(ctx context.Context, deviceID, orgID, userID uuid.UUID) error {
	return s.logControlAction(ctx, deviceID, orgID, &userID, "reconnect", "", nil)
}

func (s *DeviceControlService) BlockInternet(ctx context.Context, deviceID, orgID, userID uuid.UUID) error {
	device, err := s.deviceRepo.GetByID(ctx, deviceID)
	if err != nil {
		return fmt.Errorf("device not found: %w", err)
	}
	device.Status = "blocked"
	if err := s.deviceRepo.Update(ctx, device); err != nil {
		return err
	}
	return s.logControlAction(ctx, deviceID, orgID, &userID, "block_internet", "", nil)
}

func (s *DeviceControlService) UnblockInternet(ctx context.Context, deviceID, orgID, userID uuid.UUID) error {
	device, err := s.deviceRepo.GetByID(ctx, deviceID)
	if err != nil {
		return fmt.Errorf("device not found: %w", err)
	}
	if device.Status == "blocked" {
		device.Status = "online"
	}
	if err := s.deviceRepo.Update(ctx, device); err != nil {
		return err
	}
	return s.logControlAction(ctx, deviceID, orgID, &userID, "unblock_internet", "", nil)
}

func (s *DeviceControlService) LimitSpeed(ctx context.Context, deviceID, orgID, userID uuid.UUID, downloadLimit, uploadLimit int64) error {
	detail := fmt.Sprintf("download=%d, upload=%d", downloadLimit, uploadLimit)
	if err := s.deviceCtrlRepo.SetDeviceSpeedLimit(ctx, deviceID, downloadLimit, uploadLimit); err != nil {
		return err
	}
	return s.logControlAction(ctx, deviceID, orgID, &userID, "limit_speed", detail, nil)
}

func (s *DeviceControlService) UnlimitedSpeed(ctx context.Context, deviceID, orgID, userID uuid.UUID) error {
	if err := s.deviceCtrlRepo.RemoveDeviceSpeedLimit(ctx, deviceID); err != nil {
		return err
	}
	return s.logControlAction(ctx, deviceID, orgID, &userID, "unlimited_speed", "", nil)
}

func (s *DeviceControlService) RenameDevice(ctx context.Context, deviceID, orgID, userID uuid.UUID, newName string) error {
	device, err := s.deviceRepo.GetByID(ctx, deviceID)
	if err != nil {
		return err
	}
	oldName := device.Name
	device.Name = newName
	if err := s.deviceRepo.Update(ctx, device); err != nil {
		return err
	}
	return s.logControlAction(ctx, deviceID, orgID, &userID, "rename", oldName+" -> "+newName, nil)
}

func (s *DeviceControlService) ChangeDepartment(ctx context.Context, deviceID, orgID, userID uuid.UUID, department string) error {
	device, err := s.deviceRepo.GetByID(ctx, deviceID)
	if err != nil {
		return err
	}
	device.Department = &department
	return s.deviceRepo.Update(ctx, device)
}

func (s *DeviceControlService) ChangeRoom(ctx context.Context, deviceID, orgID, userID uuid.UUID, room string) error {
	device, err := s.deviceRepo.GetByID(ctx, deviceID)
	if err != nil {
		return err
	}
	device.Room = room
	return s.deviceRepo.Update(ctx, device)
}

func (s *DeviceControlService) MoveToGroup(ctx context.Context, deviceID, groupID, orgID, userID uuid.UUID) error {
	detail := fmt.Sprintf("moved to group %s", groupID)
	return s.logControlAction(ctx, deviceID, orgID, &userID, "move_group", detail, nil)
}

func (s *DeviceControlService) PinDevice(ctx context.Context, deviceID, orgID, userID uuid.UUID) error {
	device, err := s.deviceRepo.GetByID(ctx, deviceID)
	if err != nil {
		return err
	}
	device.IsPinned = true
	return s.deviceRepo.Update(ctx, device)
}

func (s *DeviceControlService) UnpinDevice(ctx context.Context, deviceID, orgID, userID uuid.UUID) error {
	device, err := s.deviceRepo.GetByID(ctx, deviceID)
	if err != nil {
		return err
	}
	device.IsPinned = false
	return s.deviceRepo.Update(ctx, device)
}

func (s *DeviceControlService) MarkCritical(ctx context.Context, deviceID, orgID, userID uuid.UUID) error {
	device, err := s.deviceRepo.GetByID(ctx, deviceID)
	if err != nil {
		return err
	}
	device.IsCritical = true
	return s.deviceRepo.Update(ctx, device)
}

func (s *DeviceControlService) UnmarkCritical(ctx context.Context, deviceID, orgID, userID uuid.UUID) error {
	device, err := s.deviceRepo.GetByID(ctx, deviceID)
	if err != nil {
		return err
	}
	device.IsCritical = false
	return s.deviceRepo.Update(ctx, device)
}

func (s *DeviceControlService) AddNotes(ctx context.Context, deviceID, orgID, userID uuid.UUID, notes string) error {
	device, err := s.deviceRepo.GetByID(ctx, deviceID)
	if err != nil {
		return err
	}
	device.Notes = &notes
	return s.deviceRepo.Update(ctx, device)
}

func (s *DeviceControlService) ViewHistory(ctx context.Context, deviceID, orgID uuid.UUID, limit int) ([]models.DeviceControlLog, error) {
	if limit <= 0 {
		limit = 50
	}
	return s.deviceCtrlRepo.GetDeviceLogs(ctx, deviceID, limit)
}

func (s *DeviceControlService) ReserveDHCPIP(ctx context.Context, deviceID, orgID, userID uuid.UUID, ipAddress, macAddress string) error {
	return s.logControlAction(ctx, deviceID, orgID, &userID, "reserve_dhcp", ipAddress, nil)
}

func (s *DeviceControlService) CreateStaticDHCPLease(ctx context.Context, deviceID, orgID, userID uuid.UUID, ipAddress, macAddress, hostname string) error {
	return s.logControlAction(ctx, deviceID, orgID, &userID, "static_dhcp_lease", fmt.Sprintf("%s/%s", ipAddress, macAddress), nil)
}

func (s *DeviceControlService) ViewActiveConnections(ctx context.Context, deviceID, orgID uuid.UUID) ([]models.DeviceConnection, error) {
	if s.monRepo == nil {
		return nil, fmt.Errorf("monitoring repository not available")
	}
	return s.monRepo.GetConnections(ctx, orgID)
}

func (s *DeviceControlService) ViewCurrentBandwidth(ctx context.Context, deviceID, orgID uuid.UUID) (*models.DeviceMetrics, error) {
	if s.monRepo == nil {
		return nil, fmt.Errorf("monitoring repository not available")
	}
	return s.monRepo.GetLatestMetrics(ctx, deviceID)
}

func (s *DeviceControlService) ViewHistoricalUsage(ctx context.Context, deviceID, orgID uuid.UUID, from, to time.Time) ([]models.DeviceTraffic, error) {
	if s.monRepo == nil {
		return nil, fmt.Errorf("monitoring repository not available")
	}
	return s.monRepo.GetTrafficHistory(ctx, deviceID, from, to)
}

func (s *DeviceControlService) logControlAction(ctx context.Context, deviceID, orgID uuid.UUID, userID *uuid.UUID, action, detail string, errVal error) error {
	log := &models.DeviceControlLog{
		ID:             uuid.New(),
		OrganizationID: orgID,
		DeviceID:       deviceID,
		Action:         action,
		ActionDetail:   detail,
		PerformedBy:    userID,
		Result:         "success",
	}
	if errVal != nil {
		log.Result = "failed"
		errMsg := errVal.Error()
		log.ErrorMessage = &errMsg
	}
	return s.deviceCtrlRepo.CreateControlLog(ctx, log)
}

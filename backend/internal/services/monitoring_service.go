package services

import (
	"context"
	"time"

	"github.com/google/uuid"
	"github.com/hospital/nms-backend/internal/models"
	"github.com/hospital/nms-backend/internal/repository"
)

type MonitoringService struct {
	monRepo *repository.MonitoringRepository
	devRepo *repository.DeviceRepository
}

func NewMonitoringService(monRepo *repository.MonitoringRepository, devRepo *repository.DeviceRepository) *MonitoringService {
	return &MonitoringService{monRepo: monRepo, devRepo: devRepo}
}

func (s *MonitoringService) GetDashboardSummary(ctx context.Context, orgID uuid.UUID) (*models.DashboardLiveSummary, error) {
	return s.monRepo.GetDashboardLiveSummary(ctx, orgID)
}

func (s *MonitoringService) GetDeviceClients(ctx context.Context, deviceID uuid.UUID) ([]models.DeviceClient, error) {
	return s.monRepo.GetClientsByDevice(ctx, deviceID)
}

func (s *MonitoringService) GetAllClients(ctx context.Context, orgID uuid.UUID) ([]models.DeviceClient, error) {
	return s.monRepo.GetAllActiveClients(ctx, orgID)
}

func (s *MonitoringService) GetConnections(ctx context.Context, orgID uuid.UUID) ([]models.DeviceConnection, error) {
	return s.monRepo.GetConnections(ctx, orgID)
}

func (s *MonitoringService) GetLatestMetrics(ctx context.Context, deviceID uuid.UUID) (*models.DeviceMetrics, error) {
	return s.monRepo.GetLatestMetrics(ctx, deviceID)
}

func (s *MonitoringService) GetLatestPing(ctx context.Context, deviceID uuid.UUID) (*models.DevicePing, error) {
	return s.monRepo.GetLatestPing(ctx, deviceID)
}

func (s *MonitoringService) GetLatestTraffic(ctx context.Context, deviceID uuid.UUID) (*models.DeviceTraffic, error) {
	return s.monRepo.GetLatestTraffic(ctx, deviceID)
}

func (s *MonitoringService) GetMetricsHistory(ctx context.Context, deviceID uuid.UUID, from, to time.Time) ([]models.DeviceMetrics, error) {
	return s.monRepo.GetMetricsHistory(ctx, deviceID, from, to)
}

func (s *MonitoringService) GetPingHistory(ctx context.Context, deviceID uuid.UUID, from, to time.Time) ([]models.DevicePing, error) {
	return s.monRepo.GetPingHistory(ctx, deviceID, from, to)
}

func (s *MonitoringService) GetTrafficHistory(ctx context.Context, deviceID uuid.UUID, from, to time.Time) ([]models.DeviceTraffic, error) {
	return s.monRepo.GetTrafficHistory(ctx, deviceID, from, to)
}

// EquipmentKinds are the registered device types listed on the Equipment page.
var EquipmentKinds = []string{"router", "switch", "server", "firewall", "access_point", "printer", "medical_device", "camera", "iot"}

// ListEquipment returns the registered equipment with the latest ping of each.
func (s *MonitoringService) ListEquipment(ctx context.Context, orgID uuid.UUID) ([]repository.EquipmentRow, error) {
	return s.monRepo.ListEquipment(ctx, orgID, EquipmentKinds)
}

// MetricsFreshFor is how old a device reading may be and still be shown as current.
const MetricsFreshFor = 15 * time.Minute

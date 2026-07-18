package services

import (
	"context"
	"time"

	"github.com/google/uuid"
	"github.com/hospital/nms-backend/internal/models"
	"github.com/hospital/nms-backend/internal/repository"
)

type InternetService struct {
	repo *repository.InternetRepository
}

func NewInternetService(repo *repository.InternetRepository) *InternetService {
	return &InternetService{repo: repo}
}

// InternetPolicy

func (s *InternetService) CreatePolicy(ctx context.Context, p *models.InternetPolicy) error {
	return s.repo.CreatePolicy(ctx, p)
}

func (s *InternetService) GetPolicyByID(ctx context.Context, id uuid.UUID) (*models.InternetPolicy, error) {
	return s.repo.GetPolicyByID(ctx, id)
}

func (s *InternetService) ListPolicies(ctx context.Context, orgID uuid.UUID) ([]models.InternetPolicy, error) {
	return s.repo.ListPolicies(ctx, orgID)
}

func (s *InternetService) UpdatePolicy(ctx context.Context, p *models.InternetPolicy) error {
	return s.repo.UpdatePolicy(ctx, p)
}

func (s *InternetService) DeletePolicy(ctx context.Context, id uuid.UUID) error {
	return s.repo.DeletePolicy(ctx, id)
}

// BandwidthRule

func (s *InternetService) CreateBandwidthRule(ctx context.Context, b *models.BandwidthRule) error {
	return s.repo.CreateBandwidthRule(ctx, b)
}

func (s *InternetService) ListBandwidthRulesByPolicy(ctx context.Context, policyID uuid.UUID) ([]models.BandwidthRule, error) {
	return s.repo.ListBandwidthRulesByPolicy(ctx, policyID)
}

func (s *InternetService) UpdateBandwidthRule(ctx context.Context, b *models.BandwidthRule) error {
	return s.repo.UpdateBandwidthRule(ctx, b)
}

func (s *InternetService) DeleteBandwidthRule(ctx context.Context, id uuid.UUID) error {
	return s.repo.DeleteBandwidthRule(ctx, id)
}

func (s *InternetService) SetTemporaryBandwidth(ctx context.Context, id uuid.UUID, uploadLimit, downloadLimit *int64, expiresAt time.Time) error {
	return s.repo.SetTemporaryBandwidth(ctx, id, uploadLimit, downloadLimit, expiresAt)
}

func (s *InternetService) ClearTemporaryBandwidth(ctx context.Context, id uuid.UUID) error {
	return s.repo.ClearTemporaryBandwidth(ctx, id)
}

// FilteringRule

func (s *InternetService) CreateFilteringRule(ctx context.Context, f *models.FilteringRule) error {
	return s.repo.CreateFilteringRule(ctx, f)
}

func (s *InternetService) ListFilteringRulesByPolicy(ctx context.Context, policyID uuid.UUID) ([]models.FilteringRule, error) {
	return s.repo.ListFilteringRulesByPolicy(ctx, policyID)
}

func (s *InternetService) UpdateFilteringRule(ctx context.Context, f *models.FilteringRule) error {
	return s.repo.UpdateFilteringRule(ctx, f)
}

func (s *InternetService) DeleteFilteringRule(ctx context.Context, id uuid.UUID) error {
	return s.repo.DeleteFilteringRule(ctx, id)
}

// TimeSchedule

func (s *InternetService) CreateSchedule(ctx context.Context, sc *models.TimeSchedule) error {
	return s.repo.CreateSchedule(ctx, sc)
}

func (s *InternetService) ListSchedulesByPolicy(ctx context.Context, policyID uuid.UUID) ([]models.TimeSchedule, error) {
	return s.repo.ListSchedulesByPolicy(ctx, policyID)
}

func (s *InternetService) UpdateSchedule(ctx context.Context, sc *models.TimeSchedule) error {
	return s.repo.UpdateSchedule(ctx, sc)
}

func (s *InternetService) DeleteSchedule(ctx context.Context, id uuid.UUID) error {
	return s.repo.DeleteSchedule(ctx, id)
}

// DeviceBlock

func (s *InternetService) CreateDeviceBlock(ctx context.Context, b *models.DeviceBlock) error {
	return s.repo.CreateDeviceBlock(ctx, b)
}

func (s *InternetService) ListDeviceBlocks(ctx context.Context, orgID uuid.UUID) ([]models.DeviceBlock, error) {
	return s.repo.ListDeviceBlocks(ctx, orgID)
}

func (s *InternetService) GetDeviceBlockByDevice(ctx context.Context, deviceID uuid.UUID) (*models.DeviceBlock, error) {
	return s.repo.GetDeviceBlockByDevice(ctx, deviceID)
}

func (s *InternetService) GetDeviceBlockByMAC(ctx context.Context, mac string) (*models.DeviceBlock, error) {
	return s.repo.GetDeviceBlockByMAC(ctx, mac)
}

func (s *InternetService) GetDeviceBlockByIP(ctx context.Context, ip string) (*models.DeviceBlock, error) {
	return s.repo.GetDeviceBlockByIP(ctx, ip)
}

func (s *InternetService) UnblockDevice(ctx context.Context, id uuid.UUID) error {
	return s.repo.UnblockDevice(ctx, id)
}

// VendorIntegration

func (s *InternetService) CreateVendorIntegration(ctx context.Context, v *models.VendorIntegration) error {
	return s.repo.CreateVendorIntegration(ctx, v)
}

func (s *InternetService) GetVendorIntegrationByID(ctx context.Context, id uuid.UUID) (*models.VendorIntegration, error) {
	return s.repo.GetVendorIntegrationByID(ctx, id)
}

func (s *InternetService) ListVendorIntegrations(ctx context.Context, orgID uuid.UUID) ([]models.VendorIntegration, error) {
	return s.repo.ListVendorIntegrations(ctx, orgID)
}

func (s *InternetService) UpdateVendorIntegration(ctx context.Context, v *models.VendorIntegration) error {
	return s.repo.UpdateVendorIntegration(ctx, v)
}

func (s *InternetService) DeleteVendorIntegration(ctx context.Context, id uuid.UUID) error {
	return s.repo.DeleteVendorIntegration(ctx, id)
}

func (s *InternetService) UpdateVendorSyncStatus(ctx context.Context, id uuid.UUID, status string, lastSyncAt time.Time, errMsg *string) error {
	return s.repo.UpdateVendorSyncStatus(ctx, id, status, lastSyncAt, errMsg)
}

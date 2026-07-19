package services

import (
	"context"
	"time"

	"github.com/google/uuid"
	"github.com/hospital/nms-backend/internal/models"
	"github.com/hospital/nms-backend/internal/repository"
)

type AssetService struct {
	assetRepo *repository.AssetRepository
}

func NewAssetService(assetRepo *repository.AssetRepository) *AssetService {
	return &AssetService{assetRepo: assetRepo}
}

func (s *AssetService) CreateGroup(ctx context.Context, g *models.DeviceGroup) error {
	g.ID = uuid.New()
	g.CreatedAt = time.Now()
	g.UpdatedAt = time.Now()
	return s.assetRepo.CreateGroup(ctx, g)
}

func (s *AssetService) UpdateGroup(ctx context.Context, g *models.DeviceGroup) error {
	g.UpdatedAt = time.Now()
	return s.assetRepo.UpdateGroup(ctx, g)
}

func (s *AssetService) DeleteGroup(ctx context.Context, id uuid.UUID) error {
	return s.assetRepo.DeleteGroup(ctx, id)
}

func (s *AssetService) GetGroup(ctx context.Context, id uuid.UUID) (*models.DeviceGroup, error) {
	return s.assetRepo.GetGroupByID(ctx, id)
}

func (s *AssetService) ListGroups(ctx context.Context, orgID uuid.UUID) ([]models.DeviceGroup, error) {
	return s.assetRepo.ListGroups(ctx, orgID)
}

func (s *AssetService) AssignDevicesToGroup(ctx context.Context, groupID uuid.UUID, deviceIDs []uuid.UUID) error {
	return s.assetRepo.AssignDevicesToGroup(ctx, groupID, deviceIDs)
}

func (s *AssetService) RemoveDeviceFromGroup(ctx context.Context, groupID, deviceID uuid.UUID) error {
	return s.assetRepo.RemoveDeviceFromGroup(ctx, groupID, deviceID)
}

func (s *AssetService) GetGroupDevices(ctx context.Context, groupID uuid.UUID) ([]uuid.UUID, error) {
	return s.assetRepo.GetGroupDevices(ctx, groupID)
}

func (s *AssetService) ListGroupsForDevice(ctx context.Context, deviceID uuid.UUID) ([]models.DeviceGroup, error) {
	return s.assetRepo.ListGroupsForDevice(ctx, deviceID)
}

func (s *AssetService) CreateFloorMap(ctx context.Context, f *models.FloorMap) error {
	f.ID = uuid.New()
	f.CreatedAt = time.Now()
	f.UpdatedAt = time.Now()
	return s.assetRepo.CreateFloorMap(ctx, f)
}

func (s *AssetService) UpdateFloorMap(ctx context.Context, f *models.FloorMap) error {
	f.UpdatedAt = time.Now()
	return s.assetRepo.UpdateFloorMap(ctx, f)
}

func (s *AssetService) DeleteFloorMap(ctx context.Context, id uuid.UUID) error {
	return s.assetRepo.DeleteFloorMap(ctx, id)
}

func (s *AssetService) GetFloorMap(ctx context.Context, id uuid.UUID) (*models.FloorMap, error) {
	return s.assetRepo.GetFloorMapByID(ctx, id)
}

func (s *AssetService) ListFloorMaps(ctx context.Context, orgID uuid.UUID) ([]models.FloorMap, error) {
	return s.assetRepo.ListFloorMaps(ctx, orgID)
}

func (s *AssetService) PlaceDeviceOnMap(ctx context.Context, fmd *models.FloorMapDevice) error {
	if fmd.ID == uuid.Nil {
		fmd.ID = uuid.New()
	}
	fmd.CreatedAt = time.Now()
	fmd.UpdatedAt = time.Now()
	return s.assetRepo.PlaceDeviceOnMap(ctx, fmd)
}

func (s *AssetService) RemoveDeviceFromMap(ctx context.Context, floorMapID, deviceID uuid.UUID) error {
	return s.assetRepo.RemoveDeviceFromMap(ctx, floorMapID, deviceID)
}

func (s *AssetService) GetFloorMapDevices(ctx context.Context, floorMapID uuid.UUID) ([]models.FloorMapDevice, error) {
	return s.assetRepo.GetFloorMapDevices(ctx, floorMapID)
}

func (s *AssetService) UpsertAssetDetail(ctx context.Context, a *models.AssetDetail) error {
	if a.ID == uuid.Nil {
		a.ID = uuid.New()
	}
	a.CreatedAt = time.Now()
	a.UpdatedAt = time.Now()
	return s.assetRepo.UpsertAssetDetail(ctx, a)
}

func (s *AssetService) GetAssetDetail(ctx context.Context, deviceID uuid.UUID) (*models.AssetDetail, error) {
	return s.assetRepo.GetAssetDetail(ctx, deviceID)
}

func (s *AssetService) ListAssetDetails(ctx context.Context, orgID uuid.UUID) ([]models.AssetDetail, error) {
	return s.assetRepo.ListAssetDetails(ctx, orgID)
}

func (s *AssetService) CreatePolicy(ctx context.Context, p *models.Policy) error {
	p.ID = uuid.New()
	p.CreatedAt = time.Now()
	p.UpdatedAt = time.Now()
	return s.assetRepo.CreatePolicy(ctx, p)
}

func (s *AssetService) UpdatePolicy(ctx context.Context, p *models.Policy) error {
	p.UpdatedAt = time.Now()
	return s.assetRepo.UpdatePolicy(ctx, p)
}

func (s *AssetService) DeletePolicy(ctx context.Context, id uuid.UUID) error {
	return s.assetRepo.DeletePolicy(ctx, id)
}

func (s *AssetService) GetPolicy(ctx context.Context, id uuid.UUID) (*models.Policy, error) {
	return s.assetRepo.GetPolicyByID(ctx, id)
}

func (s *AssetService) ListPolicies(ctx context.Context, orgID uuid.UUID) ([]models.Policy, error) {
	return s.assetRepo.ListPolicies(ctx, orgID)
}

func (s *AssetService) AssignPolicyToGroup(ctx context.Context, policyID, groupID uuid.UUID) error {
	return s.assetRepo.AssignPolicyToGroup(ctx, policyID, groupID)
}

func (s *AssetService) RemovePolicyFromGroup(ctx context.Context, policyID, groupID uuid.UUID) error {
	return s.assetRepo.RemovePolicyFromGroup(ctx, policyID, groupID)
}

func (s *AssetService) GetPoliciesForGroup(ctx context.Context, groupID uuid.UUID) ([]models.Policy, error) {
	return s.assetRepo.GetPoliciesForGroup(ctx, groupID)
}

func (s *AssetService) CreateSyncLog(ctx context.Context, l *models.SyncLog) error {
	l.ID = uuid.New()
	l.CreatedAt = time.Now()
	return s.assetRepo.CreateSyncLog(ctx, l)
}

func (s *AssetService) ListSyncLogs(ctx context.Context, orgID uuid.UUID, limit int) ([]models.SyncLog, error) {
	return s.assetRepo.ListSyncLogs(ctx, orgID, limit)
}

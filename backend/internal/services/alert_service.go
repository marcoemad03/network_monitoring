package services

import (
	"context"

	"github.com/google/uuid"
	"github.com/hospital/nms-backend/internal/models"
	"github.com/hospital/nms-backend/internal/repository"
)

type AlertService struct {
	alertRepo *repository.AlertRepository
}

func NewAlertService(alertRepo *repository.AlertRepository) *AlertService {
	return &AlertService{alertRepo: alertRepo}
}

func (s *AlertService) List(ctx context.Context, orgID uuid.UUID, page, limit int, status, severity, category, deviceID, sortBy string, ascending bool) ([]models.Alert, int, error) {
	return s.alertRepo.List(ctx, orgID, page, limit, status, severity, category, deviceID, sortBy, ascending)
}

func (s *AlertService) GetByID(ctx context.Context, id uuid.UUID) (*models.Alert, error) {
	return s.alertRepo.GetByID(ctx, id)
}

func (s *AlertService) Acknowledge(ctx context.Context, id, userID uuid.UUID, notes string) error {
	return s.alertRepo.Acknowledge(ctx, id, userID, notes)
}

func (s *AlertService) Resolve(ctx context.Context, id, userID uuid.UUID, resolutionNotes string) error {
	return s.alertRepo.Resolve(ctx, id, userID, resolutionNotes)
}

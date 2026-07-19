package services

import (
	"context"
	"fmt"
	"time"

	"github.com/google/uuid"
	"github.com/hospital/nms-backend/internal/config"
	"github.com/hospital/nms-backend/internal/models"
	"github.com/hospital/nms-backend/internal/repository"
	"github.com/hospital/nms-backend/pkg/mikrotik"
)

type PolicySyncService struct {
	assetRepo *repository.AssetRepository
	deviceRepo *repository.DeviceRepository
	cfg       *config.Config
}

func NewPolicySyncService(assetRepo *repository.AssetRepository, deviceRepo *repository.DeviceRepository, cfg *config.Config) *PolicySyncService {
	return &PolicySyncService{
		assetRepo:  assetRepo,
		deviceRepo: deviceRepo,
		cfg:        cfg,
	}
}

func (s *PolicySyncService) SyncPoliciesToMikroTik(ctx context.Context, orgID uuid.UUID, vendor *models.VendorIntegration) error {
	log := &models.SyncLog{
		OrganizationID:      orgID,
		VendorIntegrationID: &vendor.ID,
		Status:              "in_progress",
		Details:             map[string]interface{}{"started_at": time.Now().Format(time.RFC3339)},
	}
	s.assetRepo.CreateSyncLog(ctx, log)

	password := ""
	if vendor.EncryptedPassword != nil {
		password = *vendor.EncryptedPassword
	}
	username := "admin"
	if vendor.Username != nil {
		username = *vendor.Username
	}
	host := extractHost(vendor.BaseURL)

	client := mikrotik.NewClient(host, username, password, s.cfg.MikroTikAPITimeout)

	policies, err := s.assetRepo.ListPolicies(ctx, orgID)
	if err != nil {
		log.Status = "failed"
		log.Details = map[string]interface{}{"error": fmt.Sprintf("list policies: %v", err)}
		s.assetRepo.CreateSyncLog(ctx, log)
		return err
	}

	conn, err := s.dial(client)
	if err != nil {
		log.Status = "failed"
		log.Details = map[string]interface{}{"error": fmt.Sprintf("connect mikrotik: %v", err)}
		s.assetRepo.CreateSyncLog(ctx, log)
		return err
	}
	defer conn.Close()

	pushed := 0
	failed := 0

	for _, p := range policies {
		if !p.IsActive {
			continue
		}
		if err := s.pushPolicy(ctx, conn, &p); err != nil {
			failed++
			continue
		}
		pushed++
	}

	log.Status = "completed"
	log.Details = map[string]interface{}{
		"pushed": pushed,
		"failed": failed,
		"total":  len(policies),
		"completed_at": time.Now().Format(time.RFC3339),
	}
	s.assetRepo.CreateSyncLog(ctx, log)
	return nil
}

func (s *PolicySyncService) dial(client *mikrotik.Client) (*mikrotik.APIConnection, error) {
	conn := mikrotik.NewAPIConnection(client.Host(), 8728, client.Username(), client.Password(), s.cfg.MikroTikAPITimeout)
	if err := conn.Connect(); err != nil {
		return nil, fmt.Errorf("connect: %w", err)
	}
	if err := conn.Login(); err != nil {
		conn.Close()
		return nil, fmt.Errorf("login: %w", err)
	}
	return conn, nil
}

func (s *PolicySyncService) pushPolicy(_ context.Context, conn *mikrotik.APIConnection, p *models.Policy) error {
	switch p.PolicyType {
	case "website_blacklist":
		return s.pushWebsiteBlacklist(conn, p)
	case "website_whitelist":
		return s.pushWebsiteWhitelist(conn, p)
	case "bandwidth_limit", "upload_limit", "download_limit":
		return s.pushBandwidthLimit(conn, p)
	case "internet_access":
		return s.pushInternetAccess(conn, p)
	case "schedule":
		return s.pushSchedule(conn, p)
	}
	return nil
}

func (s *PolicySyncService) pushWebsiteBlacklist(conn *mikrotik.APIConnection, p *models.Policy) error {
	domains, _ := p.Config["domains"].([]interface{})
	for _, d := range domains {
		domain, _ := d.(string)
		if domain == "" {
			continue
		}
		comment := fmt.Sprintf("nms-blacklist-%s", p.ID.String()[:8])
		_, err := conn.Command(fmt.Sprintf("/ip/firewall/filter/add chain=forward dst-host=%s action=drop comment=%s", domain, comment))
		if err != nil {
			return fmt.Errorf("add blacklist rule for %s: %w", domain, err)
		}
	}
	return nil
}

func (s *PolicySyncService) pushWebsiteWhitelist(conn *mikrotik.APIConnection, p *models.Policy) error {
	domains, _ := p.Config["domains"].([]interface{})
	for _, d := range domains {
		domain, _ := d.(string)
		if domain == "" {
			continue
		}
		comment := fmt.Sprintf("nms-whitelist-%s", p.ID.String()[:8])
		_, err := conn.Command(fmt.Sprintf("/ip/firewall/filter/add chain=forward dst-host=%s action=accept comment=%s", domain, comment))
		if err != nil {
			return fmt.Errorf("add whitelist rule for %s: %w", domain, err)
		}
	}
	if len(domains) > 0 {
		comment := fmt.Sprintf("nms-whitelist-drop-%s", p.ID.String()[:8])
		conn.Command(fmt.Sprintf("/ip/firewall/filter/add chain=forward action=drop comment=%s", comment))
	}
	return nil
}

func (s *PolicySyncService) pushBandwidthLimit(conn *mikrotik.APIConnection, p *models.Policy) error {
	uploadBps, _ := p.Config["upload_limit_bps"].(float64)
	downloadBps, _ := p.Config["download_limit_bps"].(float64)
	if u, ok := p.Config["upload_limit_bps"].(int); ok {
		uploadBps = float64(u)
	}
	if d, ok := p.Config["download_limit_bps"].(int); ok {
		downloadBps = float64(d)
	}

	uploadStr := fmt.Sprintf("%.0f", uploadBps)
	downloadStr := fmt.Sprintf("%.0f", downloadBps)
	if uploadBps == 0 && downloadBps == 0 {
		return nil
	}

	target, _ := p.Config["target"].(string)
	comment := fmt.Sprintf("nms-bwlimit-%s", p.ID.String()[:8])

	cmd := fmt.Sprintf("/queue/simple/add name=%s target=%s max-limit=%s/%s comment=%s",
		comment, target, uploadStr, downloadStr, comment)
	_, err := conn.Command(cmd)
	return err
}

func (s *PolicySyncService) pushInternetAccess(conn *mikrotik.APIConnection, p *models.Policy) error {
	enabled, _ := p.Config["enabled"].(bool)
	comment := fmt.Sprintf("nms-internet-%s", p.ID.String()[:8])

	if !enabled {
		_, err := conn.Command(fmt.Sprintf("/ip/firewall/filter/add chain=forward action=drop comment=%s", comment))
		return err
	}
	_, err := conn.Command(fmt.Sprintf("/ip/firewall/filter/remove [find comment=%s]", comment))
	return err
}

func (s *PolicySyncService) pushSchedule(conn *mikrotik.APIConnection, p *models.Policy) error {
	startTime, _ := p.Config["start_time"].(string)
	endTime, _ := p.Config["end_time"].(string)
	days, _ := p.Config["days"].(string)
	action, _ := p.Config["action"].(string)

	if startTime == "" || endTime == "" {
		return nil
	}
	if action == "" {
		action = "drop"
	}

	comment := fmt.Sprintf("nms-schedule-%s", p.ID.String()[:8])
	interval := fmt.Sprintf("%s-%s", startTime, endTime)
	var dayFilter string
	if days != "" {
		dayFilter = fmt.Sprintf(" days=%s", days)
	}
	cmd := fmt.Sprintf("/ip/firewall/filter/add chain=forward action=%s time=%s%s comment=%s",
		action, interval, dayFilter, comment)
	_, err := conn.Command(cmd)
	return err
}



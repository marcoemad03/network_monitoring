package services

import (
	"context"
	"fmt"
	"net"
	"net/url"
	"strings"
	"time"

	"github.com/google/uuid"
	"github.com/hospital/nms-backend/internal/config"
	"github.com/hospital/nms-backend/internal/models"
	"github.com/hospital/nms-backend/internal/repository"
	"github.com/hospital/nms-backend/pkg/mikrotik"
)

type DiscoveryService struct {
	deviceRepo *repository.DeviceRepository
	scanRepo   *repository.ScanRepository
	cfg        *config.Config
}

func NewDiscoveryService(deviceRepo *repository.DeviceRepository, scanRepo *repository.ScanRepository, cfg *config.Config) *DiscoveryService {
	return &DiscoveryService{
		deviceRepo: deviceRepo,
		scanRepo:   scanRepo,
		cfg:        cfg,
	}
}

func extractHost(baseURL string) string {
	baseURL = strings.TrimPrefix(baseURL, "http://")
	baseURL = strings.TrimPrefix(baseURL, "https://")
	if idx := strings.Index(baseURL, ":"); idx > 0 {
		baseURL = baseURL[:idx]
	}
	if idx := strings.Index(baseURL, "/"); idx > 0 {
		baseURL = baseURL[:idx]
	}
	if u, err := url.Parse(baseURL); err == nil && u.Host != "" {
		return u.Host
	}
	return baseURL
}

func (s *DiscoveryService) StartMikroTikDiscovery(ctx context.Context, scan *models.NetworkScan, vendor *models.VendorIntegration) error {
	password := ""
	if vendor.EncryptedPassword != nil {
		password = *vendor.EncryptedPassword
	}

	username := "admin"
	if vendor.Username != nil {
		username = *vendor.Username
	}

	host := extractHost(vendor.BaseURL)

	timeout := s.cfg.ScanTimeout
	if timeout == 0 {
		timeout = 30 * time.Second
	}

	client := mikrotik.NewClient(host, username, password, timeout)

	startTime := time.Now()

	s.scanRepo.UpdateProgress(ctx, scan.ID, 10, 0, 0)

	devices, err := client.GetAllDevices()
	if err != nil {
		s.scanRepo.Fail(ctx, scan.ID, fmt.Sprintf("discovery failed: %v", err))
		return fmt.Errorf("get all devices: %w", err)
	}

	s.scanRepo.UpdateProgress(ctx, scan.ID, 50, len(devices), 0)

	discoveredCount := 0
	activeCount := 0

	for _, d := range devices {
		if d.IsActive {
			activeCount++
		}

		ip := net.ParseIP(d.IPAddress)
		var macAddr *string
		if d.MACAddress != "" {
			macAddr = &d.MACAddress
		}

		existing, _, err := s.deviceRepo.List(ctx, scan.OrganizationID, 1, 1, d.MACAddress, "", "", "", "created_at", false)
		isNew := true
		var deviceID uuid.UUID

		if err == nil && len(existing) > 0 {
			isNew = false
			deviceID = existing[0].ID
			existing[0].IPAddress = ip
			existing[0].LastSeen = time.Now()
			if d.Hostname != "" {
				existing[0].Hostname = &d.Hostname
			}
			existing[0].Status = "online"
			s.deviceRepo.Update(ctx, &existing[0])
		} else {
			dev := &models.Device{
				ID:             uuid.New(),
				OrganizationID: scan.OrganizationID,
				Name:           d.Hostname,
				Hostname:       &d.Hostname,
				IPAddress:      ip,
				MACAddress:     macAddr,
				DeviceType:     "unknown",
				Status:         "online",
				Vendor:         &d.Vendor,
				FirstSeen:      time.Now(),
				LastSeen:       time.Now(),
				IsMonitored:    true,
			}
			if d.Hostname != "" {
				dev.Name = d.Hostname
			} else if d.IPAddress != "" {
				dev.Name = d.IPAddress
			} else {
				dev.Name = "Unknown Device"
			}
			if err := s.deviceRepo.Create(ctx, dev); err != nil {
				continue
			}
			deviceID = dev.ID
		}

		hostname := ""
		if d.Hostname != "" {
			hostname = d.Hostname
		}

		var vendorStr *string
		if d.Vendor != "" {
			vendorStr = &d.Vendor
		}

		result := &models.ScanResult{
			ID:          uuid.New(),
			ScanID:      scan.ID,
			IPAddress:   ip,
			Hostname:    &hostname,
			MACAddress:  macAddr,
			Vendor:      vendorStr,
			IsAlive:     d.IsActive,
			IsNewDevice: isNew,
		}
		if err := s.scanRepo.CreateScanResult(ctx, result); err != nil {
			continue
		}

		discoveredCount++

		_ = deviceID
	}

	duration := int(time.Since(startTime).Seconds())
	s.scanRepo.Complete(ctx, scan.ID, discoveredCount, activeCount, duration, "MikroTik discovery completed")

	return nil
}

func (s *DiscoveryService) TestMikroTikConnection(vendor *models.VendorIntegration) error {
	password := ""
	if vendor.EncryptedPassword != nil {
		password = *vendor.EncryptedPassword
	}
	username := "admin"
	if vendor.Username != nil {
		username = *vendor.Username
	}
	host := extractHost(vendor.BaseURL)
	client := mikrotik.NewClient(host, username, password, 10*time.Second)
	return client.TestConnection()
}

package services

import (
	"context"
	"errors"
	"fmt"
	"log"
	"net"
	"os"
	"sort"
	"strings"
	"sync"
	"time"

	"github.com/google/uuid"
	"github.com/hospital/nms-backend/internal/config"
	"github.com/hospital/nms-backend/internal/models"
	"github.com/hospital/nms-backend/internal/repository"
	"github.com/hospital/nms-backend/internal/websocket"
	"github.com/hospital/nms-backend/pkg/mikrotik"
)

type EnhancedDiscoveryService struct {
	deviceRepo     *repository.DeviceRepository
	scanRepo       *repository.ScanRepository
	eventRepo      *repository.DeviceEventRepository
	deviceCtrlRepo *repository.DeviceControlRepository
	internetRepo   *repository.InternetRepository
	hub            *websocket.Hub
	cfg            *config.Config
	mu             sync.Mutex
	pollingActive  map[uuid.UUID]bool
}

func NewEnhancedDiscoveryService(deviceRepo *repository.DeviceRepository, scanRepo *repository.ScanRepository, eventRepo *repository.DeviceEventRepository, deviceCtrlRepo *repository.DeviceControlRepository, internetRepo *repository.InternetRepository, hub *websocket.Hub, cfg *config.Config) *EnhancedDiscoveryService {
	return &EnhancedDiscoveryService{
		deviceRepo:     deviceRepo,
		scanRepo:       scanRepo,
		eventRepo:      eventRepo,
		deviceCtrlRepo: deviceCtrlRepo,
		internetRepo:   internetRepo,
		hub:            hub,
		cfg:            cfg,
		pollingActive:  make(map[uuid.UUID]bool),
	}
}

func (s *EnhancedDiscoveryService) getVendorFromDB(ctx context.Context, vendorID uuid.UUID) (*models.VendorIntegration, error) {
	if s.internetRepo == nil {
		return nil, fmt.Errorf("internet repository not available")
	}
	return s.internetRepo.GetVendorIntegrationByID(ctx, vendorID)
}

func (s *EnhancedDiscoveryService) GetVendorIntegration(ctx context.Context, vendorID, orgID uuid.UUID) (*models.VendorIntegration, error) {
	vendor, err := s.internetRepo.GetVendorIntegrationForOrganization(ctx, vendorID, orgID)
	if err != nil {
		return nil, err
	}
	if vendor.VendorType != "mikrotik" {
		return nil, fmt.Errorf("integration is not MikroTik")
	}
	if !vendor.IsActive {
		return nil, fmt.Errorf("MikroTik integration is disabled")
	}
	return vendor, nil
}

func (s *EnhancedDiscoveryService) GetConnectedDevices(ctx context.Context, orgID uuid.UUID, vendorID *uuid.UUID) (*models.ConnectedDevicesResult, error) {
	var vendor *models.VendorIntegration
	var err error
	if vendorID != nil {
		vendor, err = s.GetVendorIntegration(ctx, *vendorID, orgID)
	} else {
		vendor, err = s.internetRepo.GetActiveMikroTikIntegration(ctx, orgID)
	}
	if err != nil {
		return &models.ConnectedDevicesResult{Connection: models.RouterConnectionStatus{Code: "NOT_CONFIGURED", Message: "No active MikroTik integration is configured", CheckedAt: time.Now()}, Devices: []models.ConnectedDeviceView{}}, nil
	}

	username := "admin"
	if vendor.Username != nil && strings.TrimSpace(*vendor.Username) != "" {
		username = strings.TrimSpace(*vendor.Username)
	}
	password := ""
	if vendor.EncryptedPassword != nil {
		password = *vendor.EncryptedPassword
	}
	timeout := s.cfg.MikroTikAPITimeout
	if timeout <= 0 {
		timeout = 10 * time.Second
	}
	client, err := mikrotik.NewClientFromEndpoint(vendor.BaseURL, username, password, timeout)
	if err != nil {
		return &models.ConnectedDevicesResult{Connection: models.RouterConnectionStatus{Code: "INVALID_CONFIGURATION", Message: err.Error(), APIEndpoint: vendor.BaseURL, CheckedAt: time.Now()}, Devices: []models.ConnectedDeviceView{}}, nil
	}

	identity, err := client.GetRouterIdentity()
	if err != nil {
		code, message := classifyRouterError(err)
		return &models.ConnectedDevicesResult{Connection: models.RouterConnectionStatus{Code: code, Message: message, APIEndpoint: vendor.BaseURL, CheckedAt: time.Now()}, Devices: []models.ConnectedDeviceView{}}, nil
	}
	entries, err := client.GetAllDevicesEnhanced()
	if err != nil {
		code, message := classifyRouterError(err)
		return &models.ConnectedDevicesResult{Connection: models.RouterConnectionStatus{Code: code, Message: message, APIEndpoint: vendor.BaseURL, RouterName: identity.Name, RouterVersion: identity.Version, CheckedAt: time.Now()}, Devices: []models.ConnectedDeviceView{}}, nil
	}

	return connectedDevicesResult(vendor.BaseURL, identity, entries), nil
}

func (s *EnhancedDiscoveryService) ConnectDevelopmentMikroTik(ctx context.Context, orgID uuid.UUID, host, username, password string, port int) (*models.ConnectedDevicesResult, error) {
	endpoint := net.JoinHostPort(host, fmt.Sprintf("%d", port))
	client := mikrotik.NewClientWithPort(host, port, username, password, s.cfg.MikroTikAPITimeout)
	identity, err := client.GetRouterIdentity()
	if err != nil {
		code, message := classifyRouterError(err)
		return &models.ConnectedDevicesResult{Connection: models.RouterConnectionStatus{Code: code, Message: message, APIEndpoint: endpoint, CheckedAt: time.Now()}, Devices: []models.ConnectedDeviceView{}}, nil
	}
	entries, err := client.GetAllDevicesEnhanced()
	if err != nil {
		code, message := classifyRouterError(err)
		return &models.ConnectedDevicesResult{Connection: models.RouterConnectionStatus{Code: code, Message: message, APIEndpoint: endpoint, RouterName: identity.Name, RouterVersion: identity.Version, CheckedAt: time.Now()}, Devices: []models.ConnectedDeviceView{}}, nil
	}

	vendor := &models.VendorIntegration{
		OrgID:             orgID,
		VendorType:        "mikrotik",
		Name:              "Development MikroTik",
		BaseURL:           endpoint,
		Username:          &username,
		EncryptedPassword: &password,
		IsActive:          true,
	}
	if err := s.internetRepo.SaveDevelopmentMikroTikIntegration(ctx, vendor); err != nil {
		return nil, fmt.Errorf("save MikroTik configuration: %w", err)
	}

	return connectedDevicesResult(endpoint, identity, entries), nil
}

func connectedDevicesResult(endpoint string, identity *mikrotik.RouterIdentity, entries []mikrotik.EnhancedDevice) *models.ConnectedDevicesResult {
	now := time.Now()
	devices := make([]models.ConnectedDeviceView, 0, len(entries))
	for _, entry := range entries {
		if !mikrotik.IsInSubnet172(entry.IPAddress) {
			continue
		}
		name := firstNonEmpty(entry.Hostname, entry.Comment, entry.IPAddress, entry.MACAddress)
		connectionType := "LAN"
		accessPoint := ""
		if strings.EqualFold(entry.ConnectionType, "WiFi") {
			connectionType = "WiFi"
			accessPoint = entry.InterfaceName
		}
		var upload, download *float64
		if entry.RxRateMbps > 0 {
			value := entry.RxRateMbps
			upload = &value
		}
		if entry.TxRateMbps > 0 {
			value := entry.TxRateMbps
			download = &value
		}
		var signal *int
		if entry.SignalStrength != 0 {
			value := entry.SignalStrength
			signal = &value
		}
		id := strings.ToUpper(entry.MACAddress)
		if id == "" {
			id = entry.IPAddress
		}
		devices = append(devices, models.ConnectedDeviceView{ID: id, DeviceName: name, Hostname: entry.Hostname, IPAddress: entry.IPAddress, MACAddress: strings.ToUpper(entry.MACAddress), IsOnline: entry.IsActive && !entry.Disabled, ConnectionType: connectionType, ConnectedAccessPoint: accessPoint, InterfaceName: entry.InterfaceName, CurrentUploadMbps: upload, CurrentDownloadMbps: download, SignalStrengthDbm: signal, LastSeen: now})
	}
	sort.Slice(devices, func(i, j int) bool { return bytesCompareIP(devices[i].IPAddress, devices[j].IPAddress) < 0 })
	return &models.ConnectedDevicesResult{Connection: models.RouterConnectionStatus{Code: "CONNECTED", Message: "Connected to MikroTik RouterOS API", Reachable: true, APIEndpoint: endpoint, RouterName: identity.Name, RouterVersion: identity.Version, CheckedAt: now}, Devices: devices}
}

func classifyRouterError(err error) (string, string) {
	text := strings.ToLower(err.Error())
	var netErr net.Error
	switch {
	case strings.Contains(text, "authentication failed"), strings.Contains(text, "invalid user"), strings.Contains(text, "invalid password"):
		return "AUTHENTICATION_FAILED", "MikroTik authentication failed. Verify the RouterOS username and password."
	case errors.As(err, &netErr) && netErr.Timeout(), strings.Contains(text, "timeout"), strings.Contains(text, "deadline exceeded"):
		return "API_TIMEOUT", "MikroTik RouterOS API timed out."
	case strings.Contains(text, "connection refused"):
		return "API_DISABLED", "MikroTik RouterOS API is disabled or the configured API port is closed."
	case errors.Is(err, os.ErrNotExist), strings.Contains(text, "no such host"), strings.Contains(text, "network is unreachable"), strings.Contains(text, "no route to host"):
		return "ROUTER_UNREACHABLE", "MikroTik router is unreachable on the local network."
	case strings.Contains(text, "not enough permissions"), strings.Contains(text, "permission"):
		return "PERMISSION_DENIED", "The RouterOS account does not have permission to read network tables."
	default:
		return "ROUTER_ERROR", err.Error()
	}
}

func bytesCompareIP(left, right string) int {
	a, b := net.ParseIP(left), net.ParseIP(right)
	if a == nil || b == nil {
		return strings.Compare(left, right)
	}
	return strings.Compare(string(a.To16()), string(b.To16()))
}

func firstNonEmpty(values ...string) string {
	for _, value := range values {
		if strings.TrimSpace(value) != "" {
			return strings.TrimSpace(value)
		}
	}
	return "Unknown Device"
}

func (s *EnhancedDiscoveryService) DiscoverDevices172(ctx context.Context, vendor *models.VendorIntegration, orgID uuid.UUID) ([]models.Device, error) {
	password := ""
	if vendor.EncryptedPassword != nil {
		password = *vendor.EncryptedPassword
	}
	username := "admin"
	if vendor.Username != nil {
		username = *vendor.Username
	}

	timeout := s.cfg.ScanTimeout
	if timeout == 0 {
		timeout = 30 * time.Second
	}

	client, err := mikrotik.NewClientFromEndpoint(vendor.BaseURL, username, password, timeout)
	if err != nil {
		return nil, err
	}

	allDevices, err := client.GetAllDevicesEnhanced()
	if err != nil {
		return nil, fmt.Errorf("discovery failed: %w", err)
	}

	var created []models.Device
	for _, d := range allDevices {
		if !mikrotik.IsInSubnet172(d.IPAddress) {
			continue
		}

		ip := net.ParseIP(d.IPAddress)
		var macAddr *string
		if d.MACAddress != "" {
			upperMac := strings.ToUpper(d.MACAddress)
			macAddr = &upperMac
		}

		existing, err := s.findDeviceByMAC(ctx, orgID, d.MACAddress)
		if err != nil || existing == nil {
			existing, err = s.findDeviceByIP(ctx, orgID, d.IPAddress)
		}

		if existing != nil {
			oldIP := existing.IPAddress.String()
			needsUpdate := false

			if d.Hostname != "" && (existing.Hostname == nil || *existing.Hostname != d.Hostname) {
				existing.Hostname = &d.Hostname
				needsUpdate = true
			}
			if ip != nil && !existing.IPAddress.Equal(ip) {
				existing.IPAddress = ip
				needsUpdate = true
			}
			existing.LastSeen = time.Now()
			existing.Status = "online"

			if d.ConnectionType == "WiFi" {
				existing.ConnectionType = "WiFi"
				existing.ConnectedAP = d.InterfaceName
				existing.SignalStrengthDbm = d.SignalStrength
			} else {
				existing.ConnectionType = "LAN"
				existing.ConnectedInterface = d.InterfaceName
			}

			if d.TxBytes > 0 {
				existing.TotalUploadBytes = d.TxBytes
			}
			if d.RxBytes > 0 {
				existing.TotalDownloadBytes = d.RxBytes
			}

			if needsUpdate {
				if err := s.deviceRepo.Update(ctx, existing); err != nil {
					log.Printf("Failed to update device %s: %v", existing.ID, err)
				} else {
					s.broadcastDeviceUpdate(existing)
					if !existing.IPAddress.Equal(ip) {
						s.eventRepo.CreateEvent(ctx, &models.DeviceEvent{
							ID:             uuid.New(),
							OrganizationID: orgID,
							DeviceID:       existing.ID,
							EventType:      "ip_change",
							PreviousValue:  oldIP,
							NewValue:       ip.String(),
						})
					}
				}
			}
			created = append(created, *existing)
		} else {
			device := &models.Device{
				ID:             uuid.New(),
				OrganizationID: orgID,
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
				ConnectionType: d.ConnectionType,
			}

			if d.Hostname != "" {
				device.Name = d.Hostname
			} else if d.IPAddress != "" {
				device.Name = d.IPAddress
			} else {
				device.Name = "Unknown Device"
			}

			if d.ConnectionType == "WiFi" {
				device.ConnectedAP = d.InterfaceName
				device.SignalStrengthDbm = d.SignalStrength
			} else {
				device.ConnectedInterface = d.InterfaceName
			}

			device.DHCPStatus = d.DHCPStatus
			device.TotalUploadBytes = d.TxBytes
			device.TotalDownloadBytes = d.RxBytes

			macUpper := strings.ToUpper(d.MACAddress)
			device.MACAddress = &macUpper

			if err := s.deviceRepo.Create(ctx, device); err != nil {
				if strings.Contains(err.Error(), "duplicate") {
					existing2, _ := s.findDeviceByMAC(ctx, orgID, d.MACAddress)
					if existing2 != nil {
						existing2.LastSeen = time.Now()
						existing2.Status = "online"
						s.deviceRepo.Update(ctx, existing2)
						created = append(created, *existing2)
						s.broadcastDeviceUpdate(existing2)
					}
					continue
				}
				log.Printf("Failed to create device %s: %v", d.IPAddress, err)
				continue
			}

			s.eventRepo.CreateEvent(ctx, &models.DeviceEvent{
				ID:             uuid.New(),
				OrganizationID: orgID,
				DeviceID:       device.ID,
				EventType:      "connection",
				NewValue:       "online",
			})

			created = append(created, *device)
			s.broadcastDeviceUpdate(device)
		}
	}

	return created, nil
}

func (s *EnhancedDiscoveryService) findDeviceByMAC(ctx context.Context, orgID uuid.UUID, mac string) (*models.Device, error) {
	if mac == "" {
		return nil, fmt.Errorf("empty mac")
	}
	return s.deviceRepo.GetByMACForOrganization(ctx, orgID, mac)
}

func (s *EnhancedDiscoveryService) findDeviceByIP(ctx context.Context, orgID uuid.UUID, ipStr string) (*models.Device, error) {
	if ipStr == "" {
		return nil, fmt.Errorf("empty ip")
	}
	devices, _, err := s.deviceRepo.List(ctx, orgID, 1, 1000, "", "", "", "", "created_at", false)
	if err != nil {
		return nil, err
	}
	for _, d := range devices {
		if d.IPAddress.String() == ipStr {
			return &d, nil
		}
	}
	return nil, nil
}

func (s *EnhancedDiscoveryService) broadcastDeviceUpdate(device *models.Device) {
	if s.hub == nil {
		return
	}
	s.hub.BroadcastMessage("device_update", device)
}

func (s *EnhancedDiscoveryService) StartPolling(ctx context.Context, vendorID, orgID uuid.UUID, interval time.Duration) {
	s.mu.Lock()
	if s.pollingActive[vendorID] {
		s.mu.Unlock()
		return
	}
	s.pollingActive[vendorID] = true
	s.mu.Unlock()

	go func() {
		ticker := time.NewTicker(interval)
		defer ticker.Stop()
		defer func() {
			s.mu.Lock()
			delete(s.pollingActive, vendorID)
			s.mu.Unlock()
		}()

		for {
			select {
			case <-ctx.Done():
				return
			case <-ticker.C:
				vendor, err := s.getVendorFromDB(ctx, vendorID)
				if err != nil {
					log.Printf("Polling: vendor integration not found: %v", err)
					continue
				}
				if _, err := s.DiscoverDevices172(ctx, vendor, orgID); err != nil {
					log.Printf("Polling discovery error: %v", err)
				} else {
					if s.hub != nil {
						s.hub.BroadcastMessage("discovery_poll", map[string]interface{}{
							"status": "completed",
							"vendor": vendor.ID.String(),
						})
					}
				}
			}
		}
	}()
}

func (s *EnhancedDiscoveryService) StopPolling(vendorID uuid.UUID) {
	s.mu.Lock()
	delete(s.pollingActive, vendorID)
	s.mu.Unlock()
}

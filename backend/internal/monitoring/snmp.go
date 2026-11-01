package monitoring

import (
	"context"
	"fmt"
	"time"

	"github.com/google/uuid"
	"github.com/hospital/nms-backend/internal/database"
	"github.com/hospital/nms-backend/internal/models"
	"github.com/hospital/nms-backend/internal/repository"
	"github.com/hospital/nms-backend/internal/websocket"
	"github.com/hospital/nms-backend/pkg/logger"
)

type SNMPCollector struct {
	db      *database.DB
	hub     *websocket.Hub
	monRepo *repository.MonitoringRepository
	stopCh  chan struct{}
}

func NewSNMPCollector(db *database.DB, hub *websocket.Hub) *SNMPCollector {
	return &SNMPCollector{
		db:      db,
		hub:     hub,
		monRepo: repository.NewMonitoringRepository(db),
		stopCh:  make(chan struct{}),
	}
}

func (c *SNMPCollector) Start() {
	logger.Info("SNMP metric collector started")
	ticker := time.NewTicker(3 * time.Minute)
	defer ticker.Stop()

	c.collectAll()

	for {
		select {
		case <-ticker.C:
			c.collectAll()
		case <-c.stopCh:
			return
		}
	}
}

func (c *SNMPCollector) Stop() {
	close(c.stopCh)
}

func (c *SNMPCollector) collectAll() {
	ctx, cancel := context.WithTimeout(context.Background(), 2*time.Minute)
	defer cancel()

	deviceIDs, err := c.monRepo.GetMonitoredDevices(ctx)
	if err != nil {
		logger.Error("Failed to get monitored devices for SNMP", "error", err)
		return
	}

	forEachDevice(ctx, deviceIDs, c.collectDevice)

	orgID := uuid.MustParse("00000000-0000-0000-0000-000000000001")
	summary, err := c.monRepo.GetDashboardLiveSummary(ctx, orgID)
	if err == nil {
		c.hub.BroadcastMessage("dashboard_summary", summary)
	}
}

func (c *SNMPCollector) collectDevice(ctx context.Context, deviceID uuid.UUID) {
	device, err := c.monRepo.GetDeviceByID(ctx, deviceID)
	if err != nil {
		return
	}

	if !pollable(device.IPAddress) {
		return
	}

	deviceType := "unknown"
	if d, err := c.repositoryDevice(ctx, deviceID); err == nil {
		deviceType = d.DeviceType
	}

	pingResult := PingDevice(ctx, device.IPAddress.String(), 2, 500, 3000)
	pingModel := PingToModel(deviceID, pingResult)
	if err := c.monRepo.InsertPing(ctx, pingModel); err != nil {
		logger.Error("Failed to store SNMP ping", "error", err, "device_id", deviceID)
	}

	update := map[string]interface{}{
		"device_id": deviceID,
		"type":      "snmp",
		"ping":      pingModel,
	}
	if simulating() {
		metrics := SimulateMetrics(deviceID, deviceType)
		metrics.AverageLatencyMs = &pingResult.AvgRttMs
		metrics.MaxLatencyMs = &pingResult.MaxRttMs
		metrics.PacketLossPercent = &pingResult.PacketLossPercent
		if err := c.monRepo.InsertMetrics(ctx, metrics); err != nil {
			logger.Error("Failed to store SNMP metrics", "error", err, "device_id", deviceID)
		}

		traffic := SimulateTraffic(deviceID, nil)
		if err := c.monRepo.InsertTraffic(ctx, traffic); err != nil {
			logger.Error("Failed to store SNMP traffic", "error", err, "device_id", deviceID)
		}

		speedTest := SimulateSpeedTest(deviceID)
		if err := c.monRepo.InsertSpeedTest(ctx, speedTest); err != nil {
			logger.Error("Failed to store speed test", "error", err, "device_id", deviceID)
		}
		update["metrics"] = metrics
		update["traffic"] = traffic
		update["speed_test"] = speedTest
	}
	c.hub.BroadcastMessage("device_update", update)
}

func (c *SNMPCollector) repositoryDevice(ctx context.Context, id uuid.UUID) (*models.Device, error) {
	return c.monRepo.GetDeviceByID(ctx, id)
}

// TODO: Implement real SNMP WalkOID using gosnmp for production use
func (c *SNMPCollector) WalkOID(ctx context.Context, ip, community, oid string) (map[string]string, error) {
	return nil, fmt.Errorf("SNMP WalkOID not yet implemented - requires gosnmp dependency")
}

// TODO: Implement real SNMP Get using gosnmp for production use
func (c *SNMPCollector) Get(ctx context.Context, ip, community, oid string) (string, error) {
	return "", fmt.Errorf("SNMP Get not yet implemented - requires gosnmp dependency")
}

package monitoring

import (
	"context"
	"fmt"
	"sync/atomic"
	"time"

	"github.com/google/uuid"
	"github.com/hospital/nms-backend/internal/database"
	"github.com/hospital/nms-backend/internal/repository"
	"github.com/hospital/nms-backend/internal/websocket"
	"github.com/hospital/nms-backend/pkg/logger"
)

type Monitor struct {
	db        *database.DB
	hub       *websocket.Hub
	monRepo   *repository.MonitoringRepository
	devRepo   *repository.DeviceRepository
	interval  time.Duration
	pingCount int
	stopCh    chan struct{}
	polling   atomic.Bool
}

func NewMonitor(db *database.DB, hub *websocket.Hub, interval time.Duration) *Monitor {
	return &Monitor{
		db:        db,
		hub:       hub,
		monRepo:   repository.NewMonitoringRepository(db),
		devRepo:   repository.NewDeviceRepository(db),
		interval:  interval,
		pingCount: 4,
		stopCh:    make(chan struct{}),
	}
}

func (m *Monitor) Start() {
	logger.Info("Network monitor started", "interval", m.interval.String())

	go func() {
		m.pollOnce()
		ticker := time.NewTicker(m.interval)
		defer ticker.Stop()

		for {
			select {
			case <-ticker.C:
				m.pollOnce()
			case <-m.stopCh:
				return
			}
		}
	}()
}

func (m *Monitor) Stop() {
	close(m.stopCh)
	logger.Info("Network monitor stopped")
}

func (m *Monitor) pollOnce() {
	// A slow round must not stack on top of the next one.
	if !m.polling.CompareAndSwap(false, true) {
		return
	}
	defer m.polling.Store(false)

	ctx, cancel := context.WithTimeout(context.Background(), 3*time.Minute)
	defer cancel()

	deviceIDs, err := m.monRepo.GetMonitoredDevices(ctx)
	if err != nil {
		logger.Error("Failed to get monitored devices", "error", err)
		return
	}

	forEachDevice(ctx, deviceIDs, m.pollDevice)

	m.broadcastDashboardSummary(ctx)
}

func (m *Monitor) pollDevice(ctx context.Context, deviceID uuid.UUID) {
	device, err := m.monRepo.GetDeviceByID(ctx, deviceID)
	if err != nil {
		return
	}

	if !pollable(device.IPAddress) {
		return
	}
	ip := device.IPAddress.String()
	deviceType := "unknown"
	if d, err := m.devRepo.GetByID(ctx, deviceID); err == nil {
		deviceType = d.DeviceType
	}

	pingResult := PingDevice(ctx, ip, m.pingCount, 300, 2000)
	pingModel := PingToModel(deviceID, pingResult)
	if err := m.monRepo.InsertPing(ctx, pingModel); err != nil {
		logger.Error("Failed to store ping result", "error", err, "device_id", deviceID)
	}

	status := "online"
	if !pingResult.IsReachable {
		status = "offline"
	} else if pingResult.PacketLossPercent > 10 || (pingResult.AvgRttMs > 200) {
		status = "degraded"
	}
	if err := m.monRepo.UpdateDeviceStatus(ctx, deviceID, status); err != nil {
		logger.Error("Failed to update device status", "error", err, "device_id", deviceID)
	}

	metrics := SimulateMetrics(deviceID, deviceType)
	metrics.AverageLatencyMs = &pingResult.AvgRttMs
	metrics.MaxLatencyMs = &pingResult.MaxRttMs
	metrics.PacketLossPercent = &pingResult.PacketLossPercent
	if err := m.monRepo.InsertMetrics(ctx, metrics); err != nil {
		logger.Error("Failed to store metrics", "error", err, "device_id", deviceID)
	}

	traffic := SimulateTraffic(deviceID, nil)
	if err := m.monRepo.InsertTraffic(ctx, traffic); err != nil {
		logger.Error("Failed to store traffic", "error", err, "device_id", deviceID)
	}

	m.hub.BroadcastMessage("device_update", map[string]interface{}{
		"device_id": deviceID,
		"status":    status,
		"ping":      pingModel,
		"metrics":   metrics,
		"traffic":   traffic,
	})
}

func (m *Monitor) broadcastDashboardSummary(ctx context.Context) {
	orgID := uuid.MustParse("00000000-0000-0000-0000-000000000001")
	summary, err := m.monRepo.GetDashboardLiveSummary(ctx, orgID)
	if err != nil {
		logger.Error("Failed to get dashboard summary", "error", err)
		return
	}
	m.hub.BroadcastMessage("dashboard_summary", summary)

	if summary.CriticalAlerts > 0 {
		m.hub.BroadcastMessage("alert_summary", map[string]interface{}{
			"critical": summary.CriticalAlerts,
			"open":     summary.OpenAlerts,
			"message":  fmt.Sprintf("%d critical alerts require attention", summary.CriticalAlerts),
		})
	}
}

package monitoring

import (
	"context"
	"fmt"
	"math"
	"math/rand"
	"net"
	"time"

	"github.com/hospital/nms-backend/internal/models"
)

type PingResult struct {
	MinRttMs         float64
	MaxRttMs         float64
	AvgRttMs         float64
	MedianRttMs      float64
	StddevRttMs      float64
	JitterMs         float64
	PacketLossPercent float64
	PacketsSent      int
	PacketsReceived  int
	PacketsLost      int
	IsReachable      bool
}

func PingDevice(ctx context.Context, ip string, count, intervalMs int, timeoutMs int) *PingResult {
	if count <= 0 {
		count = 4
	}
	if intervalMs <= 0 {
		intervalMs = 200
	}
	if timeoutMs <= 0 {
		timeoutMs = 1000
	}

	result := &PingResult{
		PacketsSent: count,
	}

	var rtts []float64

	for i := 0; i < count; i++ {
		select {
		case <-ctx.Done():
			result.PacketsSent = i
			goto done
		default:
		}

		rtt, ok := simulatedPing(ip, timeoutMs)
		if ok {
			rtts = append(rtts, rtt)
			result.PacketsReceived++
		} else {
			result.PacketsLost++
		}

		if i < count-1 {
			time.Sleep(time.Duration(intervalMs) * time.Millisecond)
		}
	}

done:
	result.PacketsSent = count
	if result.PacketsSent > 0 {
		result.PacketLossPercent = float64(result.PacketsLost) / float64(result.PacketsSent) * 100
	}

	if len(rtts) > 0 {
		result.IsReachable = true
		var sum float64
		for _, rtt := range rtts {
			sum += rtt
		}
		result.AvgRttMs = sum / float64(len(rtts))

		result.MinRttMs = rtts[0]
		result.MaxRttMs = rtts[0]
		for _, rtt := range rtts {
			if rtt < result.MinRttMs {
				result.MinRttMs = rtt
			}
			if rtt > result.MaxRttMs {
				result.MaxRttMs = rtt
			}
		}

		sorted := make([]float64, len(rtts))
		copy(sorted, rtts)
		for i := 0; i < len(sorted); i++ {
			for j := i + 1; j < len(sorted); j++ {
				if sorted[i] > sorted[j] {
					sorted[i], sorted[j] = sorted[j], sorted[i]
				}
			}
		}
		mid := len(sorted) / 2
		if len(sorted)%2 == 0 {
			result.MedianRttMs = (sorted[mid-1] + sorted[mid]) / 2
		} else {
			result.MedianRttMs = sorted[mid]
		}

		var varianceSum float64
		for _, rtt := range rtts {
			diff := rtt - result.AvgRttMs
			varianceSum += diff * diff
		}
		result.StddevRttMs = math.Sqrt(varianceSum / float64(len(rtts)))

		if len(rtts) > 1 {
			var jitterSum float64
			for i := 1; i < len(rtts); i++ {
				diff := rtts[i] - rtts[i-1]
				if diff < 0 {
					diff = -diff
				}
				jitterSum += diff
			}
			result.JitterMs = jitterSum / float64(len(rtts)-1)
		}
	}

	return result
}

func simulatedPing(ip string, timeoutMs int) (float64, bool) {
	addr := net.ParseIP(ip)
	if addr == nil {
		return 0, false
	}

	baseLatency := 1.0
	if addr.IsLoopback() {
		baseLatency = 0.1
	}

	rtt := baseLatency + rand.Float64()*5.0
	lossRoll := rand.Float64() * 100
	packetLoss := 1.0

	if lossRoll < packetLoss {
		return rtt, true
	}
	return 0, false
}

func PingToModel(deviceID uuid.UUID, result *PingResult) *models.DevicePing {
	avg := result.AvgRttMs
	max := result.MaxRttMs
	min := result.MinRttMs
	med := result.MedianRttMs
	stddev := result.StddevRttMs
	jitter := result.JitterMs

	return &models.DevicePing{
		ID:                [16]byte{},
		DeviceID:          deviceID,
		MinRttMs:         &min,
		MaxRttMs:         &max,
		AvgRttMs:         &avg,
		MedianRttMs:      &med,
		StddevRttMs:      &stddev,
		JitterMs:         &jitter,
		PacketLossPercent: result.PacketLossPercent,
		PacketsSent:      result.PacketsSent,
		PacketsReceived:  result.PacketsReceived,
		PacketsLost:      result.PacketsLost,
		IsReachable:      result.IsReachable,
		Timestamp:        time.Now(),
	}
}

func SimulateMetrics(deviceID uuid.UUID, deviceType string) *models.DeviceMetrics {
	now := time.Now()
	cpu := 20.0 + rand.Float64()*60.0
	mem := 30.0 + rand.Float64()*50.0
	disk := 25.0 + rand.Float64()*50.0
	temp := 35.0 + rand.Float64()*20.0
	uptime := int64(86400 * (1 + rand.Intn(30)))
	latency := 0.5 + rand.Float64()*10.0
	maxLat := latency + rand.Float64()*20.0
	packetLoss := rand.Float64() * 2.0
	uploadBps := int64(rand.Float64() * 100000000)
	downloadBps := int64(rand.Float64() * 500000000)
	inBps := int64(rand.Float64() * 500000000)
	outBps := int64(rand.Float64() * 100000000)

	var signalDbm *int
	var signalQuality *float64
	if deviceType == "access_point" || deviceType == "router" || deviceType == "workstation" || deviceType == "phone" || deviceType == "iot" || deviceType == "camera" {
		s := -(40 + rand.Intn(40))
		signalDbm = &s
		q := 50.0 + rand.Float64()*50.0
		signalQuality = &q
	}

	return &models.DeviceMetrics{
		DeviceID:            deviceID,
		CPUUsagePercent:     &cpu,
		MemoryUsagePercent:  &mem,
		DiskUsagePercent:    &disk,
		TemperatureCelsius:  &temp,
		UptimeSeconds:       &uptime,
		TotalTrafficInBps:   &inBps,
		TotalTrafficOutBps:  &outBps,
		AverageLatencyMs:    &latency,
		MaxLatencyMs:        &maxLat,
		PacketLossPercent:   &packetLoss,
		UploadSpeedBps:      &uploadBps,
		DownloadSpeedBps:    &downloadBps,
		SignalStrengthDbm:   signalDbm,
		SignalQualityPercent: signalQuality,
		Timestamp:           now,
	}
}

func SimulateTraffic(deviceID uuid.UUID, interfaceID *uuid.UUID) *models.DeviceTraffic {
	util := 5.0 + rand.Float64()*60.0
	return &models.DeviceTraffic{
		ID:                 [16]byte{},
		DeviceID:           deviceID,
		InterfaceID:        interfaceID,
		UploadBps:          int64(rand.Float64() * 100000000),
		DownloadBps:        int64(rand.Float64() * 500000000),
		TotalUploadBytes:   int64(rand.Float64() * 1e12),
		TotalDownloadBytes: int64(rand.Float64() * 5e12),
		UploadPackets:      int64(rand.Float64() * 1e7),
		DownloadPackets:    int64(rand.Float64() * 3e7),
		UtilizationPercent: &util,
		Timestamp:          time.Now(),
	}
}

func SimulateSpeedTest(deviceID uuid.UUID) *models.DeviceSpeedTest {
	up := 10.0 + rand.Float64()*100.0
	down := 50.0 + rand.Float64()*400.0
	lat := 1.0 + rand.Float64()*30.0
	jit := 0.1 + rand.Float64()*10.0
	pl := rand.Float64() * 1.0
	duration := 10 + rand.Intn(20)
	server := fmt.Sprintf("speedtest-server-%d.local", 1+rand.Intn(5))

	return &models.DeviceSpeedTest{
		ID:                  [16]byte{},
		DeviceID:            deviceID,
		UploadSpeedMbps:     &up,
		DownloadSpeedMbps:   &down,
		LatencyMs:           &lat,
		JitterMs:            &jit,
		PacketLossPercent:   &pl,
		TestServer:          &server,
		TestDurationSeconds: &duration,
		Timestamp:           time.Now(),
	}
}

package seeds

import (
	"context"
	"time"

	"github.com/google/uuid"
	"github.com/hospital/nms-backend/internal/database"
	"github.com/hospital/nms-backend/pkg/logger"
	"golang.org/x/crypto/bcrypt"
)

func Run(db *database.DB) error {
	ctx := context.Background()

	orgID := uuid.MustParse("00000000-0000-0000-0000-000000000001")
	adminID := uuid.MustParse("00000000-0000-0000-0000-000000000002")

	var count int
	db.QueryRow(ctx, `SELECT COUNT(*) FROM organizations`).Scan(&count)
	if count > 0 {
		logger.Info("Database already seeded, skipping")
		return nil
	}

	logger.Info("Seeding database...")

	_, err := db.Exec(ctx,
		`INSERT INTO organizations (id, name, code) VALUES ($1, $2, $3)`,
		orgID, "Hospital Network Operations", "HOSP-NMS",
	)
	if err != nil {
		return err
	}

	hash, _ := bcrypt.GenerateFromPassword([]byte("admin123"), bcrypt.DefaultCost)
	_, err = db.Exec(ctx,
		`INSERT INTO users (id, organization_id, username, email, password_hash, display_name, role, is_active) VALUES ($1, $2, $3, $4, $5, $6, $7, $8)`,
		adminID, orgID, "admin", "admin@hospital.com", string(hash), "System Administrator", "admin", true,
	)
	if err != nil {
		return err
	}

	devices := []struct {
		name    string
		ip      string
		dtype   string
		status  string
		vendor  string
		medical bool
	}{
		{"Core-Switch-01", "10.0.1.1", "switch", "online", "Cisco", false},
		{"Core-Switch-02", "10.0.1.2", "switch", "online", "Cisco", false},
		{"Edge-Router-Main", "10.0.0.1", "router", "online", "MikroTik", false},
		{"Firewall-Primary", "10.0.0.2", "firewall", "online", "Palo Alto", false},
		{"PACS-Server-01", "10.0.10.10", "server", "online", "Dell", false},
		{"EHR-Database-01", "10.0.10.20", "server", "online", "HP", false},
		{"MRI-Machine-01", "10.0.20.10", "medical_device", "online", "Siemens", true},
		{"CT-Scanner-01", "10.0.20.20", "medical_device", "online", "GE Healthcare", true},
		{"Patient-Monitor-WingA-01", "10.0.30.5", "medical_device", "online", "Philips", true},
		{"Patient-Monitor-WingA-02", "10.0.30.6", "medical_device", "online", "Philips", true},
		{"Nurse-Station-A", "10.0.40.10", "workstation", "online", "HP", false},
		{"Admin-Building-AP-01", "10.0.50.1", "access_point", "online", "Aruba", false},
		{"Ward-B-AP-02", "10.0.50.2", "access_point", "degraded", "Aruba", false},
		{"Security-Camera-North", "10.0.60.5", "camera", "online", "Hikvision", false},
		{"Print-Server-Admin", "10.0.70.10", "printer", "online", "Brother", false},
		{"Legacy-Switch-Floor2", "10.0.80.1", "switch", "offline", "3Com", false},
		{"Backup-FW-Secondary", "10.0.0.3", "firewall", "maintenance", "Palo Alto", false},
		{"IoT-Temp-Sensor-01", "10.0.90.1", "iot", "online", "Monnit", false},
		{"VoIP-Gateway-Main", "10.0.100.1", "router", "online", "Cisco", false},
		{"Data-Vault-Backup", "10.0.10.30", "server", "online", "Dell", false},
	}

	now := time.Now()
	for _, d := range devices {
		devID := uuid.New()
		_, err := db.Exec(ctx,
			`INSERT INTO devices (id, organization_id, name, ip_address, device_type, status, vendor, is_critical, is_monitored, first_seen, last_seen, created_at, updated_at) VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13)`,
			devID, orgID, d.name, d.ip, d.dtype, d.status, d.vendor,
			d.medical || d.dtype == "firewall", true, now, now, now, now,
		)
		if err != nil {
			logger.Error("Failed to seed device", "error", err, "name", d.name)
		}
	}

	alerts := []struct {
		title    string
		severity string
		status   string
	}{
		{"Core-Switch-01 High CPU Usage > 90%", "critical", "open"},
		{"Edge-Router Latency Spike Detected", "high", "open"},
		{"Ward-B-AP-02 Signal Degraded", "medium", "acknowledged"},
		{"Legacy-Switch-Floor2 Device Offline", "high", "open"},
		{"PACS-Server Disk Usage > 85%", "medium", "open"},
		{"Backup-FW-Secondary Maintenance Overdue", "low", "open"},
		{"Security-Camera-North Packet Loss", "low", "resolved"},
	}

	for _, a := range alerts {
		_, err := db.Exec(ctx,
			`INSERT INTO alerts (id, organization_id, title, severity, status, category, detected_at, created_at, updated_at) VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9)`,
			uuid.New(), orgID, a.title, a.severity, a.status, "connectivity", now, now, now,
		)
		if err != nil {
			logger.Error("Failed to seed alert", "error", err)
		}
	}

	logger.Info("Database seeded successfully",
		"organizations", 1,
		"users", 1,
		"devices", len(devices),
		"alerts", len(alerts),
	)
	return nil
}

package seeds

import (
	"context"
	"encoding/json"
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
		logger.Info("Database already seeded, skipping main seed")
		SeedAssetData(db, orgID)
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

	SeedAssetData(db, orgID)
	return nil
}

func SeedAssetData(db *database.DB, orgID uuid.UUID) {
	ctx := context.Background()

	var policyCount int
	db.QueryRow(ctx, `SELECT COUNT(*) FROM policies`).Scan(&policyCount)
	if policyCount > 0 {
		return
	}

	logger.Info("Seeding asset management data...")

	now := time.Now()

	// Seed device groups
	groups := []struct {
		id   string
		name string
		desc string
	}{
		{"a1000000-0000-0000-0000-000000000001", "IT Infrastructure", "Core network infrastructure devices"},
		{"a1000000-0000-0000-0000-000000000002", "Medical Equipment", "Patient-facing medical devices"},
		{"a1000000-0000-0000-0000-000000000003", "Admin Staff", "Administrative workstations and printers"},
		{"a1000000-0000-0000-0000-000000000004", "Security Systems", "Cameras and access control devices"},
	}
	for _, g := range groups {
		db.Exec(ctx,
			`INSERT INTO device_groups (id, organization_id, name, description, created_at, updated_at) VALUES ($1,$2,$3,$4,$5,$6) ON CONFLICT DO NOTHING`,
			g.id, orgID, g.name, g.desc, now, now,
		)
	}

	// Seed floor maps
	maps := []struct {
		id     string
		name   string
		width  int
		height int
	}{
		{"b1000000-0000-0000-0000-000000000001", "Ground Floor - Reception & Admin", 1200, 900},
		{"b1000000-0000-0000-0000-000000000002", "First Floor - Wards A & B", 1200, 900},
		{"b1000000-0000-0000-0000-000000000003", "Second Floor - Surgery & ICU", 1200, 900},
	}
	for _, m := range maps {
		db.Exec(ctx,
			`INSERT INTO floor_maps (id, organization_id, name, image_path, width, height, created_at, updated_at) VALUES ($1,$2,$3,$4,$5,$6,$7,$8) ON CONFLICT DO NOTHING`,
			m.id, orgID, m.name, "default.png", m.width, m.height, now, now,
		)
	}

	// Seed policies
	blConfig, _ := json.Marshal(map[string]interface{}{
		"domains": []string{"facebook.com", "twitter.com", "tiktok.com", "instagram.com"},
	})
	bwConfig, _ := json.Marshal(map[string]interface{}{
		"upload_limit_bps":   5000000,
		"download_limit_bps": 20000000,
	})
	inetConfig, _ := json.Marshal(map[string]interface{}{
		"enabled": false,
	})
	whitelistConfig, _ := json.Marshal(map[string]interface{}{
		"domains": []string{"hospital.com", "health.gov"},
	})
	policies := []struct {
		id     string
		name   string
		pType  string
		config string
	}{
		{"c1000000-0000-0000-0000-000000000001", "Block Social Media", "blacklist", string(blConfig)},
		{"c1000000-0000-0000-0000-000000000002", "Medical Staff Bandwidth", "bandwidth_limit", string(bwConfig)},
		{"c1000000-0000-0000-0000-000000000003", "Internet Off - Night Shift", "internet_access", string(inetConfig)},
		{"c1000000-0000-0000-0000-000000000004", "Whitelist Hospital Sites", "website_whitelist", string(whitelistConfig)},
		{"c1000000-0000-0000-0000-000000000005", "Upload Limit - 2Mbps", "upload_limit", string(bwConfig)},
		{"c1000000-0000-0000-0000-000000000006", "Download Limit - 5Mbps", "download_limit", string(bwConfig)},
	}
	for _, p := range policies {
		db.Exec(ctx,
			`INSERT INTO policies (id, organization_id, name, policy_type, config, is_active, created_at, updated_at) VALUES ($1,$2,$3,$4,$5,$6,$7,$8) ON CONFLICT DO NOTHING`,
			p.id, orgID, p.name, p.pType, p.config, true, now, now,
		)
	}

	// Assign policies to groups
	policyGroupPairs := []struct {
		policyID string
		groupID  string
	}{
		{"c1000000-0000-0000-0000-000000000001", "a1000000-0000-0000-0000-000000000001"},
		{"c1000000-0000-0000-0000-000000000002", "a1000000-0000-0000-0000-000000000002"},
		{"c1000000-0000-0000-0000-000000000003", "a1000000-0000-0000-0000-000000000003"},
		{"c1000000-0000-0000-0000-000000000004", "a1000000-0000-0000-0000-000000000001"},
		{"c1000000-0000-0000-0000-000000000005", "a1000000-0000-0000-0000-000000000004"},
		{"c1000000-0000-0000-0000-000000000006", "a1000000-0000-0000-0000-000000000003"},
	}
	for _, pair := range policyGroupPairs {
		db.Exec(ctx,
			`INSERT INTO policy_assignments (id, policy_id, group_id, created_at) VALUES ($1,$2,$3,$4) ON CONFLICT DO NOTHING`,
			uuid.New(), pair.policyID, pair.groupID, now,
		)
	}

	logger.Info("Asset management data seeded",
		"groups", len(groups),
		"floor_maps", len(maps),
		"policies", len(policies),
		"policy_assignments", len(policyGroupPairs),
	)
}

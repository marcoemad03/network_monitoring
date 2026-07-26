package services

import (
	"context"
	"errors"
	"fmt"
	"net"
	"strconv"
	"strings"
	"time"

	"github.com/google/uuid"
	"github.com/hospital/nms-backend/internal/config"
	"github.com/hospital/nms-backend/internal/models"
	"github.com/hospital/nms-backend/internal/repository"
	"github.com/hospital/nms-backend/pkg/mikrotik"
)

const managedPolicyPrefix = "nms-policy-"

var ErrPolicyUnsupported = errors.New("policy type is not safely enforceable on MikroTik")

type routerCommander interface {
	Command(string, ...string) ([]map[string]string, error)
	Close() error
}

type desiredRouterEntry struct {
	path  string
	attrs map[string]string
}

type PolicySyncService struct {
	assetRepo    *repository.AssetRepository
	internetRepo *repository.InternetRepository
	cfg          *config.Config
	dialRouter   func(*models.VendorIntegration) (routerCommander, error)
}

func NewPolicySyncService(assetRepo *repository.AssetRepository, internetRepo *repository.InternetRepository, cfg *config.Config) *PolicySyncService {
	s := &PolicySyncService{assetRepo: assetRepo, internetRepo: internetRepo, cfg: cfg}
	s.dialRouter = s.dial
	return s
}

func (s *PolicySyncService) SyncPoliciesToMikroTik(ctx context.Context, orgID uuid.UUID) error {
	vendor, err := s.internetRepo.GetActiveMikroTikIntegration(ctx, orgID)
	if err != nil {
		return fmt.Errorf("active MikroTik integration is not configured: %w", err)
	}
	log := &models.SyncLog{ID: uuid.New(), OrganizationID: orgID, VendorIntegrationID: &vendor.ID, Status: "in_progress", Details: map[string]interface{}{"started_at": time.Now().Format(time.RFC3339)}}
	_ = s.assetRepo.CreateSyncLog(ctx, log)

	targets, err := s.assetRepo.ListAssignedPolicyDevices(ctx, orgID)
	if err != nil {
		return s.fail(ctx, log, fmt.Errorf("resolve policy assignments: %w", err))
	}
	firewall, queues, err := desiredEntries(targets)
	if err != nil {
		return s.fail(ctx, log, err)
	}
	conn, err := s.dialRouter(vendor)
	if err != nil {
		return s.fail(ctx, log, fmt.Errorf("connect MikroTik: %w", err))
	}
	defer conn.Close()

	if err := reconcileEntries(conn, "/ip/firewall/filter", firewall); err != nil {
		return s.fail(ctx, log, fmt.Errorf("reconcile Internet access rules: %w", err))
	}
	if err := reconcileEntries(conn, "/queue/simple", queues); err != nil {
		return s.fail(ctx, log, fmt.Errorf("reconcile bandwidth queues: %w", err))
	}
	log.ID = uuid.New()
	log.Status = "completed"
	log.Details = map[string]interface{}{"targets": len(targets), "firewall_rules": len(firewall), "queues": len(queues), "completed_at": time.Now().Format(time.RFC3339)}
	_ = s.assetRepo.CreateSyncLog(ctx, log)
	return nil
}

func (s *PolicySyncService) fail(ctx context.Context, log *models.SyncLog, err error) error {
	log.ID = uuid.New()
	log.Status = "failed"
	log.Details = map[string]interface{}{"error": err.Error(), "failed_at": time.Now().Format(time.RFC3339)}
	_ = s.assetRepo.CreateSyncLog(ctx, log)
	return err
}

func (s *PolicySyncService) dial(vendor *models.VendorIntegration) (routerCommander, error) {
	username := "admin"
	if vendor.Username != nil {
		username = *vendor.Username
	}
	password := ""
	if vendor.EncryptedPassword != nil {
		password = *vendor.EncryptedPassword
	}
	client, err := mikrotik.NewClientFromEndpoint(vendor.BaseURL, username, password, s.cfg.MikroTikAPITimeout)
	if err != nil {
		return nil, err
	}
	conn := mikrotik.NewAPIConnection(client.Host(), client.Port(), client.Username(), client.Password(), s.cfg.MikroTikAPITimeout)
	if err := conn.Connect(); err != nil {
		return nil, err
	}
	if err := conn.Login(); err != nil {
		conn.Close()
		return nil, err
	}
	return conn, nil
}

func desiredEntries(targets []models.AssignedPolicyDevice) (map[string]desiredRouterEntry, map[string]desiredRouterEntry, error) {
	firewall := make(map[string]desiredRouterEntry)
	queues := make(map[string]desiredRouterEntry)
	for _, target := range targets {
		p, d := target.Policy, target.Device
		if d.MACAddress == nil || strings.TrimSpace(*d.MACAddress) == "" || d.IPAddress == nil || d.IPAddress.IsUnspecified() {
			return nil, nil, fmt.Errorf("policy %s device %s has no current MAC/IP identity", p.ID, d.ID)
		}
		comment := managedPolicyPrefix + p.ID.String() + "-" + d.ID.String()
		switch p.PolicyType {
		case "internet_access":
			enabled, ok := p.Config["enabled"].(bool)
			if !ok {
				return nil, nil, fmt.Errorf("policy %s: internet_access requires boolean enabled", p.ID)
			}
			if !enabled {
				firewall[comment] = desiredRouterEntry{path: "/ip/firewall/filter", attrs: map[string]string{"chain": "forward", "action": "drop", "src-address": hostCIDR(d.IPAddress), "src-mac-address": strings.ToUpper(*d.MACAddress), "comment": comment}}
			}
		case "bandwidth_limit", "upload_limit", "download_limit":
			upload, uok := positiveInt64(p.Config["upload_limit_bps"])
			download, dok := positiveInt64(p.Config["download_limit_bps"])
			if p.PolicyType == "upload_limit" && !uok || p.PolicyType == "download_limit" && !dok || p.PolicyType == "bandwidth_limit" && !uok && !dok {
				return nil, nil, fmt.Errorf("policy %s: %s requires a positive applicable limit", p.ID, p.PolicyType)
			}
			queues[comment] = desiredRouterEntry{path: "/queue/simple", attrs: map[string]string{"name": comment, "target": hostCIDR(d.IPAddress), "max-limit": fmt.Sprintf("%d/%d", upload, download), "comment": comment}}
		case "website_blacklist", "website_whitelist", "schedule":
			return nil, nil, fmt.Errorf("%w: %s policy %s", ErrPolicyUnsupported, p.PolicyType, p.ID)
		default:
			return nil, nil, fmt.Errorf("%w: unknown policy type %q", ErrPolicyUnsupported, p.PolicyType)
		}
	}
	return firewall, queues, nil
}

func reconcileEntries(conn routerCommander, basePath string, desired map[string]desiredRouterEntry) error {
	existing, err := conn.Command(basePath+"/print", "?comment="+managedPolicyPrefix)
	if err != nil {
		return err
	}
	seen := make(map[string]bool)
	for _, current := range existing {
		comment := current["comment"]
		if !strings.HasPrefix(comment, managedPolicyPrefix) {
			continue
		}
		want, ok := desired[comment]
		if !ok {
			if _, err := conn.Command(basePath+"/remove", "=.id="+current[".id"]); err != nil {
				return err
			}
			continue
		}
		seen[comment] = true
		changed := false
		for key, value := range want.attrs {
			if current[key] != value {
				changed = true
				break
			}
		}
		if changed {
			attrs := attributeWords(want.attrs)
			attrs = append([]string{"=.id=" + current[".id"]}, attrs...)
			if _, err := conn.Command(basePath+"/set", attrs...); err != nil {
				return err
			}
		}
	}
	for comment, want := range desired {
		if seen[comment] {
			continue
		}
		if _, err := conn.Command(want.path+"/add", attributeWords(want.attrs)...); err != nil {
			return err
		}
	}
	return nil
}

func attributeWords(attrs map[string]string) []string {
	words := make([]string, 0, len(attrs))
	for key, value := range attrs {
		words = append(words, "="+key+"="+value)
	}
	return words
}

func positiveInt64(value interface{}) (int64, bool) {
	var n int64
	switch value := value.(type) {
	case float64:
		n = int64(value)
	case int:
		n = int64(value)
	case int64:
		n = value
	case string:
		n, _ = strconv.ParseInt(value, 10, 64)
	}
	return n, n > 0
}

func hostCIDR(ip net.IP) string {
	if ip.To4() != nil {
		return ip.String() + "/32"
	}
	return ip.String() + "/128"
}

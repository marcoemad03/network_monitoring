package services

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"log"
	"net/http"
	"strings"
	"sync"
	"time"

	"github.com/google/uuid"
	"github.com/hospital/nms-backend/internal/models"
	"github.com/hospital/nms-backend/internal/repository"
	"github.com/hospital/nms-backend/internal/websocket"
)

var telegramEmoji = map[models.TelegramEventType]string{
	models.TelegramEventConnect:         "\xF0\x9F\x93\xB1",
	models.TelegramEventDisconnect:      "\xF0\x9F\x92\xA5",
	models.TelegramEventNewDevice:       "\xE2\x9A\xA0\xEF\xB8\x8F",
	models.TelegramEventPolicyViolation: "\xF0\x9F\x9A\xAB",
}

type TelegramService struct {
	repo    *repository.TelegramRepository
	hub     *websocket.Hub
	client  *http.Client
	mu      sync.Mutex
	midnightCancel map[uuid.UUID]context.CancelFunc
}

func NewTelegramService(repo *repository.TelegramRepository, hub *websocket.Hub) *TelegramService {
	return &TelegramService{
		repo:           repo,
		hub:            hub,
		client:         &http.Client{Timeout: 10 * time.Second},
		midnightCancel: make(map[uuid.UUID]context.CancelFunc),
	}
}

func (s *TelegramService) GetConfig(ctx context.Context, orgID uuid.UUID) (*models.TelegramConfig, error) {
	cfg, err := s.repo.GetConfig(ctx, orgID)
	if err != nil {
		return nil, err
	}
	if cfg == nil {
		return &models.TelegramConfig{OrganizationID: orgID, GracePeriodMinutes: 5, OncePerDay: true, NotifyConnect: true, NotifyDisconnect: true, NotifyNewDevice: true, NotifyPolicyViolation: true}, nil
	}
	return cfg, nil
}

func (s *TelegramService) SaveConfig(ctx context.Context, cfg *models.TelegramConfig) error {
	cfg.BotToken = strings.TrimSpace(cfg.BotToken)
	cfg.ChatID = strings.TrimSpace(cfg.ChatID)
	if cfg.GracePeriodMinutes < 0 {
		cfg.GracePeriodMinutes = 0
	}
	if cfg.Enabled && (cfg.BotToken == "" || cfg.ChatID == "") {
		return fmt.Errorf("bot_token and chat_id are required when notifications are enabled")
	}
	if err := s.repo.UpsertConfig(ctx, cfg); err != nil {
		return err
	}
	if cfg.Enabled {
		s.startMidnightReset(ctx, cfg.OrganizationID)
	}
	return nil
}

func (s *TelegramService) Notify(ctx context.Context, orgID uuid.UUID, eventType models.TelegramEventType, deviceMAC, deviceName, ipAddress, accessPoint string) error {
	cfg, err := s.repo.GetConfig(ctx, orgID)
	if err != nil || cfg == nil || !cfg.Enabled {
		return nil
	}

	switch eventType {
	case models.TelegramEventConnect:
		if !cfg.NotifyConnect {
			return nil
		}
	case models.TelegramEventDisconnect:
		if !cfg.NotifyDisconnect {
			return nil
		}
	case models.TelegramEventNewDevice:
		if !cfg.NotifyNewDevice {
			return nil
		}
	case models.TelegramEventPolicyViolation:
		if !cfg.NotifyPolicyViolation {
			return nil
		}
	}

	now := time.Now()
	dayDate := now.Truncate(24 * time.Hour)
	graceDuration := time.Duration(cfg.GracePeriodMinutes) * time.Minute

	recent, err := s.repo.HasRecentEvent(ctx, orgID, string(eventType), deviceMAC, graceDuration)
	if err != nil {
		log.Printf("Telegram: error checking recent event: %v", err)
	}
	if recent {
		return nil
	}

	if cfg.OncePerDay {
		sentToday, err := s.repo.HasSentToday(ctx, orgID, string(eventType), deviceMAC, dayDate)
		if err != nil {
			log.Printf("Telegram: error checking daily sent: %v", err)
		}
		if sentToday {
			return nil
		}
	}

	msg := s.formatMessage(eventType, deviceName, deviceMAC, ipAddress, accessPoint)
	if err := s.sendTelegram(ctx, cfg.BotToken, cfg.ChatID, msg); err != nil {
		return fmt.Errorf("send telegram: %w", err)
	}

	history := &models.TelegramNotificationHistory{
		ID:             uuid.New(),
		OrganizationID: orgID,
		DeviceMAC:      deviceMAC,
		DeviceName:     deviceName,
		IPAddress:      ipAddress,
		AccessPoint:    accessPoint,
		EventType:      string(eventType),
		SentAt:         now,
		DayDate:        dayDate,
	}
	if err := s.repo.InsertHistory(ctx, history); err != nil {
		log.Printf("Telegram: error inserting history: %v", err)
	}

	if s.hub != nil {
		s.hub.BroadcastMessage("notification", models.LiveNotification{
			Title:    fmt.Sprintf("Telegram: %s", eventType),
			Message:  msg,
			Type:     "telegram_" + string(eventType),
			DeviceID: deviceMAC,
		})
	}

	_ = s.repo.CleanupOldHistory(ctx, orgID, now.Add(-7*24*time.Hour))
	return nil
}

func (s *TelegramService) formatMessage(eventType models.TelegramEventType, deviceName, deviceMAC, ipAddress, accessPoint string) string {
	emoji := telegramEmoji[eventType]
	if emoji == "" {
		emoji = "\xF0\x9F\x94\x94"
	}
	var title string
	switch eventType {
	case models.TelegramEventConnect:
		title = "Device Connected to WiFi"
	case models.TelegramEventDisconnect:
		title = "Device Disconnected"
	case models.TelegramEventNewDevice:
		title = "Unknown Device Joined"
	case models.TelegramEventPolicyViolation:
		title = "Policy Violation"
	}
	var b strings.Builder
	b.WriteString(fmt.Sprintf("%s *%s*\n", emoji, title))
	b.WriteString(fmt.Sprintf("Device: `%s`\n", deviceName))
	if deviceMAC != "" {
		b.WriteString(fmt.Sprintf("MAC: `%s`\n", deviceMAC))
	}
	if ipAddress != "" {
		b.WriteString(fmt.Sprintf("IP: `%s`\n", ipAddress))
	}
	if accessPoint != "" {
		b.WriteString(fmt.Sprintf("AP: `%s`\n", accessPoint))
	}
	b.WriteString(fmt.Sprintf("Time: %s", time.Now().Format("2006-01-02 15:04:05")))
	return b.String()
}

type telegramSendBody struct {
	ChatID              string `json:"chat_id"`
	Text                string `json:"text"`
	ParseMode           string `json:"parse_mode"`
	DisableNotification bool   `json:"disable_notification"`
}

func (s *TelegramService) sendTelegram(ctx context.Context, botToken, chatID, text string) error {
	url := fmt.Sprintf("https://api.telegram.org/bot%s/sendMessage", botToken)
	body := telegramSendBody{
		ChatID:              chatID,
		Text:                text,
		ParseMode:           "Markdown",
		DisableNotification: false,
	}
	data, err := json.Marshal(body)
	if err != nil {
		return err
	}
	req, err := http.NewRequestWithContext(ctx, http.MethodPost, url, bytes.NewReader(data))
	if err != nil {
		return err
	}
	req.Header.Set("Content-Type", "application/json")
	resp, err := s.client.Do(req)
	if err != nil {
		return err
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		respBody, _ := io.ReadAll(resp.Body)
		return fmt.Errorf("telegram API returned %d: %s", resp.StatusCode, string(respBody))
	}
	return nil
}

func (s *TelegramService) startMidnightReset(ctx context.Context, orgID uuid.UUID) {
	s.mu.Lock()
	if cancel, ok := s.midnightCancel[orgID]; ok {
		cancel()
	}
	ctx, cancel := context.WithCancel(ctx)
	s.midnightCancel[orgID] = cancel
	s.mu.Unlock()

	now := time.Now()
	nextMidnight := now.Truncate(24 * time.Hour).Add(24 * time.Hour)
	duration := nextMidnight.Sub(now)

	go func() {
		select {
		case <-time.After(duration):
			_ = s.repo.CleanupOldHistory(ctx, orgID, time.Now().Add(-30*24*time.Hour))
			log.Printf("Telegram: midnight reset for org %s", orgID)
			s.startMidnightReset(ctx, orgID)
		case <-ctx.Done():
		}
	}()
}

package middleware

import (
	"context"
	"net"
	"net/http"
	"strconv"
	"strings"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
	"github.com/hospital/nms-backend/internal/models"
	"github.com/hospital/nms-backend/pkg/logger"
)

// AuditStore keeps audit entries.
type AuditStore interface {
	Create(ctx context.Context, log *models.AuditLog) error
}

// Requests that change nothing, or that the app sends on its own.
var auditSkip = []string{"/sites/check", "/development/mikrotik/connect"}

// AuditSkipKey lets a handler keep a request out of the audit log.
const AuditSkipKey = "audit_skip"

// AuditDetailKey lets a handler say what was done. Request bodies are never logged,
// because they can hold passwords.
const AuditDetailKey = "audit_detail"

// AuditTrail records every request that changes something: who, what and the result.
func AuditTrail(store AuditStore) gin.HandlerFunc {
	return func(c *gin.Context) {
		c.Next()
		action := ""
		switch c.Request.Method {
		case http.MethodPost:
			action = "create"
		case http.MethodPut, http.MethodPatch:
			action = "update"
		case http.MethodDelete:
			action = "delete"
		default:
			return
		}
		path := c.Request.URL.Path
		for _, s := range auditSkip {
			if strings.HasSuffix(path, s) {
				return
			}
		}
		if c.GetBool(AuditSkipKey) {
			return
		}
		orgID, err := uuid.Parse(c.GetString("org_id"))
		if err != nil {
			return
		}
		status := c.Writer.Status()
		description := c.Request.Method + " " + strings.TrimPrefix(path, "/api/v1")
		if detail := c.GetString(AuditDetailKey); detail != "" {
			description = detail
		}
		entity := auditEntity(path)
		entry := &models.AuditLog{
			ID: uuid.New(), OrganizationID: orgID, Action: action, EntityType: entity, EntityName: &entity,
			Description: &description, IsSuccess: status < 400, Timestamp: time.Now(),
		}
		if id, err := uuid.Parse(c.GetString("user_id")); err == nil {
			entry.PerformedBy = &id
		}
		if ip := net.ParseIP(c.ClientIP()); ip != nil {
			entry.IPAddress = &ip
		}
		if status >= 400 {
			reason := "HTTP " + strconv.Itoa(status)
			entry.FailureReason = &reason
		}
		ctx, cancel := context.WithTimeout(context.Background(), 3*time.Second)
		defer cancel()
		if err := store.Create(ctx, entry); err != nil {
			logger.Warn("Audit entry not stored", "path", path, "error", err)
		}
	}
}

// auditEntity names what a request was about: the part of the API it went to.
func auditEntity(path string) string {
	for _, part := range strings.Split(strings.TrimPrefix(path, "/api/v1/"), "/") {
		if part != "" {
			return part
		}
	}
	return "system"
}

package middleware

import (
	"net/http"
	"strings"

	"github.com/gin-gonic/gin"
	"github.com/hospital/nms-backend/internal/config"
	"github.com/hospital/nms-backend/internal/security"
)

func JWTAuth(cfg *config.Config) gin.HandlerFunc {
	jwtManager := security.NewJWTManager(cfg)

	return func(c *gin.Context) {
		authHeader := c.GetHeader("Authorization")
		if authHeader == "" {
			c.AbortWithStatusJSON(http.StatusUnauthorized, gin.H{
				"success": false,
				"message": "Authorization header is required",
				"error_code": "MISSING_AUTH",
			})
			return
		}

		parts := strings.SplitN(authHeader, " ", 2)
		if len(parts) != 2 || !strings.EqualFold(parts[0], "Bearer") {
			c.AbortWithStatusJSON(http.StatusUnauthorized, gin.H{
				"success": false,
				"message": "Invalid authorization header format",
				"error_code": "INVALID_AUTH_FORMAT",
			})
			return
		}

		claims, err := jwtManager.ValidateAccessToken(parts[1])
		if err != nil {
			c.AbortWithStatusJSON(http.StatusUnauthorized, gin.H{
				"success": false,
				"message": "Invalid or expired token",
				"error_code": "INVALID_TOKEN",
			})
			return
		}

		c.Set("user_id", claims.UserID.String())
		c.Set("role", claims.Role)
		c.Set("org_id", claims.OrgID.String())

		c.Next()
	}
}

func RoleAuthorization(requiredRoles ...string) gin.HandlerFunc {
	return func(c *gin.Context) {
		userRole, exists := c.Get("role")
		if !exists {
			c.AbortWithStatusJSON(http.StatusForbidden, gin.H{
				"success": false,
				"message": "Access denied",
				"error_code": "FORBIDDEN",
			})
			return
		}

		roleStr := userRole.(string)
		hasRole := false
		for _, required := range requiredRoles {
			if strings.EqualFold(roleStr, required) {
				hasRole = true
				break
			}
		}

		if !hasRole {
			c.AbortWithStatusJSON(http.StatusForbidden, gin.H{
				"success": false,
				"message": "Insufficient permissions",
				"error_code": "INSUFFICIENT_PERMISSIONS",
			})
			return
		}

		c.Next()
	}
}

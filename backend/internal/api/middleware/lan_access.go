package middleware

import (
	"crypto/subtle"
	"net"
	"net/http"
	"strings"

	"github.com/gin-gonic/gin"
)

// AccessKeyHeader carries the key other PCs need to use this server.
const AccessKeyHeader = "X-NMS-Key"

// LANAccess keeps the server to this PC and to apps holding the access key. This
// server can change the router and asks for no login, and phones share its network.
// Without a key set, only this PC gets in.
func LANAccess(key string) gin.HandlerFunc {
	return func(c *gin.Context) {
		host, _, err := net.SplitHostPort(c.Request.RemoteAddr)
		if err == nil {
			if ip := net.ParseIP(host); ip != nil && ip.IsLoopback() {
				c.Next()
				return
			}
		}
		// Lets another PC tell "the server is off" from "the key is wrong".
		if strings.HasSuffix(c.Request.URL.Path, "/api/v1/health") || strings.HasSuffix(c.Request.URL.Path, "/api/v1/ping") {
			c.Next()
			return
		}
		got := c.GetHeader(AccessKeyHeader)
		if key != "" && subtle.ConstantTimeCompare([]byte(got), []byte(key)) == 1 {
			c.Next()
			return
		}
		c.AbortWithStatusJSON(http.StatusForbidden, gin.H{"success": false, "message": "This PC is not allowed to use the NMS server", "error_code": "FORBIDDEN"})
	}
}

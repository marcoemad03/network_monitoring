package middleware

import (
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/gin-gonic/gin"
)

func TestLANAccess(t *testing.T) {
	gin.SetMode(gin.TestMode)
	build := func(key string) *gin.Engine {
		r := gin.New()
		r.Use(LANAccess(key))
		ok := func(c *gin.Context) { c.Status(http.StatusOK) }
		r.GET("/api/v1/health", ok)
		r.POST("/api/v1/marco/terminal", ok)
		r.GET("/ws/alerts", ok)
		return r
	}
	cases := []struct {
		name, serverKey, remote, method, path, sent string
		want                                        int
	}{
		{"this PC needs no key", "k1", "127.0.0.1:5000", "POST", "/api/v1/marco/terminal", "", 200},
		{"this PC over IPv6", "k1", "[::1]:5000", "POST", "/api/v1/marco/terminal", "", 200},
		{"another PC with the key", "k1", "172.16.0.60:5000", "POST", "/api/v1/marco/terminal", "k1", 200},
		{"another PC with no key", "k1", "172.16.0.60:5000", "POST", "/api/v1/marco/terminal", "", 403},
		{"another PC with a wrong key", "k1", "172.16.0.60:5000", "POST", "/api/v1/marco/terminal", "k2", 403},
		{"live updates need the key too", "k1", "172.16.0.60:5000", "GET", "/ws/alerts", "", 403},
		{"anyone can see the server is up", "k1", "172.16.0.60:5000", "GET", "/api/v1/health", "", 200},
		{"no key set: only this PC", "", "172.16.0.60:5000", "POST", "/api/v1/marco/terminal", "", 403},
		{"no key set: an empty key is no key", "", "172.16.0.60:5000", "GET", "/ws/alerts", "", 403},
	}
	for _, c := range cases {
		req := httptest.NewRequest(c.method, c.path, nil)
		req.RemoteAddr = c.remote
		if c.sent != "" {
			req.Header.Set(AccessKeyHeader, c.sent)
		}
		rec := httptest.NewRecorder()
		build(c.serverKey).ServeHTTP(rec, req)
		if rec.Code != c.want {
			t.Errorf("%s: got %d, want %d", c.name, rec.Code, c.want)
		}
	}
}

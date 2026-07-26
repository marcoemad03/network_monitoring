package middleware

import (
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"

	"github.com/gin-gonic/gin"
)

func TestDevelopmentAuthContextAllowsRequestWithoutToken(t *testing.T) {
	gin.SetMode(gin.TestMode)
	router := gin.New()
	router.Use(DevelopmentAuthContext())
	router.GET("/network", func(c *gin.Context) {
		c.JSON(http.StatusOK, gin.H{
			"org_id":  c.GetString("org_id"),
			"user_id": c.GetString("user_id"),
			"role":    c.GetString("role"),
		})
	})

	recorder := httptest.NewRecorder()
	router.ServeHTTP(recorder, httptest.NewRequest(http.MethodGet, "/network", nil))

	if recorder.Code != http.StatusOK {
		t.Fatalf("expected development request without JWT to succeed, got %d", recorder.Code)
	}
	for _, expected := range []string{DevelopmentOrganizationID, DevelopmentUserID, "super_admin"} {
		if body := recorder.Body.String(); !strings.Contains(body, expected) {
			t.Fatalf("expected response to contain %q, got %s", expected, body)
		}
	}
}

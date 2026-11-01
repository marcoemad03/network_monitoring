package handlers

import (
	"net/http/httptest"
	"testing"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
)

func TestCtxUUIDAcceptsStringAndUUID(t *testing.T) {
	gin.SetMode(gin.TestMode)
	c, _ := gin.CreateTestContext(httptest.NewRecorder())
	id := uuid.New()

	c.Set("as_string", id.String())
	c.Set("as_uuid", id)
	c.Set("garbage", "not-a-uuid")

	if got := ctxUUID(c, "as_string"); got != id {
		t.Fatalf("string value: got %s want %s", got, id)
	}
	if got := ctxUUID(c, "as_uuid"); got != id {
		t.Fatalf("uuid value: got %s want %s", got, id)
	}
	if got := ctxUUID(c, "garbage"); got != uuid.Nil {
		t.Fatalf("unparsable value: got %s want Nil", got)
	}
}

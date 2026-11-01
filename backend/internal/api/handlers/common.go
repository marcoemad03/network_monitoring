package handlers

import (
	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
)

func parseUUID(s string) (uuid.UUID, error) {
	return uuid.Parse(s)
}

// ctxUUID reads an ID that the auth middleware stored on the request context.
// The middleware stores it as a string, so a hard uuid.UUID assertion panics;
// an unparsable or missing value yields uuid.Nil.
func ctxUUID(c *gin.Context, key string) uuid.UUID {
	switch v := c.MustGet(key).(type) {
	case uuid.UUID:
		return v
	case string:
		id, err := uuid.Parse(v)
		if err != nil {
			return uuid.Nil
		}
		return id
	}
	return uuid.Nil
}

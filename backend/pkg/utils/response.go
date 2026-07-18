package utils

import "github.com/gin-gonic/gin"

type Meta struct {
	Page       int `json:"page,omitempty"`
	Limit      int `json:"limit,omitempty"`
	Total      int `json:"total,omitempty"`
	TotalPages int `json:"total_pages,omitempty"`
}

type APIResponse struct {
	Success bool        `json:"success"`
	Data    interface{} `json:"data,omitempty"`
	Message string      `json:"message,omitempty"`
	Meta    *Meta       `json:"meta,omitempty"`
	Errors  interface{} `json:"errors,omitempty"`
}

func Success(c *gin.Context, status int, data interface{}, message string) {
	c.JSON(status, APIResponse{
		Success: true,
		Data:    data,
		Message: message,
	})
}

func SuccessWithMeta(c *gin.Context, status int, data interface{}, message string, meta *Meta) {
	c.JSON(status, APIResponse{
		Success: true,
		Data:    data,
		Message: message,
		Meta:    meta,
	})
}

func Error(c *gin.Context, status int, message string, errorCode string, errors interface{}) {
	c.JSON(status, APIResponse{
		Success: false,
		Message: message,
		Errors: map[string]interface{}{
			"code":    errorCode,
			"details": errors,
		},
	})
}

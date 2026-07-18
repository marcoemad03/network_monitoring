package routes

import (
	"github.com/gin-gonic/gin"
	"github.com/hospital/nms-backend/internal/api/handlers"
	"github.com/hospital/nms-backend/internal/api/middleware"
	"github.com/hospital/nms-backend/internal/config"
	"github.com/hospital/nms-backend/internal/database"
	"github.com/hospital/nms-backend/internal/repository"
	"github.com/hospital/nms-backend/internal/security"
	"github.com/hospital/nms-backend/internal/services"
	"github.com/hospital/nms-backend/internal/websocket"
)

func RegisterRoutes(router *gin.Engine, db *database.DB, hub *websocket.Hub, cfg *config.Config) {
	jwtManager := security.NewJWTManager(cfg)

	userRepo := repository.NewUserRepository(db)
	deviceRepo := repository.NewDeviceRepository(db)
	alertRepo := repository.NewAlertRepository(db)
	scanRepo := repository.NewScanRepository(db)
	auditRepo := repository.NewAuditRepository(db)
	sessionRepo := repository.NewSessionRepository(db)
	permRepo := repository.NewPermissionRepository(db)
	monRepo := repository.NewMonitoringRepository(db)
	internetRepo := repository.NewInternetRepository(db)

	authService := services.NewAuthService(userRepo, sessionRepo, jwtManager, cfg)
	deviceService := services.NewDeviceService(deviceRepo, alertRepo, auditRepo)
	alertService := services.NewAlertService(alertRepo)
	permService := services.NewPermissionService(permRepo, userRepo)
	monitoringService := services.NewMonitoringService(monRepo, deviceRepo)
	internetService := services.NewInternetService(internetRepo)

	authHandler := handlers.NewAuthHandler(authService, userRepo)
	deviceHandler := handlers.NewDeviceHandler(deviceService)
	alertHandler := handlers.NewAlertHandler(alertService)
	scanHandler := handlers.NewScanHandler(scanRepo)
	auditHandler := handlers.NewAuditHandler(auditRepo)
	userHandler := handlers.NewUserHandler(userRepo)
	permHandler := handlers.NewPermissionHandler(permService)
	monitoringHandler := handlers.NewMonitoringHandler(monitoringService)
	internetHandler := handlers.NewInternetHandler(internetService)

	api := router.Group("/api/v1")
	api.Use(middleware.CorrelationID())
	api.Use(middleware.RequestLogger())
	api.Use(middleware.RateLimiter(cfg))

	api.GET("/health", func(c *gin.Context) {
		c.JSON(200, gin.H{"status": "ok", "service": "hospital-nms"})
	})

	auth := api.Group("/auth")
	{
		auth.POST("/login", authHandler.Login)
		auth.POST("/refresh", authHandler.RefreshToken)
		auth.POST("/logout", authHandler.Logout)
		auth.POST("/forgot-password", authHandler.ForgotPassword)
		auth.POST("/reset-password", authHandler.ResetPassword)
	}

	protected := api.Group("")
	protected.Use(middleware.JWTAuth(cfg))
	{
		protected.GET("/auth/me", authHandler.GetCurrentUser)

		devices := protected.Group("/devices")
		{
			devices.GET("", deviceHandler.List)
			devices.GET("/:id", deviceHandler.Get)
			devices.POST("", deviceHandler.Create)
			devices.PUT("/:id", deviceHandler.Update)
			devices.DELETE("/:id", deviceHandler.Delete)
			devices.GET("/:id/interfaces", deviceHandler.GetInterfaces)
			devices.GET("/:id/metrics", deviceHandler.GetMetrics)
			devices.GET("/:id/metrics/latest", monitoringHandler.GetDeviceLatestMetrics)
			devices.GET("/:id/metrics/history", monitoringHandler.GetDeviceMetricsHistory)
			devices.GET("/:id/ping", monitoringHandler.GetDevicePingHistory)
			devices.GET("/:id/traffic", monitoringHandler.GetDeviceTrafficHistory)
			devices.GET("/:id/clients", monitoringHandler.GetDeviceClients)
		}

		alerts := protected.Group("/alerts")
		{
			alerts.GET("", alertHandler.List)
			alerts.GET("/:id", alertHandler.Get)
			alerts.POST("/:id/acknowledge", alertHandler.Acknowledge)
			alerts.POST("/:id/resolve", alertHandler.Resolve)
		}

		scans := protected.Group("/scans")
		{
			scans.GET("", scanHandler.List)
			scans.POST("", scanHandler.Start)
			scans.GET("/:id", scanHandler.Get)
			scans.POST("/:id/cancel", scanHandler.Cancel)
		}

		users := protected.Group("/users")
		{
			users.GET("", middleware.RoleAuthorization("super_admin", "network_admin"), userHandler.List)
			users.GET("/:id", middleware.RoleAuthorization("super_admin", "network_admin"), userHandler.Get)
			users.POST("", middleware.RoleAuthorization("super_admin"), userHandler.Create)
			users.PUT("/:id", middleware.RoleAuthorization("super_admin"), userHandler.Update)
			users.DELETE("/:id", middleware.RoleAuthorization("super_admin"), userHandler.Delete)
			users.POST("/:id/reset-password", middleware.RoleAuthorization("super_admin"), userHandler.AdminResetPassword)
		}

		protected.GET("/auth/me/permissions", userHandler.GetPermissions)
		protected.POST("/auth/change-password", userHandler.ChangePassword)

		sessions := protected.Group("/sessions")
		{
			sessions.GET("", authHandler.ListSessions)
			sessions.DELETE("/:id", authHandler.RevokeSession)
			sessions.DELETE("", authHandler.RevokeAllSessions)
		}

		roles := protected.Group("/roles")
		{
			roles.GET("", permHandler.ListRoles)
			roles.GET("/:id", permHandler.GetRole)
			roles.POST("", middleware.RoleAuthorization("super_admin"), permHandler.CreateRole)
			roles.PUT("/:id", middleware.RoleAuthorization("super_admin"), permHandler.UpdateRole)
			roles.DELETE("/:id", middleware.RoleAuthorization("super_admin"), permHandler.DeleteRole)
			roles.POST("/:id/permissions", middleware.RoleAuthorization("super_admin"), permHandler.AssignPermission)
			roles.DELETE("/:id/permissions/:permissionId", middleware.RoleAuthorization("super_admin"), permHandler.RemovePermission)
		}

		permissions := protected.Group("/permissions")
		{
			permissions.GET("", permHandler.ListPermissions)
			permissions.GET("/all-with-roles", permHandler.GetAllRolesWithPermissions)
		}

		protected.GET("/audit-logs", auditHandler.List)
		protected.GET("/audit-logs/export", auditHandler.Export)

		monitoring := protected.Group("/monitoring")
		{
			monitoring.GET("/dashboard", monitoringHandler.GetDashboardSummary)
			monitoring.GET("/clients", monitoringHandler.GetAllClients)
			monitoring.GET("/connections", monitoringHandler.GetConnections)
		}

		internetPolicies := protected.Group("/internet-policies")
		{
			internetPolicies.GET("", internetHandler.ListPolicies)
			internetPolicies.GET("/:id", internetHandler.GetPolicy)
			internetPolicies.POST("", internetHandler.CreatePolicy)
			internetPolicies.PUT("/:id", internetHandler.UpdatePolicy)
			internetPolicies.DELETE("/:id", internetHandler.DeletePolicy)

			internetPolicies.GET("/:id/bandwidth-rules", internetHandler.ListBandwidthRules)
			internetPolicies.POST("/:id/bandwidth-rules", internetHandler.CreateBandwidthRule)
			internetPolicies.GET("/:id/filtering-rules", internetHandler.ListFilteringRules)
			internetPolicies.POST("/:id/filtering-rules", internetHandler.CreateFilteringRule)
			internetPolicies.GET("/:id/schedules", internetHandler.ListSchedules)
			internetPolicies.POST("/:id/schedules", internetHandler.CreateSchedule)
		}

		bandwidthRules := protected.Group("/bandwidth-rules")
		{
			bandwidthRules.PUT("/:id", internetHandler.UpdateBandwidthRule)
			bandwidthRules.DELETE("/:id", internetHandler.DeleteBandwidthRule)
			bandwidthRules.POST("/:id/temporary", internetHandler.SetTemporaryBandwidth)
			bandwidthRules.DELETE("/:id/temporary", internetHandler.ClearTemporaryBandwidth)
		}

		filteringRules := protected.Group("/filtering-rules")
		{
			filteringRules.PUT("/:id", internetHandler.UpdateFilteringRule)
			filteringRules.DELETE("/:id", internetHandler.DeleteFilteringRule)
		}

		schedules := protected.Group("/schedules")
		{
			schedules.PUT("/:id", internetHandler.UpdateSchedule)
			schedules.DELETE("/:id", internetHandler.DeleteSchedule)
		}

		deviceBlocks := protected.Group("/device-blocks")
		{
			deviceBlocks.GET("", internetHandler.ListDeviceBlocks)
			deviceBlocks.POST("", internetHandler.BlockDevice)
			deviceBlocks.DELETE("/:id", internetHandler.UnblockDevice)
		}

		vendorIntegrations := protected.Group("/vendor-integrations")
		{
			vendorIntegrations.GET("", internetHandler.ListVendorIntegrations)
			vendorIntegrations.GET("/:id", internetHandler.GetVendorIntegration)
			vendorIntegrations.POST("", internetHandler.CreateVendorIntegration)
			vendorIntegrations.PUT("/:id", internetHandler.UpdateVendorIntegration)
			vendorIntegrations.DELETE("/:id", internetHandler.DeleteVendorIntegration)
			vendorIntegrations.POST("/:id/test", internetHandler.TestVendorConnection)
			vendorIntegrations.POST("/:id/sync", internetHandler.SyncVendor)
		}

		protected.GET("/dashboard/summary", monitoringHandler.GetDashboardSummary)
	}

	router.GET("/ws/alerts", func(c *gin.Context) {
		websocket.ServeWS(hub, c.Writer, c.Request)
	})
	router.GET("/ws/metrics", func(c *gin.Context) {
		websocket.ServeWS(hub, c.Writer, c.Request)
	})
	router.GET("/ws/discovery", func(c *gin.Context) {
		websocket.ServeWS(hub, c.Writer, c.Request)
	})
	router.GET("/ws/dashboard", func(c *gin.Context) {
		websocket.ServeWS(hub, c.Writer, c.Request)
	})
}

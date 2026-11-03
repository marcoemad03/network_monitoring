package routes

import (
	"context"
	"strings"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/hospital/nms-backend/internal/api/handlers"
	"github.com/hospital/nms-backend/internal/api/middleware"
	"github.com/hospital/nms-backend/internal/config"
	"github.com/hospital/nms-backend/internal/database"
	"github.com/hospital/nms-backend/internal/repository"
	"github.com/hospital/nms-backend/internal/security"
	"github.com/hospital/nms-backend/internal/services"
	"github.com/hospital/nms-backend/internal/websocket"
	"github.com/hospital/nms-backend/pkg/logger"
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
	assetRepo := repository.NewAssetRepository(db)
	marcoRepo := repository.NewMarcoRepository(db)
	deviceCtrlRepo := repository.NewDeviceControlRepository(db)
	deviceEventRepo := repository.NewDeviceEventRepository(db)
	hotspotWelcomeRepo := repository.NewHotspotWelcomeRepository(db)

	// Reporting repositories
	webLogRepo := repository.NewWebLogRepository(db)
	connLogRepo := repository.NewConnectionLogRepository(db)
	downLogRepo := repository.NewDownloadLogRepository(db)
	reportCacheRepo := repository.NewReportCacheRepository(db)
	reportExportRepo := repository.NewReportExportRepository(db)
	alertRuleRepo := repository.NewAlertRuleRepository(db)
	alertNotifRepo := repository.NewAlertNotificationRepository(db)
	dashWidgetRepo := repository.NewDashboardWidgetRepository(db)

	authService := services.NewAuthService(userRepo, sessionRepo, jwtManager, cfg)
	deviceService := services.NewDeviceService(deviceRepo, alertRepo, auditRepo)
	alertService := services.NewAlertService(alertRepo)
	permService := services.NewPermissionService(permRepo, userRepo)
	monitoringService := services.NewMonitoringService(monRepo, deviceRepo)
	internetService := services.NewInternetService(internetRepo)
	discoveryService := services.NewDiscoveryService(deviceRepo, scanRepo, cfg)
	assetService := services.NewAssetService(assetRepo)
	telegramRepo := repository.NewTelegramRepository(db)
	telegramService := services.NewTelegramService(telegramRepo, hub)
	policySyncService := services.NewPolicySyncService(assetRepo, internetRepo, cfg, hub, telegramService)
	deviceControlService := services.NewDeviceControlService(deviceRepo, deviceCtrlRepo, monRepo, auditRepo)
	deviceEventService := services.NewDeviceEventService(deviceEventRepo, deviceRepo, alertRepo)
	enhancedDiscoverySvc := services.NewEnhancedDiscoveryService(deviceRepo, scanRepo, deviceEventRepo, deviceCtrlRepo, internetRepo, hub, cfg, telegramService)
	marcoGroupService := services.NewMarcoGroupService(marcoRepo, deviceRepo, internetRepo, cfg, hub, telegramService)
	marcoQuotaService := services.NewMarcoQuotaService(marcoRepo, internetRepo, cfg)
	marcoQuotaService.Start(context.Background(), 60*time.Second)
	wanRepo := repository.NewWANRepository(db)
	routerTelemetry := services.NewRouterTelemetryService(wanRepo, internetRepo, cfg)
	routerTelemetry.Start(context.Background(), cfg.RouterTelemetryInterval)
	wanHandler := handlers.NewWANHandler(routerTelemetry, wanRepo, cfg.RouterTelemetryInterval)
	clientRepo := repository.NewClientRepository(db)
	clientInventory := services.NewClientInventoryService(clientRepo, internetRepo, cfg)
	clientInventory.Start(context.Background(), cfg.RouterClientPollInterval, wanRepo.OrgsWithRouter)
	clientHandler := handlers.NewClientHandler(clientInventory)
	marcoGroupService.SetInventory(clientInventory, clientRepo)
	marcoGroupService.StartFollower(context.Background(), wanRepo.OrgsWithRouter)
	services.StartLogCleanup(context.Background(), cfg.LogCleanupFiles, cfg.LogKeepDays)
	topologyService := services.NewTopologyService(internetRepo, cfg)
	networkMapHandler := handlers.NewNetworkMapHandler(services.NewNetworkMapService(clientInventory, topologyService, clientRepo, monRepo))
	securityRepo := repository.NewSecurityRepository(db)
	securityScan := services.NewSecurityScanService(securityRepo, internetRepo, clientInventory, cfg)
	securityScan.Start(context.Background(), cfg.RouterSecurityScanInterval, wanRepo.OrgsWithRouter)
	securityHandler := handlers.NewSecurityHandler(securityScan, auditRepo)
	usageReportHandler := handlers.NewUsageReportHandler(services.NewUsageReportService(repository.NewUsageReportRepository(db), clientRepo, clientInventory, securityScan))
	dnsRepo := repository.NewDNSRepository(db)
	dnsCollector := services.NewDNSCollector(dnsRepo, clientInventory, cfg.DNSRetentionDays)
	dnsCollector.Start(context.Background(), wanRepo.OrgsWithRouter)
	dnsCollector.RegisterSource(services.SourceSyslog, cfg.DNSSyslogListen != "")
	dnsCollector.RegisterSource(services.SourcePihole, cfg.PiholeURL != "")
	if cfg.DNSSyslogListen != "" {
		if err := dnsCollector.StartSyslog(context.Background(), cfg.DNSSyslogListen, cfg.DNSSyslogAllow); err != nil {
			logger.Warn("DNS syslog listener not started", "error", err)
		}
	}
	if cfg.PiholeURL != "" && (cfg.PiholePassword != "" || cfg.PiholeToken != "") {
		dnsCollector.StartPihole(context.Background(), services.NewPiholeReader(cfg.PiholeURL, cfg.PiholePassword, cfg.PiholeToken, cfg.PiholeInsecureTLS), cfg.PiholePollInterval)
	} else if cfg.PiholeURL != "" {
		dnsCollector.SourceError(services.SourcePihole, "PIHOLE_URL is set but neither PIHOLE_PASSWORD nor PIHOLE_API_TOKEN is")
	}
	sitesHandler := handlers.NewSitesHandler(services.NewSitesService(dnsRepo, dnsCollector, clientInventory), auditRepo, cfg.DNSRetentionDays)
	hotspotWelcomeService := services.NewHotspotWelcomeService(hotspotWelcomeRepo)

	// Reporting services
	loggingService := services.NewLoggingService(webLogRepo, connLogRepo, downLogRepo)
	reportingService := services.NewReportingService(reportCacheRepo, reportExportRepo, webLogRepo)
	analyticsService := services.NewAnalyticsService(webLogRepo)
	dashboardService := services.NewDashboardService(dashWidgetRepo)

	authHandler := handlers.NewAuthHandler(authService, userRepo)
	deviceHandler := handlers.NewDeviceHandler(deviceService)
	alertHandler := handlers.NewAlertHandler(alertService)
	scanHandler := handlers.NewScanHandler(scanRepo, discoveryService, internetService)
	auditHandler := handlers.NewAuditHandler(auditRepo)
	userHandler := handlers.NewUserHandler(userRepo)
	permHandler := handlers.NewPermissionHandler(permService)
	monitoringHandler := handlers.NewMonitoringHandler(monitoringService)
	internetHandler := handlers.NewInternetHandler(internetService, scanRepo, discoveryService)
	assetHandler := handlers.NewAssetHandler(assetService, policySyncService)
	deviceCtrlHandler := handlers.NewDeviceControlHandler(deviceControlService, deviceEventService, enhancedDiscoverySvc, marcoGroupService)
	marcoGroupHandler := handlers.NewMarcoGroupHandler(marcoGroupService)
	hotspotWelcomeHandler := handlers.NewHotspotWelcomeHandler(hotspotWelcomeService)
	telegramHandler := handlers.NewTelegramHandler(telegramService)
	healthHandler := handlers.NewHealthHandler(db, enhancedDiscoverySvc)

	// Reporting handlers
	logsHandler := handlers.NewLogsHandler(loggingService)
	reportsHandler := handlers.NewReportsHandler(reportingService)
	exportsHandler := handlers.NewExportsHandler(reportingService)
	analyticsHandler := handlers.NewAnalyticsHandler(analyticsService)
	alertsHandler := handlers.NewAlertRulesHandler(alertRuleRepo, alertNotifRepo)
	dashboardHandler := handlers.NewDashboardHandler(dashboardService)

	api := router.Group("/api/v1")
	api.Use(middleware.CorrelationID())
	api.Use(middleware.RequestLogger())
	api.Use(middleware.RateLimiter(cfg))

	api.GET("/ping", func(c *gin.Context) {
		c.JSON(200, gin.H{"message": "pong"})
	})

	api.GET("/health", healthHandler.Check)
	api.POST("/development/mikrotik/connect", middleware.DevelopmentAuthContext(), deviceCtrlHandler.ConnectDevelopmentMikroTik)

	auth := api.Group("/auth")
	if !strings.EqualFold(cfg.Environment, "development") {
		auth.POST("/login", authHandler.Login)
		auth.POST("/refresh", authHandler.RefreshToken)
		auth.POST("/logout", authHandler.Logout)
		auth.POST("/forgot-password", authHandler.ForgotPassword)
		auth.POST("/reset-password", authHandler.ResetPassword)
	}

	protected := api.Group("")
	if strings.EqualFold(cfg.Environment, "development") {
		protected.Use(middleware.DevelopmentAuthContext())
	} else {
		protected.Use(middleware.JWTAuth(cfg))
	}
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
			scans.GET("/:id/devices", scanHandler.GetScanDevices)
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

		security := protected.Group("/security")
		{
			security.GET("/overview", securityHandler.Overview)
			security.POST("/scan", securityHandler.Scan)
			security.GET("/devices/:key", securityHandler.Device)
			security.GET("/sites", sitesHandler.Overview)
			security.GET("/sites/device/:key", sitesHandler.Device)
			security.GET("/sites/logo/:domain", sitesHandler.Logo)
			security.GET("/sites/detail/:domain", sitesHandler.Site)
			security.POST("/sites/adopt", sitesHandler.Adopt)
			security.POST("/catalog", sitesHandler.Create)
			security.PUT("/catalog/:id", sitesHandler.Update)
			security.DELETE("/catalog/:id", sitesHandler.Delete)
			security.POST("/catalog/:id/logo/fetch", sitesHandler.FetchLogo)
			security.PUT("/catalog/:id/logo", sitesHandler.UploadLogo)
			security.DELETE("/catalog/:id/logo", sitesHandler.ClearLogo)
		}

		monitoring := protected.Group("/monitoring")
		{
			monitoring.GET("/dashboard", monitoringHandler.GetDashboardSummary)
			monitoring.GET("/wan", wanHandler.Get)
			monitoring.GET("/equipment", monitoringHandler.GetEquipment)
			monitoring.GET("/clients/inventory", clientHandler.List)
			monitoring.PUT("/clients/inventory/:mac", clientHandler.UpdateNote)
			monitoring.GET("/clients/inventory/:mac/usage", clientHandler.Usage)
			monitoring.GET("/clients", monitoringHandler.GetAllClients)
			monitoring.GET("/connections", monitoringHandler.GetConnections)
			monitoring.GET("/network-map", networkMapHandler.Get)
			monitoring.PUT("/network-map/places/:port", networkMapHandler.SavePlace)
			monitoring.PUT("/network-map/device-places", networkMapHandler.SaveDevicePlaces)
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

		hotspotWelcome := protected.Group("/hotspot/welcome-page")
		{
			hotspotWelcome.GET("", hotspotWelcomeHandler.Get)
			hotspotWelcome.PUT("", middleware.RoleAuthorization("super_admin", "network_admin"), hotspotWelcomeHandler.Update)
			hotspotWelcome.GET("/login.html", hotspotWelcomeHandler.Download)
			hotspotWelcome.POST("/configure-profile", middleware.RoleAuthorization("super_admin", "network_admin"), hotspotWelcomeHandler.ConfigureProfile)
		}

		telegram := protected.Group("/telegram")
		{
			telegram.GET("/config", telegramHandler.GetConfig)
			telegram.PUT("/config", middleware.RoleAuthorization("super_admin", "network_admin"), telegramHandler.SaveConfig)
			telegram.POST("/test", middleware.RoleAuthorization("super_admin", "network_admin"), telegramHandler.Test)
		}

		// Reporting - Logs
		logs := protected.Group("/logs")
		{
			logs.GET("/web", logsHandler.GetWebLogs)
			logs.GET("/web/stats", logsHandler.GetWebLogStats)
			logs.GET("/connections", logsHandler.GetConnectionLogs)
			logs.GET("/connections/active", logsHandler.GetActiveConnections)
			logs.GET("/downloads", logsHandler.GetDownloadLogs)
		}

		// Reports
		reports := protected.Group("/reports")
		{
			reports.POST("/generate", reportsHandler.GenerateReport)
			reports.GET("", reportsHandler.GetReportsList)
			reports.GET("/detail", reportsHandler.GetReportDetail)
			reports.GET("/top-websites", reportsHandler.GetTopWebsites)
			reports.GET("/top-users", reportsHandler.GetTopUsers)
			reports.GET("/top-bandwidth", reportsHandler.GetTopBandwidthConsumers)
			reports.GET("/usage", usageReportHandler.Usage)
			reports.GET("/usage/export", usageReportHandler.Export)
			reports.GET("/departments", reportsHandler.GetDepartmentReports)
		}

		// Exports
		exports := protected.Group("/exports")
		{
			exports.POST("/generate", exportsHandler.GenerateExport)
			exports.GET("", exportsHandler.GetExportsList)
			exports.GET("/:id/download", exportsHandler.DownloadExport)
			exports.DELETE("/:id", exportsHandler.DeleteExport)
		}

		// Analytics
		analytics := protected.Group("/analytics")
		{
			analytics.GET("/bandwidth", analyticsHandler.GetBandwidthOverTime)
			analytics.GET("/summary", analyticsHandler.GetAnalyticsSummary)
			analytics.GET("/device/:id", analyticsHandler.GetDeviceAnalytics)
		}

		// Alert rules and notifications
		alerts = protected.Group("/alerts")
		{
			alerts.GET("/rules", alertsHandler.ListAlertRules)
			alerts.POST("/rules", alertsHandler.CreateAlertRule)
			alerts.PUT("/rules/:id", alertsHandler.UpdateAlertRule)
			alerts.DELETE("/rules/:id", alertsHandler.DeleteAlertRule)
			alerts.GET("/notifications", alertsHandler.ListNotifications)
			alerts.GET("/notifications/unread-count", alertsHandler.GetUnreadCount)
			alerts.PUT("/notifications/:id/read", alertsHandler.MarkAsRead)
			alerts.PUT("/notifications/:id/acknowledge", alertsHandler.Acknowledge)
		}

		// Dashboard Widgets
		dashWidgets := protected.Group("/dashboard/widgets")
		{
			dashWidgets.GET("", dashboardHandler.GetUserWidgets)
			dashWidgets.POST("", dashboardHandler.CreateWidget)
			dashWidgets.PUT("/:id", dashboardHandler.UpdateWidget)
			dashWidgets.DELETE("/:id", dashboardHandler.DeleteWidget)
			dashWidgets.PUT("/reorder", dashboardHandler.ReorderWidgets)
		}

		// Asset & Policy Management
		groups := protected.Group("/groups")
		{
			groups.GET("", assetHandler.ListGroups)
			groups.GET("/:id", assetHandler.GetGroup)
			groups.POST("", assetHandler.CreateGroup)
			groups.PUT("/:id", assetHandler.UpdateGroup)
			groups.DELETE("/:id", assetHandler.DeleteGroup)
			groups.POST("/:id/devices", assetHandler.AssignDevicesToGroup)
			groups.DELETE("/:id/devices/:deviceId", assetHandler.RemoveDeviceFromGroup)
			groups.GET("/:id/devices", assetHandler.GetGroupDevices)
			groups.GET("/:id/policies", assetHandler.GetPoliciesForGroup)
		}

		protected.GET("/devices/:id/groups", assetHandler.ListGroupsForDevice)
		protected.GET("/devices/:id/asset", assetHandler.GetAssetDetail)
		protected.POST("/devices/:id/asset", assetHandler.UpsertAssetDetail)

		floorMaps := protected.Group("/floor-maps")
		{
			floorMaps.GET("", assetHandler.ListFloorMaps)
			floorMaps.GET("/:id", assetHandler.GetFloorMap)
			floorMaps.POST("", assetHandler.CreateFloorMap)
			floorMaps.PUT("/:id", assetHandler.UpdateFloorMap)
			floorMaps.DELETE("/:id", assetHandler.DeleteFloorMap)
			floorMaps.GET("/:id/devices", assetHandler.GetFloorMapDevices)
			floorMaps.POST("/devices", assetHandler.PlaceDeviceOnMap)
			floorMaps.DELETE("/:id/devices/:deviceId", assetHandler.RemoveDeviceFromMap)
		}

		assetDetails := protected.Group("/assets")
		{
			assetDetails.GET("", assetHandler.ListAssetDetails)
			assetDetails.GET("/:deviceId", assetHandler.GetAssetDetail)
			assetDetails.POST("", assetHandler.UpsertAssetDetail)
		}

		policies := protected.Group("/policies")
		{
			policies.GET("", assetHandler.ListPolicies)
			policies.GET("/:id", assetHandler.GetPolicy)
			policies.POST("", assetHandler.CreatePolicy)
			policies.PUT("/:id", assetHandler.UpdatePolicy)
			policies.DELETE("/:id", assetHandler.DeletePolicy)
			policies.POST("/:id/groups", assetHandler.AssignPolicyToGroup)
			policies.DELETE("/:id/groups/:groupId", assetHandler.RemovePolicyFromGroup)
			policies.POST("/sync", assetHandler.SyncPolicies)
			policies.GET("/sync-logs", assetHandler.ListSyncLogs)
		}

		// Device Control
		deviceControl := protected.Group("/devices/:id/control")
		{
			deviceControl.POST("/disconnect", deviceCtrlHandler.DisconnectDevice)
			deviceControl.POST("/reconnect", deviceCtrlHandler.ReconnectDevice)
			deviceControl.POST("/block", deviceCtrlHandler.BlockInternet)
			deviceControl.POST("/unblock", deviceCtrlHandler.UnblockInternet)
			deviceControl.POST("/limit-speed", deviceCtrlHandler.LimitSpeed)
			deviceControl.POST("/unlimited-speed", deviceCtrlHandler.UnlimitedSpeed)
			deviceControl.POST("/rename", deviceCtrlHandler.RenameDevice)
			deviceControl.POST("/department", deviceCtrlHandler.ChangeDepartment)
			deviceControl.POST("/room", deviceCtrlHandler.ChangeRoom)
			deviceControl.POST("/move-group", deviceCtrlHandler.MoveToGroup)
			deviceControl.POST("/pin", deviceCtrlHandler.PinDevice)
			deviceControl.POST("/unpin", deviceCtrlHandler.UnpinDevice)
			deviceControl.POST("/mark-critical", deviceCtrlHandler.MarkCritical)
			deviceControl.POST("/unmark-critical", deviceCtrlHandler.UnmarkCritical)
			deviceControl.POST("/notes", deviceCtrlHandler.AddNotes)
			deviceControl.GET("/history", deviceCtrlHandler.GetDeviceHistory)
			deviceControl.POST("/reserve-dhcp", deviceCtrlHandler.ReserveDHCPIP)
			deviceControl.GET("/connections", deviceCtrlHandler.ViewActiveConnections)
			deviceControl.GET("/bandwidth", deviceCtrlHandler.ViewCurrentBandwidth)
			deviceControl.GET("/usage", deviceCtrlHandler.ViewHistoricalUsage)
		}

		// Device Events
		deviceEvents := protected.Group("/devices/:id/events")
		{
			deviceEvents.GET("", deviceCtrlHandler.GetDeviceEvents)
			deviceEvents.GET("/summary", deviceCtrlHandler.GetDeviceEventSummary)
		}
		protected.GET("/events", deviceCtrlHandler.GetOrganizationEvents)

		// Marco Groups policy engine
		marco := protected.Group("/marco")
		{
			marco.GET("/platforms", marcoGroupHandler.ListPlatforms)
			marco.GET("/groups", marcoGroupHandler.ListGroups)
			marco.GET("/groups/:id", marcoGroupHandler.GetGroup)
			marco.POST("/groups", marcoGroupHandler.CreateGroup)
			marco.PUT("/groups/:id", marcoGroupHandler.UpdateGroup)
			marco.DELETE("/groups/:id", marcoGroupHandler.DeleteGroup)
			marco.POST("/groups/:id/members", marcoGroupHandler.AddMembers)
			marco.DELETE("/groups/:id/members/:deviceId", marcoGroupHandler.RemoveMember)
			marco.PUT("/groups/:id/policy", marcoGroupHandler.UpdatePolicy)
			marco.POST("/sync", marcoGroupHandler.Sync)
			marco.GET("/logs", marcoGroupHandler.ListLogs)
			marco.GET("/groups/:id/details", marcoGroupHandler.Details)
			marco.GET("/sites/catalog", marcoGroupHandler.Catalog)
			marco.POST("/sites/check", marcoGroupHandler.CheckSite)
			marco.GET("/sites/status", marcoGroupHandler.SiteStatus)
			marco.POST("/sites/allowed", marcoGroupHandler.AddAllowed)
			marco.DELETE("/sites/allowed/:domain", marcoGroupHandler.RemoveAllowed)
			marco.GET("/overrides", marcoGroupHandler.ListOverrides)
			marco.PUT("/overrides/:mac", marcoGroupHandler.SetOverride)
			marco.DELETE("/overrides/:mac", marcoGroupHandler.DeleteOverride)
			marco.GET("/devices/status", marcoGroupHandler.DeviceStatuses)
		}

		// Enhanced Discovery
		protected.GET("/monitoring/connected-devices", deviceCtrlHandler.GetConnectedDevices)
		protected.POST("/vendors/:vendorId/discover", deviceCtrlHandler.DiscoverDevices)
		protected.POST("/vendors/:vendorId/polling/start", deviceCtrlHandler.StartPolling)
		protected.POST("/vendors/:vendorId/polling/stop", deviceCtrlHandler.StopPolling)
		protected.GET("/vendors/:vendorId/interfaces", deviceCtrlHandler.GetMikroTikInterfaces)
		protected.GET("/vendors/:vendorId/queues", deviceCtrlHandler.GetMikroTikQueues)
		protected.GET("/vendors/:vendorId/firewall", deviceCtrlHandler.GetMikroTikFirewallRules)
		protected.GET("/vendors/:vendorId/address-lists", deviceCtrlHandler.GetMikroTikAddressLists)
		protected.GET("/vendors/:vendorId/dns", deviceCtrlHandler.GetMikroTikDNS)
		protected.GET("/vendors/:vendorId/identity", deviceCtrlHandler.GetMikroTikRouterIdentity)
		protected.GET("/vendors/:vendorId/connections", deviceCtrlHandler.GetMikroTikActiveConnections)
		protected.GET("/vendors/:vendorId/dns-cache", deviceCtrlHandler.GetMikroTikDNSCache)
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

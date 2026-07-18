package main

import (
	"context"
	"fmt"
	"log"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/hospital/nms-backend/internal/api/routes"
	"github.com/hospital/nms-backend/internal/config"
	"github.com/hospital/nms-backend/internal/database"
	"github.com/hospital/nms-backend/internal/database/seeds"
	"github.com/hospital/nms-backend/internal/monitoring"
	"github.com/hospital/nms-backend/internal/websocket"
	"github.com/hospital/nms-backend/pkg/logger"
)

func main() {
	cfg, err := config.Load()
	if err != nil {
		log.Fatalf("Failed to load config: %v", err)
	}

	logger.Init(cfg.LogLevel, cfg.LogFormat)

	if cfg.JWTAccessSecret == "change-me" || cfg.JWTRefreshSecret == "change-me" {
		logger.Fatal("JWT secrets are set to default values. Change them in .env file")
	}

	logger.Info("Starting Hospital NMS Backend",
		"environment", cfg.Environment,
		"port", cfg.ServerPort,
	)

	db, err := database.NewPostgresDB(cfg)
	if err != nil {
		logger.Fatal("Failed to connect to database", "error", err)
	}
	defer db.Close()

	if err := seeds.Run(db); err != nil {
		logger.Warn("Failed to seed database", "error", err)
	}

	hub := websocket.NewHub(cfg.CORSAllowedOrigins)
	go hub.Run()

	monitor := monitoring.NewMonitor(db, hub, 30*time.Second)
	defer monitor.Stop()
	monitor.Start()

	snmpCollector := monitoring.NewSNMPCollector(db, hub)
	go snmpCollector.Start()

	router := gin.New()
	router.Use(gin.Recovery())
	router.Use(corsMiddleware(cfg))

	routes.RegisterRoutes(router, db, hub, cfg)

	srv := &http.Server{
		Addr:         fmt.Sprintf("%s:%d", cfg.ServerHost, cfg.ServerPort),
		Handler:      router,
		ReadTimeout:  15 * time.Second,
		WriteTimeout: 15 * time.Second,
		IdleTimeout:  60 * time.Second,
	}

	go func() {
		logger.Info("Server listening", "address", srv.Addr)
		if err := srv.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			logger.Fatal("Server failed to start", "error", err)
		}
	}()

	quit := make(chan os.Signal, 1)
	signal.Notify(quit, syscall.SIGINT, syscall.SIGTERM)
	<-quit

	logger.Info("Shutting down server...")

	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()

	if err := srv.Shutdown(ctx); err != nil {
		logger.Fatal("Server forced to shutdown", "error", err)
	}

	logger.Info("Server exited")
}

func corsMiddleware(cfg *config.Config) gin.HandlerFunc {
	return func(c *gin.Context) {
		c.Header("Access-Control-Allow-Origin", cfg.CORSAllowedOrigins)
		c.Header("Access-Control-Allow-Methods", cfg.CORSAllowedMethods)
		c.Header("Access-Control-Allow-Headers", "Origin, Content-Type, Accept, Authorization, X-Correlation-ID")
		c.Header("Access-Control-Expose-Headers", "X-Correlation-ID")
		c.Header("Access-Control-Allow-Credentials", "true")

		if c.Request.Method == http.MethodOptions {
			c.AbortWithStatus(http.StatusNoContent)
			return
		}

		c.Next()
	}
}

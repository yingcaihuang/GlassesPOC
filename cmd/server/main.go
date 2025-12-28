package main

import (
	"log"
	"smart-glasses-backend/internal/config"
	"smart-glasses-backend/internal/handler"
	"smart-glasses-backend/internal/middleware"
	"smart-glasses-backend/internal/repository"
	"smart-glasses-backend/internal/service"
	"smart-glasses-backend/pkg/azure"
	"smart-glasses-backend/pkg/database"

	"github.com/gin-gonic/gin"
)

func main() {
	// Load configuration
	cfg, err := config.Load()
	if err != nil {
		log.Fatalf("Failed to load config: %v", err)
	}

	// Initialize database connections
	db, err := database.NewPostgres(cfg.Database.PostgresDSN)
	if err != nil {
		log.Fatalf("Failed to connect to PostgreSQL: %v", err)
	}
	defer db.Close()

	redisClient, err := database.NewRedis(cfg.Database.RedisAddr, cfg.Database.RedisPassword)
	if err != nil {
		log.Fatalf("Failed to connect to Redis: %v", err)
	}
	defer redisClient.Close()

	// Initialize repositories
	userRepo := repository.NewUserRepository(db)
	translateRepo := repository.NewTranslateRepository(db)
	tokenRepo := repository.NewTokenRepository(db)

	// Initialize Azure OpenAI client
	azureClient := azure.NewOpenAIClient(
		cfg.Azure.Endpoint,
		cfg.Azure.APIKey,
		cfg.Azure.DeploymentName,
		cfg.Azure.APIVersion,
	)

	// Initialize services
	authService := service.NewAuthService(userRepo, redisClient, cfg.JWT.SecretKey, cfg.JWT.AccessTokenExpiry, cfg.JWT.RefreshTokenExpiry)
	userService := service.NewUserService(userRepo)
	translateService := service.NewTranslateService(azureClient, translateRepo, tokenRepo)
	statisticsService := service.NewStatisticsService(translateRepo, tokenRepo)
	
	// Initialize Realtime service with proper configuration
	// Requirements: 2.1 - 集成 Realtime 相关服务
	realtimeService := service.NewRealtimeService(
		cfg.Realtime.APIKey,
		cfg.Realtime.Endpoint,
		cfg.Realtime.DeploymentName,
		cfg.Realtime.APIVersion,
	)
	
	// Get security monitor from realtime service
	// Requirements: 9.5, 10.1, 10.2, 10.4, 10.5 - 安全和监控功能
	securityMonitor := realtimeService.GetSecurityMonitor()
	
	// Get performance monitor from realtime service
	// Requirements: 9.1, 9.2, 9.3, 9.4 - 性能优化和调试
	performanceMonitor := realtimeService.GetPerformanceMonitor()
	
	// Log successful initialization to ensure compatibility
	log.Printf("Realtime service initialized with endpoint: %s", cfg.Realtime.Endpoint)
	log.Printf("Realtime deployment: %s", cfg.Realtime.DeploymentName)
	log.Printf("Security monitoring enabled: privacy_mode=true, session_timeout=30m")
	log.Printf("Performance monitoring enabled: audio_latency_threshold=500ms")

	// Initialize handlers
	authHandler := handler.NewAuthHandler(authService)
	userHandler := handler.NewUserHandler(userService)
	translateHandler := handler.NewTranslateHandler(translateService)
	statisticsHandler := handler.NewStatisticsHandler(statisticsService)
	
	// Initialize Realtime handler
	// Requirements: 2.1 - 添加 /api/v1/realtime/chat WebSocket 路由
	realtimeHandler := handler.NewRealtimeHandler(realtimeService)
	
	// Initialize monitoring handler
	// Requirements: 9.5, 10.5 - 监控API端点
	monitoringHandler := handler.NewMonitoringHandler(securityMonitor)
	
	// Initialize performance handler
	// Requirements: 9.1, 9.2, 9.3, 9.4 - 性能监控API端点
	performanceHandler := handler.NewPerformanceHandler(performanceMonitor)

	// Setup router
	router := setupRouter(authHandler, userHandler, translateHandler, statisticsHandler, realtimeHandler, monitoringHandler, performanceHandler, securityMonitor, cfg)

	// Start server
	addr := ":" + cfg.Server.Port
	log.Printf("Server starting on %s", addr)
	if err := router.Run(addr); err != nil {
		log.Fatalf("Failed to start server: %v", err)
	}
}

func setupRouter(authHandler *handler.AuthHandler, userHandler *handler.UserHandler, translateHandler *handler.TranslateHandler, statisticsHandler *handler.StatisticsHandler, realtimeHandler *handler.RealtimeHandler, monitoringHandler *handler.MonitoringHandler, performanceHandler *handler.PerformanceHandler, securityMonitor *service.SecurityMonitor, cfg *config.Config) *gin.Engine {
	router := gin.Default()

	// Middleware
	router.Use(middleware.CORS())
	router.Use(middleware.Logger())
	// Requirements: 10.5 - 集成安全中间件进行访问日志记录（已修复死锁问题）
	router.Use(middleware.SecurityMiddleware(securityMonitor))

	// Health check
	router.GET("/health", func(c *gin.Context) {
		// Basic health check
		health := gin.H{
			"status": "ok",
			"services": gin.H{
				"database": "connected",
				"redis":    "connected",
			},
		}
		
		// Check if Realtime service is configured
		if cfg.Realtime.Endpoint != "" && cfg.Realtime.APIKey != "" {
			health["services"].(gin.H)["realtime"] = "configured"
		} else {
			health["services"].(gin.H)["realtime"] = "not_configured"
		}
		
		c.JSON(200, health)
	})

	// API v1 routes
	v1 := router.Group("/api/v1")
	{
		// Auth routes (public)
		auth := v1.Group("/auth")
		{
			auth.POST("/register", authHandler.Register)
			auth.POST("/login", authHandler.Login)
			auth.POST("/refresh", authHandler.Refresh)
		}

		// Protected routes
		protected := v1.Group("")
		protected.Use(middleware.AuthMiddleware(cfg.JWT.SecretKey))
		{
			// User routes
			user := protected.Group("/user")
			{
				user.GET("/profile", userHandler.GetProfile)
			}

			// Translate routes
			translate := protected.Group("/translate")
			{
				translate.POST("/text", translateHandler.TranslateText)
				translate.GET("/history", translateHandler.GetHistory)
			}

			// Statistics routes
			statistics := protected.Group("/statistics")
			{
				statistics.GET("", statisticsHandler.GetStatistics)
			}

			// Monitoring routes
			// Requirements: 9.5, 10.4, 10.5 - 监控API端点
			monitoring := protected.Group("/monitoring")
			{
				monitoring.GET("/sessions/stats", monitoringHandler.GetSessionStats)
				monitoring.GET("/sessions/active", monitoringHandler.GetActiveSessions)
				monitoring.GET("/logs", monitoringHandler.GetAccessLogs)
				monitoring.GET("/connection/:sessionId", monitoringHandler.GetConnectionQuality)
				monitoring.GET("/privacy", monitoringHandler.GetPrivacyStatus)
				monitoring.POST("/timeout", monitoringHandler.UpdateSessionTimeout)
				monitoring.POST("/enable", monitoringHandler.EnableMonitoring)
				monitoring.POST("/disable", monitoringHandler.DisableMonitoring)
				monitoring.POST("/check-timeouts", monitoringHandler.CheckSessionTimeouts)
			}

			// Performance monitoring routes
			// Requirements: 9.1, 9.2, 9.3, 9.4 - 性能优化和调试API端点
			performance := protected.Group("/performance")
			{
				performance.GET("/overview", performanceHandler.GetPerformanceOverview)
				performance.GET("/audio/:sessionId", performanceHandler.GetAudioLatencyMetrics)
				performance.GET("/websocket/:sessionId", performanceHandler.GetWebSocketMetrics)
				performance.GET("/resources", performanceHandler.GetResourceMetrics)
				performance.GET("/connection-pool", performanceHandler.GetConnectionPoolStats)
				performance.GET("/alerts", performanceHandler.GetPerformanceAlerts)
				performance.POST("/thresholds", performanceHandler.SetPerformanceThresholds)
				performance.POST("/enable", performanceHandler.EnablePerformanceMonitoring)
				performance.POST("/disable", performanceHandler.DisablePerformanceMonitoring)
				performance.POST("/optimize-websocket", performanceHandler.OptimizeWebSocketConnections)
			}
		}

		// WebSocket routes (protected)
		// Requirements: 2.1 - 添加 /api/v1/realtime/chat WebSocket 路由
		// Requirements: 10.1, 10.2 - 集成安全中间件
		v1.GET("/translate/stream", middleware.AuthWebSocket(cfg.JWT.SecretKey), translateHandler.TranslateStream)
		v1.GET("/realtime/chat", 
			middleware.AuthWebSocket(cfg.JWT.SecretKey), 
			// 使用简化的处理器进行测试
			realtimeHandler.HandleRealtimeConnection)
	}

	return router
}


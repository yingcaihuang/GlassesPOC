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

	// Initialize handlers
	authHandler := handler.NewAuthHandler(authService)
	userHandler := handler.NewUserHandler(userService)
	translateHandler := handler.NewTranslateHandler(translateService)
	statisticsHandler := handler.NewStatisticsHandler(statisticsService)

	// Setup router
	router := setupRouter(authHandler, userHandler, translateHandler, statisticsHandler, cfg)

	// Start server
	addr := ":" + cfg.Server.Port
	log.Printf("Server starting on %s", addr)
	if err := router.Run(addr); err != nil {
		log.Fatalf("Failed to start server: %v", err)
	}
}

func setupRouter(authHandler *handler.AuthHandler, userHandler *handler.UserHandler, translateHandler *handler.TranslateHandler, statisticsHandler *handler.StatisticsHandler, cfg *config.Config) *gin.Engine {
	router := gin.Default()

	// Middleware
	router.Use(middleware.CORS())
	router.Use(middleware.Logger())

	// Health check
	router.GET("/health", func(c *gin.Context) {
		c.JSON(200, gin.H{"status": "ok"})
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
		}

		// WebSocket route (protected)
		v1.GET("/translate/stream", middleware.AuthWebSocket(cfg.JWT.SecretKey), translateHandler.TranslateStream)
	}

	return router
}


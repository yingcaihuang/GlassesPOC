package middleware

import (
	"log"
	"net/http"
	"smart-glasses-backend/pkg/jwt"
	"strings"

	"github.com/gin-gonic/gin"
)

func AuthMiddleware(secretKey string) gin.HandlerFunc {
	return func(c *gin.Context) {
		authHeader := c.GetHeader("Authorization")
		if authHeader == "" {
			c.JSON(http.StatusUnauthorized, gin.H{"error": "authorization header required"})
			c.Abort()
			return
		}

		parts := strings.Split(authHeader, " ")
		if len(parts) != 2 || parts[0] != "Bearer" {
			c.JSON(http.StatusUnauthorized, gin.H{"error": "invalid authorization header format"})
			c.Abort()
			return
		}

		token := parts[1]
		claims, err := jwt.ValidateToken(token, secretKey)
		if err != nil {
			c.JSON(http.StatusUnauthorized, gin.H{"error": "invalid token"})
			c.Abort()
			return
		}

		c.Set("user_id", claims.UserID.String())
		c.Set("user_email", claims.Email)
		c.Next()
	}
}

func AuthWebSocket(secretKey string) gin.HandlerFunc {
	return func(c *gin.Context) {
		log.Printf("WebSocket auth middleware called for: %s", c.Request.URL.Path)
		
		token := c.Query("token")
		if token == "" {
			log.Printf("No token provided in WebSocket request")
			c.JSON(http.StatusUnauthorized, gin.H{"error": "token required"})
			c.Abort()
			return
		}

		log.Printf("Validating WebSocket token: %s...", token[:20])
		claims, err := jwt.ValidateToken(token, secretKey)
		if err != nil {
			log.Printf("WebSocket token validation failed: %v", err)
			c.JSON(http.StatusUnauthorized, gin.H{"error": "invalid token"})
			c.Abort()
			return
		}

		log.Printf("WebSocket token validated successfully for user: %s", claims.UserID.String())
		c.Set("user_id", claims.UserID.String())
		c.Set("user_email", claims.Email)
		c.Next()
	}
}


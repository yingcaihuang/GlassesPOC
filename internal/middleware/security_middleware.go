package middleware

import (
	"smart-glasses-backend/internal/service"
	"time"

	"github.com/gin-gonic/gin"
)

// SecurityMiddleware 安全中间件，集成访问日志记录
func SecurityMiddleware(securityMonitor *service.SecurityMonitor) gin.HandlerFunc {
	return func(c *gin.Context) {
		// 记录请求开始时间
		startTime := time.Now()
		
		// 获取用户信息（如果已认证）
		userID, _ := c.Get("user_id")
		userEmail, _ := c.Get("user_email")
		
		// 处理请求
		c.Next()
		
		// 计算处理时间
		duration := time.Since(startTime)
		
		// 记录访问日志
		userIDStr := ""
		userEmailStr := ""
		if userID != nil {
			userIDStr = userID.(string)
		}
		if userEmail != nil {
			userEmailStr = userEmail.(string)
		}
		
		// Requirements: 10.5 - 访问日志记录
		// 使用goroutine异步记录日志，避免阻塞请求处理
		go func() {
			securityMonitor.LogAccess(
				userIDStr,
				userEmailStr,
				"", // sessionID 在 WebSocket 连接中设置
				c.Request.Method,
				c.Request.URL.Path,
				c.Request.Method,
				c.ClientIP(),
				c.GetHeader("User-Agent"),
				c.Writer.Status(),
				duration,
				"", // 错误信息在具体处理中设置
			)
		}()
	}
}

// RealtimeSecurityMiddleware 实时连接安全中间件
func RealtimeSecurityMiddleware(securityMonitor *service.SecurityMonitor) gin.HandlerFunc {
	return func(c *gin.Context) {
		// 检查并发连接数限制
		activeSessions := securityMonitor.GetActiveSessions()
		if len(activeSessions) >= 100 { // 可配置的最大连接数
			c.JSON(429, gin.H{
				"error": "too many active connections",
				"user_message": "当前连接数过多，请稍后重试",
			})
			c.Abort()
			return
		}
		
		// 验证音频数据隐私保护
		if !securityMonitor.EnsureAudioDataPrivacy() {
			c.JSON(500, gin.H{
				"error": "privacy protection not enabled",
				"user_message": "隐私保护未启用，无法处理音频数据",
			})
			c.Abort()
			return
		}
		
		c.Next()
	}
}
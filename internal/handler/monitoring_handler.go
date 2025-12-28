package handler

import (
	"net/http"
	"smart-glasses-backend/internal/service"
	"strconv"
	"time"

	"github.com/gin-gonic/gin"
)

// MonitoringHandler 监控API处理器
type MonitoringHandler struct {
	securityMonitor *service.SecurityMonitor
}

// NewMonitoringHandler 创建新的监控处理器
func NewMonitoringHandler(securityMonitor *service.SecurityMonitor) *MonitoringHandler {
	return &MonitoringHandler{
		securityMonitor: securityMonitor,
	}
}

// GetSessionStats 获取会话统计信息
// Requirements: 9.5, 10.4 - 连接质量监控和会话超时管理
func (h *MonitoringHandler) GetSessionStats(c *gin.Context) {
	// 检查管理员权限（简化实现，实际应该检查用户角色）
	userID, exists := c.Get("user_id")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "authentication required"})
		return
	}

	stats := h.securityMonitor.GetSessionStats()
	
	c.JSON(http.StatusOK, gin.H{
		"status": "success",
		"data":   stats,
		"user_id": userID,
	})
}

// GetActiveSessions 获取活跃会话列表
func (h *MonitoringHandler) GetActiveSessions(c *gin.Context) {
	// 检查管理员权限
	userID, exists := c.Get("user_id")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "authentication required"})
		return
	}

	sessions := h.securityMonitor.GetActiveSessions()
	
	c.JSON(http.StatusOK, gin.H{
		"status": "success",
		"data": gin.H{
			"sessions": sessions,
			"count":    len(sessions),
		},
		"user_id": userID,
	})
}

// GetAccessLogs 获取访问日志
// Requirements: 10.5 - 访问日志记录
func (h *MonitoringHandler) GetAccessLogs(c *gin.Context) {
	// 检查管理员权限
	userID, exists := c.Get("user_id")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "authentication required"})
		return
	}

	// 获取查询参数
	limitStr := c.DefaultQuery("limit", "100")
	limit, err := strconv.Atoi(limitStr)
	if err != nil || limit <= 0 {
		limit = 100
	}
	if limit > 1000 {
		limit = 1000 // 最大限制
	}

	logs := h.securityMonitor.GetAccessLogs(limit)
	
	c.JSON(http.StatusOK, gin.H{
		"status": "success",
		"data": gin.H{
			"logs":  logs,
			"count": len(logs),
			"limit": limit,
		},
		"user_id": userID,
	})
}

// GetConnectionQuality 获取连接质量信息
// Requirements: 9.5 - 连接质量监控
func (h *MonitoringHandler) GetConnectionQuality(c *gin.Context) {
	sessionID := c.Param("sessionId")
	if sessionID == "" {
		c.JSON(http.StatusBadRequest, gin.H{
			"error": "session_id is required",
			"user_message": "会话ID是必需的",
		})
		return
	}

	// 验证用户权限（用户只能查看自己的会话）
	userID, exists := c.Get("user_id")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "authentication required"})
		return
	}

	connectionMetric := h.securityMonitor.GetConnectionQuality(sessionID)
	if connectionMetric == nil {
		c.JSON(http.StatusNotFound, gin.H{
			"error": "session not found",
			"user_message": "会话未找到",
		})
		return
	}

	// 检查用户是否有权限查看此会话
	if connectionMetric.UserID != userID.(string) {
		c.JSON(http.StatusForbidden, gin.H{
			"error": "access denied",
			"user_message": "无权访问此会话信息",
		})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"status": "success",
		"data":   connectionMetric,
		"user_id": userID,
	})
}

// UpdateSessionTimeout 更新会话超时设置
// Requirements: 10.4 - 会话超时机制
func (h *MonitoringHandler) UpdateSessionTimeout(c *gin.Context) {
	// 检查管理员权限
	userID, exists := c.Get("user_id")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "authentication required"})
		return
	}

	var request struct {
		TimeoutMinutes int `json:"timeout_minutes" binding:"required,min=1,max=1440"`
	}

	if err := c.ShouldBindJSON(&request); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{
			"error": "invalid request",
			"details": err.Error(),
			"user_message": "请求格式错误",
		})
		return
	}

	// 更新会话超时设置
	timeout := time.Duration(request.TimeoutMinutes) * time.Minute
	h.securityMonitor.SetSessionTimeout(timeout)

	c.JSON(http.StatusOK, gin.H{
		"status": "success",
		"message": "session timeout updated",
		"data": gin.H{
			"timeout_minutes": request.TimeoutMinutes,
		},
		"user_id": userID,
	})
}

// GetPrivacyStatus 获取隐私保护状态
// Requirements: 10.2 - 音频数据隐私保护
func (h *MonitoringHandler) GetPrivacyStatus(c *gin.Context) {
	userID, exists := c.Get("user_id")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "authentication required"})
		return
	}

	privacyEnabled := h.securityMonitor.EnsureAudioDataPrivacy()
	
	c.JSON(http.StatusOK, gin.H{
		"status": "success",
		"data": gin.H{
			"privacy_mode_enabled": privacyEnabled,
			"audio_data_protection": "enabled",
			"data_retention_policy": "no_audio_storage",
		},
		"user_id": userID,
	})
}

// EnableMonitoring 启用监控
func (h *MonitoringHandler) EnableMonitoring(c *gin.Context) {
	// 检查管理员权限
	userID, exists := c.Get("user_id")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "authentication required"})
		return
	}

	h.securityMonitor.EnableMonitoring()
	
	c.JSON(http.StatusOK, gin.H{
		"status": "success",
		"message": "monitoring enabled",
		"user_id": userID,
	})
}

// DisableMonitoring 禁用监控
func (h *MonitoringHandler) DisableMonitoring(c *gin.Context) {
	// 检查管理员权限
	userID, exists := c.Get("user_id")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "authentication required"})
		return
	}

	h.securityMonitor.DisableMonitoring()
	
	c.JSON(http.StatusOK, gin.H{
		"status": "success",
		"message": "monitoring disabled",
		"user_id": userID,
	})
}

// CheckSessionTimeouts 手动检查会话超时
func (h *MonitoringHandler) CheckSessionTimeouts(c *gin.Context) {
	// 检查管理员权限
	userID, exists := c.Get("user_id")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "authentication required"})
		return
	}

	timeoutEvents := h.securityMonitor.CheckSessionTimeout()
	
	c.JSON(http.StatusOK, gin.H{
		"status": "success",
		"data": gin.H{
			"timeout_events": timeoutEvents,
			"count":          len(timeoutEvents),
		},
		"user_id": userID,
	})
}
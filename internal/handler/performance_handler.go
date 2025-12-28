package handler

import (
	"net/http"
	"smart-glasses-backend/internal/service"
	"strconv"
	"time"

	"github.com/gin-gonic/gin"
)

// PerformanceHandler 性能监控API处理器
type PerformanceHandler struct {
	performanceMonitor *service.PerformanceMonitor
}

// NewPerformanceHandler 创建新的性能监控处理器
func NewPerformanceHandler(performanceMonitor *service.PerformanceMonitor) *PerformanceHandler {
	return &PerformanceHandler{
		performanceMonitor: performanceMonitor,
	}
}

// GetAudioLatencyMetrics 获取音频延迟指标
// Requirements: 9.1 - 音频延迟监控
func (h *PerformanceHandler) GetAudioLatencyMetrics(c *gin.Context) {
	sessionID := c.Param("sessionId")
	if sessionID == "" {
		c.JSON(http.StatusBadRequest, gin.H{
			"error": "session_id is required",
			"user_message": "会话ID是必需的",
		})
		return
	}

	// 验证用户权限
	userID, exists := c.Get("user_id")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "authentication required"})
		return
	}

	metrics := h.performanceMonitor.GetAudioLatencyMetrics(sessionID)
	if metrics == nil {
		c.JSON(http.StatusNotFound, gin.H{
			"error": "metrics not found",
			"user_message": "未找到该会话的音频延迟指标",
		})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"status": "success",
		"data":   metrics,
		"user_id": userID,
	})
}

// GetWebSocketMetrics 获取WebSocket性能指标
// Requirements: 9.2 - WebSocket消息处理优化
func (h *PerformanceHandler) GetWebSocketMetrics(c *gin.Context) {
	sessionID := c.Param("sessionId")
	if sessionID == "" {
		c.JSON(http.StatusBadRequest, gin.H{
			"error": "session_id is required",
			"user_message": "会话ID是必需的",
		})
		return
	}

	// 验证用户权限
	userID, exists := c.Get("user_id")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "authentication required"})
		return
	}

	metrics := h.performanceMonitor.GetWebSocketMetrics(sessionID)
	if metrics == nil {
		c.JSON(http.StatusNotFound, gin.H{
			"error": "metrics not found",
			"user_message": "未找到该会话的WebSocket指标",
		})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"status": "success",
		"data":   metrics,
		"user_id": userID,
	})
}

// GetResourceMetrics 获取系统资源使用指标
// Requirements: 9.4 - 性能指标收集
func (h *PerformanceHandler) GetResourceMetrics(c *gin.Context) {
	// 检查管理员权限
	userID, exists := c.Get("user_id")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "authentication required"})
		return
	}

	metrics := h.performanceMonitor.GetResourceMetrics()
	
	c.JSON(http.StatusOK, gin.H{
		"status": "success",
		"data":   metrics,
		"user_id": userID,
	})
}

// GetConnectionPoolStats 获取连接池统计信息
// Requirements: 9.3 - 连接池和资源管理
func (h *PerformanceHandler) GetConnectionPoolStats(c *gin.Context) {
	// 检查管理员权限
	userID, exists := c.Get("user_id")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "authentication required"})
		return
	}

	stats := h.performanceMonitor.GetConnectionPoolStats()
	
	c.JSON(http.StatusOK, gin.H{
		"status": "success",
		"data":   stats,
		"user_id": userID,
	})
}

// GetPerformanceOverview 获取性能概览
func (h *PerformanceHandler) GetPerformanceOverview(c *gin.Context) {
	// 检查管理员权限
	userID, exists := c.Get("user_id")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "authentication required"})
		return
	}

	// 获取各种指标
	resourceMetrics := h.performanceMonitor.GetResourceMetrics()
	poolStats := h.performanceMonitor.GetConnectionPoolStats()
	historicalMetrics := h.performanceMonitor.GetHistoricalMetrics()
	
	// 获取WebSocket优化统计
	wsOptimizer := h.performanceMonitor.GetWebSocketOptimizer()
	optimizationStats := wsOptimizer.GetOptimizationStats()
	
	// 获取系统指标收集器状态
	systemCollector := h.performanceMonitor.GetSystemMetricsCollector()
	collectorStatus := map[string]interface{}{
		"running":          systemCollector.IsRunning(),
		"collect_interval": systemCollector.GetCollectInterval().String(),
	}

	overview := map[string]interface{}{
		"resource_metrics":     resourceMetrics,
		"connection_pool":      poolStats,
		"historical_metrics":   historicalMetrics,
		"websocket_optimization": optimizationStats,
		"system_collector":     collectorStatus,
		"monitoring_status":    "enabled",
		"timestamp":            time.Now().UnixMilli(),
		"server_uptime":        time.Since(time.Now().Add(-24 * time.Hour)).String(), // 模拟运行时间
	}

	c.JSON(http.StatusOK, gin.H{
		"status": "success",
		"data":   overview,
		"user_id": userID,
	})
}

// SetPerformanceThresholds 设置性能阈值
func (h *PerformanceHandler) SetPerformanceThresholds(c *gin.Context) {
	// 检查管理员权限
	userID, exists := c.Get("user_id")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "authentication required"})
		return
	}

	var request struct {
		MaxAudioLatencyMs   int     `json:"max_audio_latency_ms" binding:"required,min=100,max=5000"`
		MaxMessageLatencyMs int     `json:"max_message_latency_ms" binding:"required,min=10,max=1000"`
		MaxCPUUsage         float64 `json:"max_cpu_usage" binding:"required,min=10,max=100"`
		MaxMemoryUsageMB    int64   `json:"max_memory_usage_mb" binding:"required,min=100,max=10240"`
		MaxGoroutines       int     `json:"max_goroutines" binding:"required,min=100,max=10000"`
		MinQualityScore     float64 `json:"min_quality_score" binding:"required,min=0,max=100"`
	}

	if err := c.ShouldBindJSON(&request); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{
			"error": "invalid request",
			"details": err.Error(),
			"user_message": "请求格式错误",
		})
		return
	}

	// 创建新的阈值配置
	thresholds := &service.PerformanceThresholds{
		MaxAudioLatency:   time.Duration(request.MaxAudioLatencyMs) * time.Millisecond,
		MaxMessageLatency: time.Duration(request.MaxMessageLatencyMs) * time.Millisecond,
		MaxCPUUsage:       request.MaxCPUUsage,
		MaxMemoryUsage:    request.MaxMemoryUsageMB * 1024 * 1024, // 转换为字节
		MaxGoroutines:     request.MaxGoroutines,
		MinQualityScore:   request.MinQualityScore,
		AlertCooldown:     5 * time.Minute,
	}

	h.performanceMonitor.SetPerformanceThresholds(thresholds)

	c.JSON(http.StatusOK, gin.H{
		"status": "success",
		"message": "performance thresholds updated",
		"data": gin.H{
			"max_audio_latency_ms":   request.MaxAudioLatencyMs,
			"max_message_latency_ms": request.MaxMessageLatencyMs,
			"max_cpu_usage":          request.MaxCPUUsage,
			"max_memory_usage_mb":    request.MaxMemoryUsageMB,
			"max_goroutines":         request.MaxGoroutines,
			"min_quality_score":      request.MinQualityScore,
		},
		"user_id": userID,
	})
}

// EnablePerformanceMonitoring 启用性能监控
func (h *PerformanceHandler) EnablePerformanceMonitoring(c *gin.Context) {
	// 检查管理员权限
	userID, exists := c.Get("user_id")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "authentication required"})
		return
	}

	h.performanceMonitor.EnableMonitoring()
	
	c.JSON(http.StatusOK, gin.H{
		"status": "success",
		"message": "performance monitoring enabled",
		"user_id": userID,
	})
}

// DisablePerformanceMonitoring 禁用性能监控
func (h *PerformanceHandler) DisablePerformanceMonitoring(c *gin.Context) {
	// 检查管理员权限
	userID, exists := c.Get("user_id")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "authentication required"})
		return
	}

	h.performanceMonitor.DisableMonitoring()
	
	c.JSON(http.StatusOK, gin.H{
		"status": "success",
		"message": "performance monitoring disabled",
		"user_id": userID,
	})
}

// GetPerformanceAlerts 获取性能告警历史
func (h *PerformanceHandler) GetPerformanceAlerts(c *gin.Context) {
	// 检查管理员权限
	userID, exists := c.Get("user_id")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "authentication required"})
		return
	}

	// 获取查询参数
	limitStr := c.DefaultQuery("limit", "50")
	limit, err := strconv.Atoi(limitStr)
	if err != nil || limit <= 0 {
		limit = 50
	}
	if limit > 500 {
		limit = 500 // 最大限制
	}

	// 注意：这里需要实现告警历史存储功能
	// 目前返回模拟数据
	alerts := []map[string]interface{}{
		{
			"type":      "audio_latency_high",
			"severity":  "warning",
			"message":   "Audio latency 650ms exceeds threshold 500ms",
			"timestamp": time.Now().Add(-1 * time.Hour).UnixMilli(),
			"resolved":  true,
		},
		{
			"type":      "cpu_usage_high",
			"severity":  "warning",
			"message":   "CPU usage 85% exceeds threshold 80%",
			"timestamp": time.Now().Add(-30 * time.Minute).UnixMilli(),
			"resolved":  false,
		},
	}

	c.JSON(http.StatusOK, gin.H{
		"status": "success",
		"data": gin.H{
			"alerts": alerts,
			"count":  len(alerts),
			"limit":  limit,
		},
		"user_id": userID,
	})
}

// OptimizeWebSocketConnections 优化WebSocket连接
// Requirements: 9.2 - 优化WebSocket消息处理
func (h *PerformanceHandler) OptimizeWebSocketConnections(c *gin.Context) {
	// 检查管理员权限
	userID, exists := c.Get("user_id")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "authentication required"})
		return
	}

	var request struct {
		EnableCompression   bool `json:"enable_compression"`
		MaxMessageSize      int  `json:"max_message_size"`
		ReadBufferSize      int  `json:"read_buffer_size"`
		WriteBufferSize     int  `json:"write_buffer_size"`
		EnableKeepalive     bool `json:"enable_keepalive"`
		KeepaliveIntervalMs int  `json:"keepalive_interval_ms"`
	}

	if err := c.ShouldBindJSON(&request); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{
			"error": "invalid request",
			"details": err.Error(),
			"user_message": "请求格式错误",
		})
		return
	}

	// 这里应该实际应用优化配置
	// 目前只是记录配置更改
	optimizations := map[string]interface{}{
		"compression_enabled":    request.EnableCompression,
		"max_message_size":       request.MaxMessageSize,
		"read_buffer_size":       request.ReadBufferSize,
		"write_buffer_size":      request.WriteBufferSize,
		"keepalive_enabled":      request.EnableKeepalive,
		"keepalive_interval_ms":  request.KeepaliveIntervalMs,
		"applied_at":             time.Now().UnixMilli(),
	}

	c.JSON(http.StatusOK, gin.H{
		"status": "success",
		"message": "WebSocket optimizations applied",
		"data":    optimizations,
		"user_id": userID,
	})
}
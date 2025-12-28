package service

import (
	"context"
	"fmt"
	"log"
	"sync"
	"time"
)

// PerformanceMonitor 性能监控和优化服务
type PerformanceMonitor struct {
	mu                    sync.RWMutex
	audioLatencyMetrics   map[string]*AudioLatencyMetric   // 音频延迟监控
	websocketMetrics      map[string]*WebSocketMetric      // WebSocket性能指标
	connectionPool        *ConnectionPool                  // 连接池管理
	resourceMetrics       *ResourceMetrics                 // 资源使用指标
	performanceThresholds *PerformanceThresholds           // 性能阈值配置
	alertCallbacks        map[string]func(AlertEvent)      // 性能告警回调
	monitoringEnabled     bool                             // 监控开关
	systemMetricsCollector *SystemMetricsCollector         // 系统指标收集器
	websocketOptimizer    *WebSocketOptimizer              // WebSocket优化器
	ctx                   context.Context
	cancel                context.CancelFunc
}

// AudioLatencyMetric 音频延迟指标
type AudioLatencyMetric struct {
	SessionID           string        `json:"session_id"`
	UserID              string        `json:"user_id"`
	ProcessingLatency   time.Duration `json:"processing_latency"`   // 音频处理延迟
	TransmissionLatency time.Duration `json:"transmission_latency"` // 传输延迟
	TotalLatency        time.Duration `json:"total_latency"`        // 总延迟
	AvgLatency          time.Duration `json:"avg_latency"`          // 平均延迟
	MaxLatency          time.Duration `json:"max_latency"`          // 最大延迟
	MinLatency          time.Duration `json:"min_latency"`          // 最小延迟
	SampleCount         int           `json:"sample_count"`         // 样本数量
	LastMeasurement     time.Time     `json:"last_measurement"`     // 最后测量时间
	QualityScore        float64       `json:"quality_score"`        // 质量评分 (0-100)
}

// WebSocketMetric WebSocket性能指标
type WebSocketMetric struct {
	SessionID           string        `json:"session_id"`
	MessagesSent        int64         `json:"messages_sent"`
	MessagesReceived    int64         `json:"messages_received"`
	BytesSent           int64         `json:"bytes_sent"`
	BytesReceived       int64         `json:"bytes_received"`
	MessageLatency      time.Duration `json:"message_latency"`
	AvgMessageLatency   time.Duration `json:"avg_message_latency"`
	MaxMessageLatency   time.Duration `json:"max_message_latency"`
	MessageThroughput   float64       `json:"message_throughput"`   // 消息/秒
	ByteThroughput      float64       `json:"byte_throughput"`      // 字节/秒
	ErrorCount          int           `json:"error_count"`
	ReconnectCount      int           `json:"reconnect_count"`
	LastActivity        time.Time     `json:"last_activity"`
	ConnectionDuration  time.Duration `json:"connection_duration"`
}

// ConnectionPool 连接池管理
type ConnectionPool struct {
	mu              sync.RWMutex
	activeConns     map[string]*PooledConnection // 活跃连接
	idleConns       []*PooledConnection          // 空闲连接
	maxConnections  int                          // 最大连接数
	maxIdleConns    int                          // 最大空闲连接数
	connTimeout     time.Duration                // 连接超时
	idleTimeout     time.Duration                // 空闲超时
	cleanupInterval time.Duration                // 清理间隔
	totalCreated    int64                        // 总创建连接数
	totalReused     int64                        // 总重用连接数
	totalClosed     int64                        // 总关闭连接数
}

// PooledConnection 池化连接
type PooledConnection struct {
	ID          string                 `json:"id"`
	SessionID   string                 `json:"session_id"`
	UserID      string                 `json:"user_id"`
	CreatedAt   time.Time              `json:"created_at"`
	LastUsed    time.Time              `json:"last_used"`
	UseCount    int                    `json:"use_count"`
	IsActive    bool                   `json:"is_active"`
	Metadata    map[string]interface{} `json:"metadata"`
}

// ResourceMetrics 资源使用指标
type ResourceMetrics struct {
	CPUUsage        float64   `json:"cpu_usage"`         // CPU使用率 (%)
	MemoryUsage     int64     `json:"memory_usage"`      // 内存使用量 (bytes)
	MemoryPercent   float64   `json:"memory_percent"`    // 内存使用率 (%)
	GoroutineCount  int       `json:"goroutine_count"`   // Goroutine数量
	HeapSize        int64     `json:"heap_size"`         // 堆大小
	GCPauseTime     time.Duration `json:"gc_pause_time"` // GC暂停时间
	NetworkInBytes  int64     `json:"network_in_bytes"`  // 网络入流量
	NetworkOutBytes int64     `json:"network_out_bytes"` // 网络出流量
	LastUpdated     time.Time `json:"last_updated"`
}

// PerformanceThresholds 性能阈值配置
type PerformanceThresholds struct {
	MaxAudioLatency     time.Duration `json:"max_audio_latency"`     // 最大音频延迟 (Requirements: 9.1)
	MaxMessageLatency   time.Duration `json:"max_message_latency"`   // 最大消息延迟
	MaxCPUUsage         float64       `json:"max_cpu_usage"`         // 最大CPU使用率
	MaxMemoryUsage      int64         `json:"max_memory_usage"`      // 最大内存使用量
	MaxGoroutines       int           `json:"max_goroutines"`        // 最大Goroutine数量
	MinQualityScore     float64       `json:"min_quality_score"`     // 最小质量评分
	AlertCooldown       time.Duration `json:"alert_cooldown"`        // 告警冷却时间
}

// AlertEvent 性能告警事件
type AlertEvent struct {
	Type        string                 `json:"type"`
	Severity    string                 `json:"severity"` // "warning", "critical"
	Message     string                 `json:"message"`
	Metric      string                 `json:"metric"`
	Value       interface{}            `json:"value"`
	Threshold   interface{}            `json:"threshold"`
	SessionID   string                 `json:"session_id,omitempty"`
	UserID      string                 `json:"user_id,omitempty"`
	Timestamp   time.Time              `json:"timestamp"`
	Metadata    map[string]interface{} `json:"metadata,omitempty"`
}

// NewPerformanceMonitor 创建新的性能监控服务
func NewPerformanceMonitor() *PerformanceMonitor {
	ctx, cancel := context.WithCancel(context.Background())
	
	pm := &PerformanceMonitor{
		audioLatencyMetrics: make(map[string]*AudioLatencyMetric),
		websocketMetrics:    make(map[string]*WebSocketMetric),
		connectionPool:      NewConnectionPool(),
		resourceMetrics:     &ResourceMetrics{},
		performanceThresholds: &PerformanceThresholds{
			MaxAudioLatency:   500 * time.Millisecond, // Requirements: 9.1 - 音频延迟小于500ms
			MaxMessageLatency: 100 * time.Millisecond,
			MaxCPUUsage:       80.0,
			MaxMemoryUsage:    1024 * 1024 * 1024, // 1GB
			MaxGoroutines:     1000,
			MinQualityScore:   70.0,
			AlertCooldown:     5 * time.Minute,
		},
		alertCallbacks:    make(map[string]func(AlertEvent)),
		monitoringEnabled: true,
		ctx:               ctx,
		cancel:            cancel,
	}

	// 初始化系统指标收集器
	pm.systemMetricsCollector = NewSystemMetricsCollector(pm)
	
	// 初始化WebSocket优化器
	pm.websocketOptimizer = NewWebSocketOptimizer(pm)

	// 暂时禁用性能监控来诊断WebSocket问题
	// go pm.startPerformanceMonitoring()
	
	// 暂时禁用系统指标收集
	// pm.systemMetricsCollector.Start()
	
	return pm
}

// NewConnectionPool 创建新的连接池
func NewConnectionPool() *ConnectionPool {
	return &ConnectionPool{
		activeConns:     make(map[string]*PooledConnection),
		idleConns:       make([]*PooledConnection, 0),
		maxConnections:  100,
		maxIdleConns:    20,
		connTimeout:     30 * time.Second,
		idleTimeout:     5 * time.Minute,
		cleanupInterval: 1 * time.Minute,
		totalCreated:    0,
		totalReused:     0,
		totalClosed:     0,
	}
}

// StartAudioLatencyMonitoring 开始音频延迟监控
// Requirements: 9.1 - 实现音频延迟监控
func (pm *PerformanceMonitor) StartAudioLatencyMonitoring(sessionID, userID string) {
	if !pm.monitoringEnabled {
		return
	}

	pm.mu.Lock()
	defer pm.mu.Unlock()

	metric := &AudioLatencyMetric{
		SessionID:       sessionID,
		UserID:          userID,
		MinLatency:      time.Hour, // 初始化为很大的值
		LastMeasurement: time.Now(),
		QualityScore:    100.0, // 初始质量评分
	}

	pm.audioLatencyMetrics[sessionID] = metric
	log.Printf("Started audio latency monitoring for session: %s", sessionID)
}

// MeasureAudioLatency 测量音频延迟
func (pm *PerformanceMonitor) MeasureAudioLatency(sessionID string, processingStart, transmissionStart time.Time) {
	if !pm.monitoringEnabled {
		return
	}

	pm.mu.Lock()
	defer pm.mu.Unlock()

	metric, exists := pm.audioLatencyMetrics[sessionID]
	if !exists {
		return
	}

	now := time.Now()
	processingLatency := transmissionStart.Sub(processingStart)
	transmissionLatency := now.Sub(transmissionStart)
	totalLatency := now.Sub(processingStart)

	// 更新指标
	metric.ProcessingLatency = processingLatency
	metric.TransmissionLatency = transmissionLatency
	metric.TotalLatency = totalLatency
	metric.SampleCount++
	metric.LastMeasurement = now

	// 计算平均延迟
	if metric.SampleCount == 1 {
		metric.AvgLatency = totalLatency
	} else {
		metric.AvgLatency = time.Duration(
			(int64(metric.AvgLatency)*int64(metric.SampleCount-1) + int64(totalLatency)) / int64(metric.SampleCount),
		)
	}

	// 更新最大/最小延迟
	if totalLatency > metric.MaxLatency {
		metric.MaxLatency = totalLatency
	}
	if totalLatency < metric.MinLatency {
		metric.MinLatency = totalLatency
	}

	// 计算质量评分 (基于延迟)
	metric.QualityScore = pm.calculateAudioQualityScore(totalLatency)

	// 检查性能阈值
	if totalLatency > pm.performanceThresholds.MaxAudioLatency {
		pm.triggerAlert(AlertEvent{
			Type:      "audio_latency_high",
			Severity:  "warning",
			Message:   fmt.Sprintf("Audio latency %v exceeds threshold %v", totalLatency, pm.performanceThresholds.MaxAudioLatency),
			Metric:    "audio_latency",
			Value:     totalLatency,
			Threshold: pm.performanceThresholds.MaxAudioLatency,
			SessionID: sessionID,
			UserID:    metric.UserID,
			Timestamp: now,
		})
	}

	log.Printf("Audio latency measured for session %s: processing=%v, transmission=%v, total=%v, quality=%.1f", 
		sessionID, processingLatency, transmissionLatency, totalLatency, metric.QualityScore)
}

// calculateAudioQualityScore 计算音频质量评分
func (pm *PerformanceMonitor) calculateAudioQualityScore(latency time.Duration) float64 {
	// 基于延迟计算质量评分 (0-100)
	latencyMs := float64(latency.Milliseconds())
	
	if latencyMs <= 100 {
		return 100.0 // 优秀
	} else if latencyMs <= 200 {
		return 90.0 - (latencyMs-100)*0.2 // 90-70
	} else if latencyMs <= 500 {
		return 70.0 - (latencyMs-200)*0.1 // 70-40
	} else {
		return 40.0 - (latencyMs-500)*0.05 // 40以下
	}
}

// StartWebSocketMonitoring 开始WebSocket性能监控
// Requirements: 9.2 - 优化WebSocket消息处理
func (pm *PerformanceMonitor) StartWebSocketMonitoring(sessionID string) {
	if !pm.monitoringEnabled {
		return
	}

	pm.mu.Lock()
	defer pm.mu.Unlock()

	metric := &WebSocketMetric{
		SessionID:    sessionID,
		LastActivity: time.Now(),
	}

	pm.websocketMetrics[sessionID] = metric
	log.Printf("Started WebSocket monitoring for session: %s", sessionID)
}

// RecordWebSocketMessage 记录WebSocket消息
func (pm *PerformanceMonitor) RecordWebSocketMessage(sessionID string, messageType string, messageSize int, latency time.Duration, isError bool) {
	if !pm.monitoringEnabled {
		return
	}

	pm.mu.Lock()
	defer pm.mu.Unlock()

	metric, exists := pm.websocketMetrics[sessionID]
	if !exists {
		return
	}

	now := time.Now()
	
	// 更新消息统计
	if messageType == "sent" {
		metric.MessagesSent++
		metric.BytesSent += int64(messageSize)
	} else {
		metric.MessagesReceived++
		metric.BytesReceived += int64(messageSize)
	}

	// 更新延迟统计
	if latency > 0 {
		metric.MessageLatency = latency
		totalMessages := metric.MessagesSent + metric.MessagesReceived
		if totalMessages == 1 {
			metric.AvgMessageLatency = latency
		} else {
			metric.AvgMessageLatency = time.Duration(
				(int64(metric.AvgMessageLatency)*int64(totalMessages-1) + int64(latency)) / int64(totalMessages),
			)
		}
		
		if latency > metric.MaxMessageLatency {
			metric.MaxMessageLatency = latency
		}
	}

	// 更新错误统计
	if isError {
		metric.ErrorCount++
	}

	// 计算吞吐量
	duration := now.Sub(metric.LastActivity)
	if duration > 0 {
		metric.MessageThroughput = float64(metric.MessagesSent+metric.MessagesReceived) / duration.Seconds()
		metric.ByteThroughput = float64(metric.BytesSent+metric.BytesReceived) / duration.Seconds()
	}

	metric.LastActivity = now

	// 检查性能阈值
	if latency > pm.performanceThresholds.MaxMessageLatency {
		pm.triggerAlert(AlertEvent{
			Type:      "message_latency_high",
			Severity:  "warning",
			Message:   fmt.Sprintf("Message latency %v exceeds threshold %v", latency, pm.performanceThresholds.MaxMessageLatency),
			Metric:    "message_latency",
			Value:     latency,
			Threshold: pm.performanceThresholds.MaxMessageLatency,
			SessionID: sessionID,
			Timestamp: now,
		})
	}
}

// GetConnection 从连接池获取连接
// Requirements: 9.3 - 实现连接池和资源管理
func (pm *PerformanceMonitor) GetConnection(sessionID, userID string) *PooledConnection {
	pm.connectionPool.mu.Lock()
	defer pm.connectionPool.mu.Unlock()

	// 检查是否有现有连接
	if conn, exists := pm.connectionPool.activeConns[sessionID]; exists {
		conn.LastUsed = time.Now()
		conn.UseCount++
		pm.connectionPool.totalReused++
		return conn
	}

	// 尝试从空闲连接池获取
	if len(pm.connectionPool.idleConns) > 0 {
		conn := pm.connectionPool.idleConns[0]
		pm.connectionPool.idleConns = pm.connectionPool.idleConns[1:]
		
		// 重新配置连接
		conn.SessionID = sessionID
		conn.UserID = userID
		conn.LastUsed = time.Now()
		conn.UseCount++
		conn.IsActive = true
		
		pm.connectionPool.activeConns[sessionID] = conn
		pm.connectionPool.totalReused++
		
		log.Printf("Reused connection from pool for session: %s", sessionID)
		return conn
	}

	// 检查连接数限制
	if len(pm.connectionPool.activeConns) >= pm.connectionPool.maxConnections {
		log.Printf("Connection pool limit reached: %d", pm.connectionPool.maxConnections)
		return nil
	}

	// 创建新连接
	conn := &PooledConnection{
		ID:        fmt.Sprintf("conn_%d", time.Now().UnixNano()),
		SessionID: sessionID,
		UserID:    userID,
		CreatedAt: time.Now(),
		LastUsed:  time.Now(),
		UseCount:  1,
		IsActive:  true,
		Metadata:  make(map[string]interface{}),
	}

	pm.connectionPool.activeConns[sessionID] = conn
	pm.connectionPool.totalCreated++
	
	log.Printf("Created new connection for session: %s", sessionID)
	return conn
}

// ReleaseConnection 释放连接到池中
func (pm *PerformanceMonitor) ReleaseConnection(sessionID string) {
	pm.connectionPool.mu.Lock()
	defer pm.connectionPool.mu.Unlock()

	conn, exists := pm.connectionPool.activeConns[sessionID]
	if !exists {
		return
	}

	delete(pm.connectionPool.activeConns, sessionID)
	
	// 如果空闲池未满，将连接放入空闲池
	if len(pm.connectionPool.idleConns) < pm.connectionPool.maxIdleConns {
		conn.IsActive = false
		conn.SessionID = ""
		conn.UserID = ""
		pm.connectionPool.idleConns = append(pm.connectionPool.idleConns, conn)
		log.Printf("Connection returned to idle pool: %s", conn.ID)
	} else {
		// 否则关闭连接
		pm.connectionPool.totalClosed++
		log.Printf("Connection closed (idle pool full): %s", conn.ID)
	}
}

// UpdateResourceMetrics 更新资源使用指标
// Requirements: 9.4 - 添加性能指标收集
func (pm *PerformanceMonitor) UpdateResourceMetrics(cpuUsage float64, memoryUsage int64, memoryPercent float64, goroutineCount int, heapSize int64, gcPauseTime time.Duration) {
	if !pm.monitoringEnabled {
		return
	}

	pm.mu.Lock()
	defer pm.mu.Unlock()

	pm.resourceMetrics.CPUUsage = cpuUsage
	pm.resourceMetrics.MemoryUsage = memoryUsage
	pm.resourceMetrics.MemoryPercent = memoryPercent
	pm.resourceMetrics.GoroutineCount = goroutineCount
	pm.resourceMetrics.HeapSize = heapSize
	pm.resourceMetrics.GCPauseTime = gcPauseTime
	pm.resourceMetrics.LastUpdated = time.Now()

	// 检查资源使用阈值
	if cpuUsage > pm.performanceThresholds.MaxCPUUsage {
		pm.triggerAlert(AlertEvent{
			Type:      "cpu_usage_high",
			Severity:  "warning",
			Message:   fmt.Sprintf("CPU usage %.1f%% exceeds threshold %.1f%%", cpuUsage, pm.performanceThresholds.MaxCPUUsage),
			Metric:    "cpu_usage",
			Value:     cpuUsage,
			Threshold: pm.performanceThresholds.MaxCPUUsage,
			Timestamp: time.Now(),
		})
	}

	if memoryUsage > pm.performanceThresholds.MaxMemoryUsage {
		pm.triggerAlert(AlertEvent{
			Type:      "memory_usage_high",
			Severity:  "critical",
			Message:   fmt.Sprintf("Memory usage %d bytes exceeds threshold %d bytes", memoryUsage, pm.performanceThresholds.MaxMemoryUsage),
			Metric:    "memory_usage",
			Value:     memoryUsage,
			Threshold: pm.performanceThresholds.MaxMemoryUsage,
			Timestamp: time.Now(),
		})
	}

	if goroutineCount > pm.performanceThresholds.MaxGoroutines {
		pm.triggerAlert(AlertEvent{
			Type:      "goroutine_count_high",
			Severity:  "warning",
			Message:   fmt.Sprintf("Goroutine count %d exceeds threshold %d", goroutineCount, pm.performanceThresholds.MaxGoroutines),
			Metric:    "goroutine_count",
			Value:     goroutineCount,
			Threshold: pm.performanceThresholds.MaxGoroutines,
			Timestamp: time.Now(),
		})
	}
}

// GetAudioLatencyMetrics 获取音频延迟指标
func (pm *PerformanceMonitor) GetAudioLatencyMetrics(sessionID string) *AudioLatencyMetric {
	pm.mu.RLock()
	defer pm.mu.RUnlock()

	if metric, exists := pm.audioLatencyMetrics[sessionID]; exists {
		// 返回副本
		metricCopy := *metric
		return &metricCopy
	}
	return nil
}

// GetWebSocketMetrics 获取WebSocket指标
func (pm *PerformanceMonitor) GetWebSocketMetrics(sessionID string) *WebSocketMetric {
	pm.mu.RLock()
	defer pm.mu.RUnlock()

	if metric, exists := pm.websocketMetrics[sessionID]; exists {
		// 返回副本
		metricCopy := *metric
		return &metricCopy
	}
	return nil
}

// GetResourceMetrics 获取资源使用指标
func (pm *PerformanceMonitor) GetResourceMetrics() *ResourceMetrics {
	pm.mu.RLock()
	defer pm.mu.RUnlock()

	// 返回副本
	metricsCopy := *pm.resourceMetrics
	return &metricsCopy
}

// GetConnectionPoolStats 获取连接池统计
func (pm *PerformanceMonitor) GetConnectionPoolStats() map[string]interface{} {
	pm.connectionPool.mu.RLock()
	defer pm.connectionPool.mu.RUnlock()

	return map[string]interface{}{
		"active_connections":  len(pm.connectionPool.activeConns),
		"idle_connections":    len(pm.connectionPool.idleConns),
		"max_connections":     pm.connectionPool.maxConnections,
		"max_idle_connections": pm.connectionPool.maxIdleConns,
		"total_created":       pm.connectionPool.totalCreated,
		"total_reused":        pm.connectionPool.totalReused,
		"total_closed":        pm.connectionPool.totalClosed,
		"connection_timeout":  pm.connectionPool.connTimeout.String(),
		"idle_timeout":        pm.connectionPool.idleTimeout.String(),
	}
}

// RegisterAlertCallback 注册性能告警回调
func (pm *PerformanceMonitor) RegisterAlertCallback(alertType string, callback func(AlertEvent)) {
	pm.mu.Lock()
	defer pm.mu.Unlock()
	pm.alertCallbacks[alertType] = callback
}

// triggerAlert 触发性能告警
func (pm *PerformanceMonitor) triggerAlert(event AlertEvent) {
	log.Printf("Performance Alert [%s]: %s", event.Severity, event.Message)
	
	// 触发回调
	pm.mu.RLock()
	callback, exists := pm.alertCallbacks[event.Type]
	pm.mu.RUnlock()
	
	if exists && callback != nil {
		go callback(event) // 异步执行回调
	}
}

// startPerformanceMonitoring 启动性能监控协程
func (pm *PerformanceMonitor) startPerformanceMonitoring() {
	ticker := time.NewTicker(30 * time.Second) // 每30秒收集一次指标
	defer ticker.Stop()

	for {
		select {
		case <-pm.ctx.Done():
			return
		case <-ticker.C:
			pm.collectSystemMetrics()
			pm.cleanupExpiredMetrics()
			pm.cleanupConnectionPool()
		}
	}
}

// collectSystemMetrics 收集系统指标
func (pm *PerformanceMonitor) collectSystemMetrics() {
	// 使用系统指标收集器获取实际数据
	if pm.systemMetricsCollector != nil {
		snapshot := pm.systemMetricsCollector.ForceCollect()
		
		// 直接使用 snapshot 数据更新资源指标
		pm.UpdateResourceMetrics(
			snapshot.CPUUsage,
			snapshot.MemoryUsage,
			snapshot.MemoryPercent,
			snapshot.GoroutineCount,
			snapshot.HeapSize,
			snapshot.GCPauseTime,
		)
		
		// 更新网络统计（基于WebSocket指标）
		totalBytesIn := int64(0)
		totalBytesOut := int64(0)
		
		pm.mu.RLock()
		for _, metric := range pm.websocketMetrics {
			totalBytesIn += metric.BytesReceived
			totalBytesOut += metric.BytesSent
		}
		pm.mu.RUnlock()
		
		pm.systemMetricsCollector.UpdateNetworkStats(totalBytesIn, totalBytesOut)
		
		log.Printf("System metrics collected: CPU=%.1f%%, Memory=%dMB, Goroutines=%d", 
			snapshot.CPUUsage, snapshot.MemoryUsage/(1024*1024), snapshot.GoroutineCount)
	}
}

// cleanupExpiredMetrics 清理过期指标
func (pm *PerformanceMonitor) cleanupExpiredMetrics() {
	pm.mu.Lock()
	defer pm.mu.Unlock()

	now := time.Now()
	expireTime := 1 * time.Hour

	// 清理音频延迟指标
	for sessionID, metric := range pm.audioLatencyMetrics {
		if now.Sub(metric.LastMeasurement) > expireTime {
			delete(pm.audioLatencyMetrics, sessionID)
		}
	}

	// 清理WebSocket指标
	for sessionID, metric := range pm.websocketMetrics {
		if now.Sub(metric.LastActivity) > expireTime {
			delete(pm.websocketMetrics, sessionID)
		}
	}
}

// cleanupConnectionPool 清理连接池
func (pm *PerformanceMonitor) cleanupConnectionPool() {
	pm.connectionPool.mu.Lock()
	defer pm.connectionPool.mu.Unlock()

	now := time.Now()
	
	// 清理空闲连接
	var validIdleConns []*PooledConnection
	for _, conn := range pm.connectionPool.idleConns {
		if now.Sub(conn.LastUsed) <= pm.connectionPool.idleTimeout {
			validIdleConns = append(validIdleConns, conn)
		} else {
			pm.connectionPool.totalClosed++
		}
	}
	pm.connectionPool.idleConns = validIdleConns

	log.Printf("Connection pool cleanup: active=%d, idle=%d", 
		len(pm.connectionPool.activeConns), len(pm.connectionPool.idleConns))
}

// EnableMonitoring 启用性能监控
func (pm *PerformanceMonitor) EnableMonitoring() {
	pm.mu.Lock()
	defer pm.mu.Unlock()
	pm.monitoringEnabled = true
	log.Println("Performance monitoring enabled")
}

// DisableMonitoring 禁用性能监控
func (pm *PerformanceMonitor) DisableMonitoring() {
	pm.mu.Lock()
	defer pm.mu.Unlock()
	pm.monitoringEnabled = false
	log.Println("Performance monitoring disabled")
}

// SetPerformanceThresholds 设置性能阈值
func (pm *PerformanceMonitor) SetPerformanceThresholds(thresholds *PerformanceThresholds) {
	pm.mu.Lock()
	defer pm.mu.Unlock()
	pm.performanceThresholds = thresholds
	log.Println("Performance thresholds updated")
}

// GetWebSocketOptimizer 获取WebSocket优化器
func (pm *PerformanceMonitor) GetWebSocketOptimizer() *WebSocketOptimizer {
	return pm.websocketOptimizer
}

// GetSystemMetricsCollector 获取系统指标收集器
func (pm *PerformanceMonitor) GetSystemMetricsCollector() *SystemMetricsCollector {
	return pm.systemMetricsCollector
}

// GetHistoricalMetrics 获取历史指标数据
func (pm *PerformanceMonitor) GetHistoricalMetrics() map[string]interface{} {
	if pm.systemMetricsCollector == nil {
		return nil
	}
	
	return pm.systemMetricsCollector.GetHistoricalData()
}

// Shutdown 关闭性能监控服务
func (pm *PerformanceMonitor) Shutdown() {
	if pm.systemMetricsCollector != nil {
		pm.systemMetricsCollector.Stop()
	}
	pm.cancel()
	log.Println("Performance monitor shutdown")
}
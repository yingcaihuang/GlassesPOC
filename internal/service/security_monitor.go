package service

import (
	"context"
	"fmt"
	"log"
	"sync"
	"time"
)

// SecurityMonitor 安全和监控服务
type SecurityMonitor struct {
	mu                    sync.RWMutex
	sessions              map[string]*VoiceSession    // 活跃会话管理
	connectionMetrics     map[string]*ConnectionMetric // 连接质量监控
	accessLogs            []AccessLog                  // 访问日志
	sessionTimeout        time.Duration                // 会话超时时间
	maxSessions           int                          // 最大并发会话数
	cleanupInterval       time.Duration                // 清理间隔
	logRetentionDays      int                          // 日志保留天数
	privacyMode           bool                         // 隐私保护模式
	monitoringEnabled     bool                         // 监控开关
	ctx                   context.Context
	cancel                context.CancelFunc
}

// VoiceSession 语音会话结构
type VoiceSession struct {
	ID            string                 `json:"id"`
	UserID        string                 `json:"user_id"`
	UserEmail     string                 `json:"user_email,omitempty"`
	Status        SessionStatus          `json:"status"`
	StartTime     time.Time              `json:"start_time"`
	LastActivity  time.Time              `json:"last_activity"`
	EndTime       *time.Time             `json:"end_time,omitempty"`
	AudioDuration int64                  `json:"audio_duration"` // milliseconds
	MessageCount  int                    `json:"message_count"`
	ErrorCount    int                    `json:"error_count"`
	ClientIP      string                 `json:"client_ip"`
	UserAgent     string                 `json:"user_agent"`
	Metadata      map[string]interface{} `json:"metadata,omitempty"`
}

// SessionStatus 会话状态枚举
type SessionStatus string

const (
	SessionStatusActive    SessionStatus = "active"
	SessionStatusPaused    SessionStatus = "paused"
	SessionStatusCompleted SessionStatus = "completed"
	SessionStatusTimeout   SessionStatus = "timeout"
	SessionStatusError     SessionStatus = "error"
)

// ConnectionMetric 连接质量指标
type ConnectionMetric struct {
	SessionID        string        `json:"session_id"`
	UserID           string        `json:"user_id"`
	ConnectedAt      time.Time     `json:"connected_at"`
	LastPingTime     time.Time     `json:"last_ping_time"`
	PingCount        int           `json:"ping_count"`
	LatencyMs        float64       `json:"latency_ms"`
	AvgLatencyMs     float64       `json:"avg_latency_ms"`
	MaxLatencyMs     float64       `json:"max_latency_ms"`
	MinLatencyMs     float64       `json:"min_latency_ms"`
	PacketLoss       float64       `json:"packet_loss"`
	BytesSent        int64         `json:"bytes_sent"`
	BytesReceived    int64         `json:"bytes_received"`
	AudioChunksCount int           `json:"audio_chunks_count"`
	ErrorCount       int           `json:"error_count"`
	Quality          string        `json:"quality"` // "excellent", "good", "fair", "poor"
	LastUpdated      time.Time     `json:"last_updated"`
}

// AccessLog 访问日志结构
type AccessLog struct {
	ID          string                 `json:"id"`
	Timestamp   time.Time              `json:"timestamp"`
	UserID      string                 `json:"user_id"`
	UserEmail   string                 `json:"user_email,omitempty"`
	SessionID   string                 `json:"session_id,omitempty"`
	Action      string                 `json:"action"`
	Resource    string                 `json:"resource"`
	Method      string                 `json:"method"`
	ClientIP    string                 `json:"client_ip"`
	UserAgent   string                 `json:"user_agent"`
	StatusCode  int                    `json:"status_code"`
	Duration    time.Duration          `json:"duration"`
	ErrorMsg    string                 `json:"error_msg,omitempty"`
	Metadata    map[string]interface{} `json:"metadata,omitempty"`
}

// SessionTimeoutEvent 会话超时事件
type SessionTimeoutEvent struct {
	SessionID string
	UserID    string
	Duration  time.Duration
}

// NewSecurityMonitor 创建新的安全监控服务
func NewSecurityMonitor() *SecurityMonitor {
	ctx, cancel := context.WithCancel(context.Background())
	
	sm := &SecurityMonitor{
		sessions:          make(map[string]*VoiceSession),
		connectionMetrics: make(map[string]*ConnectionMetric),
		accessLogs:        make([]AccessLog, 0),
		sessionTimeout:    30 * time.Minute, // Requirement 10.4 - 会话超时机制
		maxSessions:       100,               // 最大并发会话数
		cleanupInterval:   5 * time.Minute,   // 清理间隔
		logRetentionDays:  30,                // 日志保留30天
		privacyMode:       true,              // Requirement 10.2 - 音频数据隐私保护
		monitoringEnabled: true,              // Requirement 9.5 - 连接质量监控
		ctx:               ctx,
		cancel:            cancel,
	}

	// 启动后台清理任务
	go sm.startCleanupRoutine()
	
	return sm
}

// StartSession 开始新会话
// Requirements: 10.1, 10.4, 10.5 - JWT认证、会话超时、访问日志
func (sm *SecurityMonitor) StartSession(userID, userEmail, clientIP, userAgent string) (*VoiceSession, error) {
	sm.mu.Lock()
	defer sm.mu.Unlock()

	// 检查并发会话数限制
	activeCount := 0
	for _, session := range sm.sessions {
		if session.Status == SessionStatusActive {
			activeCount++
		}
	}

	if activeCount >= sm.maxSessions {
		return nil, fmt.Errorf("maximum concurrent sessions reached: %d", sm.maxSessions)
	}

	// 创建新会话
	sessionID := fmt.Sprintf("session_%d_%s", time.Now().UnixNano(), userID[:8])
	session := &VoiceSession{
		ID:            sessionID,
		UserID:        userID,
		UserEmail:     userEmail,
		Status:        SessionStatusActive,
		StartTime:     time.Now(),
		LastActivity:  time.Now(),
		AudioDuration: 0,
		MessageCount:  0,
		ErrorCount:    0,
		ClientIP:      clientIP,
		UserAgent:     userAgent,
		Metadata:      make(map[string]interface{}),
	}

	sm.sessions[sessionID] = session

	// 记录访问日志 (Requirement 10.5)
	sm.logAccess(AccessLog{
		ID:         fmt.Sprintf("log_%d", time.Now().UnixNano()),
		Timestamp:  time.Now(),
		UserID:     userID,
		UserEmail:  userEmail,
		SessionID:  sessionID,
		Action:     "session_start",
		Resource:   "/api/v1/realtime/chat",
		Method:     "WebSocket",
		ClientIP:   clientIP,
		UserAgent:  userAgent,
		StatusCode: 200,
		Duration:   0,
	})

	log.Printf("New voice session started: %s for user %s", sessionID, userID)
	return session, nil
}

// UpdateSessionActivity 更新会话活动时间
func (sm *SecurityMonitor) UpdateSessionActivity(sessionID string) {
	sm.mu.Lock()
	defer sm.mu.Unlock()

	if session, exists := sm.sessions[sessionID]; exists {
		session.LastActivity = time.Now()
		session.MessageCount++
	}
}

// EndSession 结束会话
func (sm *SecurityMonitor) EndSession(sessionID string, reason string) {
	sm.mu.Lock()
	defer sm.mu.Unlock()

	session, exists := sm.sessions[sessionID]
	if !exists {
		return
	}

	now := time.Now()
	session.EndTime = &now
	
	switch reason {
	case "timeout":
		session.Status = SessionStatusTimeout
	case "error":
		session.Status = SessionStatusError
	default:
		session.Status = SessionStatusCompleted
	}

	// 记录会话结束日志
	duration := now.Sub(session.StartTime)
	sm.logAccess(AccessLog{
		ID:         fmt.Sprintf("log_%d", time.Now().UnixNano()),
		Timestamp:  now,
		UserID:     session.UserID,
		UserEmail:  session.UserEmail,
		SessionID:  sessionID,
		Action:     "session_end",
		Resource:   "/api/v1/realtime/chat",
		Method:     "WebSocket",
		ClientIP:   session.ClientIP,
		UserAgent:  session.UserAgent,
		StatusCode: 200,
		Duration:   duration,
		Metadata: map[string]interface{}{
			"reason":          reason,
			"message_count":   session.MessageCount,
			"audio_duration":  session.AudioDuration,
			"error_count":     session.ErrorCount,
		},
	})

	log.Printf("Voice session ended: %s (reason: %s, duration: %v)", sessionID, reason, duration)
}

// CheckSessionTimeout 检查会话超时
// Requirements: 10.4 - 会话超时机制
func (sm *SecurityMonitor) CheckSessionTimeout() []SessionTimeoutEvent {
	sm.mu.Lock()
	defer sm.mu.Unlock()

	var timeoutEvents []SessionTimeoutEvent
	now := time.Now()

	for sessionID, session := range sm.sessions {
		if session.Status == SessionStatusActive {
			timeSinceActivity := now.Sub(session.LastActivity)
			if timeSinceActivity > sm.sessionTimeout {
				// 会话超时
				session.Status = SessionStatusTimeout
				session.EndTime = &now

				timeoutEvent := SessionTimeoutEvent{
					SessionID: sessionID,
					UserID:    session.UserID,
					Duration:  now.Sub(session.StartTime),
				}
				timeoutEvents = append(timeoutEvents, timeoutEvent)

				log.Printf("Session timeout: %s (user: %s, inactive for: %v)", 
					sessionID, session.UserID, timeSinceActivity)
			}
		}
	}

	return timeoutEvents
}

// StartConnectionMonitoring 开始连接质量监控
// Requirements: 9.5 - 连接质量监控
func (sm *SecurityMonitor) StartConnectionMonitoring(sessionID, userID string) {
	if !sm.monitoringEnabled {
		return
	}

	sm.mu.Lock()
	defer sm.mu.Unlock()

	metric := &ConnectionMetric{
		SessionID:        sessionID,
		UserID:           userID,
		ConnectedAt:      time.Now(),
		LastPingTime:     time.Now(),
		PingCount:        0,
		LatencyMs:        0,
		AvgLatencyMs:     0,
		MaxLatencyMs:     0,
		MinLatencyMs:     999999,
		PacketLoss:       0,
		BytesSent:        0,
		BytesReceived:    0,
		AudioChunksCount: 0,
		ErrorCount:       0,
		Quality:          "unknown",
		LastUpdated:      time.Now(),
	}

	sm.connectionMetrics[sessionID] = metric
	log.Printf("Started connection monitoring for session: %s", sessionID)
}

// UpdateConnectionMetric 更新连接质量指标
func (sm *SecurityMonitor) UpdateConnectionMetric(sessionID string, latencyMs float64, bytesTransferred int64, isError bool) {
	if !sm.monitoringEnabled {
		return
	}

	sm.mu.Lock()
	defer sm.mu.Unlock()

	metric, exists := sm.connectionMetrics[sessionID]
	if !exists {
		return
	}

	// 更新延迟统计
	if latencyMs > 0 {
		metric.PingCount++
		metric.LatencyMs = latencyMs
		metric.AvgLatencyMs = (metric.AvgLatencyMs*float64(metric.PingCount-1) + latencyMs) / float64(metric.PingCount)
		
		if latencyMs > metric.MaxLatencyMs {
			metric.MaxLatencyMs = latencyMs
		}
		if latencyMs < metric.MinLatencyMs {
			metric.MinLatencyMs = latencyMs
		}
		
		metric.LastPingTime = time.Now()
	}

	// 更新传输统计
	if bytesTransferred > 0 {
		metric.BytesReceived += bytesTransferred
		metric.AudioChunksCount++
	}

	// 更新错误统计
	if isError {
		metric.ErrorCount++
	}

	// 计算连接质量
	metric.Quality = sm.calculateConnectionQuality(metric)
	metric.LastUpdated = time.Now()
}

// calculateConnectionQuality 计算连接质量
func (sm *SecurityMonitor) calculateConnectionQuality(metric *ConnectionMetric) string {
	// 基于延迟和错误率计算质量
	avgLatency := metric.AvgLatencyMs
	errorRate := float64(metric.ErrorCount) / float64(metric.PingCount+1)

	if avgLatency < 100 && errorRate < 0.01 {
		return "excellent"
	} else if avgLatency < 200 && errorRate < 0.05 {
		return "good"
	} else if avgLatency < 500 && errorRate < 0.1 {
		return "fair"
	} else {
		return "poor"
	}
}

// GetConnectionQuality 获取连接质量
func (sm *SecurityMonitor) GetConnectionQuality(sessionID string) *ConnectionMetric {
	sm.mu.RLock()
	defer sm.mu.RUnlock()

	if metric, exists := sm.connectionMetrics[sessionID]; exists {
		// 返回副本以保护原始数据
		metricCopy := *metric
		return &metricCopy
	}
	return nil
}

// LogAccess 记录访问日志
// Requirements: 10.5 - 访问日志记录
func (sm *SecurityMonitor) LogAccess(userID, userEmail, sessionID, action, resource, method, clientIP, userAgent string, statusCode int, duration time.Duration, errorMsg string) {
	accessLog := AccessLog{
		ID:         fmt.Sprintf("log_%d", time.Now().UnixNano()),
		Timestamp:  time.Now(),
		UserID:     userID,
		UserEmail:  userEmail,
		SessionID:  sessionID,
		Action:     action,
		Resource:   resource,
		Method:     method,
		ClientIP:   clientIP,
		UserAgent:  userAgent,
		StatusCode: statusCode,
		Duration:   duration,
		ErrorMsg:   errorMsg,
	}

	sm.logAccess(accessLog)
}

// logAccess 内部日志记录方法
func (sm *SecurityMonitor) logAccess(accessLog AccessLog) {
	sm.mu.Lock()
	defer sm.mu.Unlock()

	// 在隐私模式下，不记录敏感信息
	if sm.privacyMode {
		accessLog.UserEmail = "" // 不记录邮箱
		accessLog.ClientIP = sm.maskIP(accessLog.ClientIP) // 掩码IP
	}

	sm.accessLogs = append(sm.accessLogs, accessLog)

	// 记录到系统日志
	log.Printf("Access: %s %s %s [%d] %v - %s", 
		accessLog.Method, accessLog.Resource, accessLog.ClientIP, 
		accessLog.StatusCode, accessLog.Duration, accessLog.UserID)
}

// maskIP 掩码IP地址以保护隐私
func (sm *SecurityMonitor) maskIP(ip string) string {
	if len(ip) == 0 {
		return ""
	}
	// 简单的IP掩码，保留前两段
	// 例如: 192.168.1.100 -> 192.168.*.* 
	parts := []rune(ip)
	dotCount := 0
	for i, char := range parts {
		if char == '.' {
			dotCount++
			if dotCount >= 2 {
				for j := i + 1; j < len(parts); j++ {
					if parts[j] == '.' {
						parts[j] = '.'
					} else {
						parts[j] = '*'
					}
				}
				break
			}
		}
	}
	return string(parts)
}

// EnsureAudioDataPrivacy 确保音频数据隐私保护
// Requirements: 10.2 - 音频数据隐私保护
func (sm *SecurityMonitor) EnsureAudioDataPrivacy() bool {
	// 返回隐私保护状态，确保音频数据不被持久化存储
	return sm.privacyMode
}

// ValidateAudioDataHandling 验证音频数据处理合规性
func (sm *SecurityMonitor) ValidateAudioDataHandling(operation string) error {
	if !sm.privacyMode {
		return fmt.Errorf("privacy mode is disabled")
	}

	// 检查操作是否符合隐私保护要求
	forbiddenOperations := []string{"store_audio", "save_audio", "persist_audio", "log_audio_content"}
	for _, forbidden := range forbiddenOperations {
		if operation == forbidden {
			return fmt.Errorf("operation '%s' violates audio data privacy policy", operation)
		}
	}

	return nil
}

// GetActiveSessions 获取活跃会话列表
func (sm *SecurityMonitor) GetActiveSessions() []*VoiceSession {
	sm.mu.RLock()
	defer sm.mu.RUnlock()

	var activeSessions []*VoiceSession
	for _, session := range sm.sessions {
		if session.Status == SessionStatusActive {
			// 返回副本以保护原始数据
			sessionCopy := *session
			activeSessions = append(activeSessions, &sessionCopy)
		}
	}

	return activeSessions
}

// GetSessionStats 获取会话统计信息
func (sm *SecurityMonitor) GetSessionStats() map[string]interface{} {
	sm.mu.RLock()
	defer sm.mu.RUnlock()

	stats := make(map[string]interface{})
	
	totalSessions := len(sm.sessions)
	activeSessions := 0
	completedSessions := 0
	timeoutSessions := 0
	errorSessions := 0

	for _, session := range sm.sessions {
		switch session.Status {
		case SessionStatusActive:
			activeSessions++
		case SessionStatusCompleted:
			completedSessions++
		case SessionStatusTimeout:
			timeoutSessions++
		case SessionStatusError:
			errorSessions++
		}
	}

	stats["total_sessions"] = totalSessions
	stats["active_sessions"] = activeSessions
	stats["completed_sessions"] = completedSessions
	stats["timeout_sessions"] = timeoutSessions
	stats["error_sessions"] = errorSessions
	stats["max_sessions"] = sm.maxSessions
	stats["session_timeout_minutes"] = sm.sessionTimeout.Minutes()

	return stats
}

// GetAccessLogs 获取访问日志
func (sm *SecurityMonitor) GetAccessLogs(limit int) []AccessLog {
	sm.mu.RLock()
	defer sm.mu.RUnlock()

	if limit <= 0 || limit > len(sm.accessLogs) {
		limit = len(sm.accessLogs)
	}

	// 返回最新的日志
	start := len(sm.accessLogs) - limit
	if start < 0 {
		start = 0
	}

	logs := make([]AccessLog, limit)
	copy(logs, sm.accessLogs[start:])
	
	return logs
}

// startCleanupRoutine 启动清理例程
func (sm *SecurityMonitor) startCleanupRoutine() {
	ticker := time.NewTicker(sm.cleanupInterval)
	defer ticker.Stop()

	for {
		select {
		case <-sm.ctx.Done():
			return
		case <-ticker.C:
			sm.cleanup()
		}
	}
}

// cleanup 清理过期数据
func (sm *SecurityMonitor) cleanup() {
	sm.mu.Lock()
	defer sm.mu.Unlock()

	now := time.Now()
	
	// 清理过期会话
	for sessionID, session := range sm.sessions {
		if session.Status != SessionStatusActive && session.EndTime != nil {
			if now.Sub(*session.EndTime) > 24*time.Hour { // 保留24小时
				delete(sm.sessions, sessionID)
				delete(sm.connectionMetrics, sessionID)
			}
		}
	}

	// 清理过期日志
	retentionTime := time.Duration(sm.logRetentionDays) * 24 * time.Hour
	var validLogs []AccessLog
	for _, log := range sm.accessLogs {
		if now.Sub(log.Timestamp) <= retentionTime {
			validLogs = append(validLogs, log)
		}
	}
	sm.accessLogs = validLogs

	log.Printf("Cleanup completed: sessions=%d, logs=%d", len(sm.sessions), len(sm.accessLogs))
}

// SetSessionTimeout 设置会话超时时间
func (sm *SecurityMonitor) SetSessionTimeout(timeout time.Duration) {
	sm.mu.Lock()
	defer sm.mu.Unlock()
	sm.sessionTimeout = timeout
	log.Printf("Session timeout set to: %v", timeout)
}

// SetMaxSessions 设置最大并发会话数
func (sm *SecurityMonitor) SetMaxSessions(maxSessions int) {
	sm.mu.Lock()
	defer sm.mu.Unlock()
	sm.maxSessions = maxSessions
	log.Printf("Max sessions set to: %d", maxSessions)
}

// EnableMonitoring 启用监控
func (sm *SecurityMonitor) EnableMonitoring() {
	sm.mu.Lock()
	defer sm.mu.Unlock()
	sm.monitoringEnabled = true
	log.Println("Connection monitoring enabled")
}

// DisableMonitoring 禁用监控
func (sm *SecurityMonitor) DisableMonitoring() {
	sm.mu.Lock()
	defer sm.mu.Unlock()
	sm.monitoringEnabled = false
	log.Println("Connection monitoring disabled")
}

// EnablePrivacyMode 启用隐私模式
func (sm *SecurityMonitor) EnablePrivacyMode() {
	sm.mu.Lock()
	defer sm.mu.Unlock()
	sm.privacyMode = true
	log.Println("Privacy mode enabled")
}

// DisablePrivacyMode 禁用隐私模式
func (sm *SecurityMonitor) DisablePrivacyMode() {
	sm.mu.Lock()
	defer sm.mu.Unlock()
	sm.privacyMode = false
	log.Println("Privacy mode disabled")
}

// Shutdown 关闭监控服务
func (sm *SecurityMonitor) Shutdown() {
	sm.cancel()
	log.Println("Security monitor shutdown")
}
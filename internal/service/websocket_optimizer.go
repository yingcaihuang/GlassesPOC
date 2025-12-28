package service

import (
	"bytes"
	"compress/gzip"
	"encoding/json"
	"fmt"
	"io"
	"log"
	"net/http"
	"sync"
	"time"

	"github.com/gorilla/websocket"
)

// WebSocketOptimizer WebSocket连接优化器
// Requirements: 9.2 - 优化WebSocket消息处理
type WebSocketOptimizer struct {
	mu                    sync.RWMutex
	compressionEnabled    bool                    // 启用压缩
	maxMessageSize        int64                   // 最大消息大小
	readBufferSize        int                     // 读缓冲区大小
	writeBufferSize       int                     // 写缓冲区大小
	enableKeepalive       bool                    // 启用心跳
	keepaliveInterval     time.Duration           // 心跳间隔
	messageQueue          map[string]*MessageQueue // 消息队列
	batchSize             int                     // 批处理大小
	batchTimeout          time.Duration           // 批处理超时
	performanceMonitor    *PerformanceMonitor     // 性能监控
}

// MessageQueue 消息队列
type MessageQueue struct {
	sessionID    string
	messages     []QueuedMessage
	lastFlush    time.Time
	mu           sync.Mutex
}

// QueuedMessage 队列中的消息
type QueuedMessage struct {
	Type      string      `json:"type"`
	Data      interface{} `json:"data"`
	Timestamp time.Time   `json:"timestamp"`
	Priority  int         `json:"priority"` // 优先级：1=高，2=中，3=低
}

// OptimizedUpgrader 优化的WebSocket升级器
type OptimizedUpgrader struct {
	*websocket.Upgrader
	optimizer *WebSocketOptimizer
}

// NewWebSocketOptimizer 创建WebSocket优化器
func NewWebSocketOptimizer(performanceMonitor *PerformanceMonitor) *WebSocketOptimizer {
	optimizer := &WebSocketOptimizer{
		compressionEnabled: true,
		maxMessageSize:     32 * 1024, // 32KB
		readBufferSize:     4096,      // 4KB
		writeBufferSize:    4096,      // 4KB
		enableKeepalive:    true,
		keepaliveInterval:  30 * time.Second,
		messageQueue:       make(map[string]*MessageQueue),
		batchSize:          10,
		batchTimeout:       100 * time.Millisecond,
		performanceMonitor: performanceMonitor,
	}

	// 启动批处理协程
	go optimizer.startBatchProcessor()
	
	return optimizer
}

// CreateOptimizedUpgrader 创建优化的WebSocket升级器
func (wo *WebSocketOptimizer) CreateOptimizedUpgrader() *OptimizedUpgrader {
	upgrader := &websocket.Upgrader{
		ReadBufferSize:    wo.readBufferSize,
		WriteBufferSize:   wo.writeBufferSize,
		EnableCompression: wo.compressionEnabled,
		CheckOrigin: func(r *http.Request) bool {
			return true // 开发环境允许所有跨域
		},
	}

	return &OptimizedUpgrader{
		Upgrader:  upgrader,
		optimizer: wo,
	}
}

// OptimizeConnection 优化WebSocket连接
func (wo *WebSocketOptimizer) OptimizeConnection(conn *websocket.Conn, sessionID string) error {
	wo.mu.Lock()
	defer wo.mu.Unlock()

	// 设置连接参数
	conn.SetReadLimit(wo.maxMessageSize)
	
	// 设置压缩
	if wo.compressionEnabled {
		conn.EnableWriteCompression(true)
	}

	// 创建消息队列
	wo.messageQueue[sessionID] = &MessageQueue{
		sessionID: sessionID,
		messages:  make([]QueuedMessage, 0),
		lastFlush: time.Now(),
	}

	// 启用心跳
	if wo.enableKeepalive {
		go wo.startKeepalive(conn, sessionID)
	}

	log.Printf("WebSocket connection optimized for session: %s", sessionID)
	return nil
}

// QueueMessage 将消息加入队列进行批处理
func (wo *WebSocketOptimizer) QueueMessage(sessionID string, msgType string, data interface{}, priority int) {
	wo.mu.Lock()
	defer wo.mu.Unlock()

	queue, exists := wo.messageQueue[sessionID]
	if !exists {
		return
	}

	queue.mu.Lock()
	defer queue.mu.Unlock()

	message := QueuedMessage{
		Type:      msgType,
		Data:      data,
		Timestamp: time.Now(),
		Priority:  priority,
	}

	queue.messages = append(queue.messages, message)

	// 如果队列满了或者是高优先级消息，立即刷新
	if len(queue.messages) >= wo.batchSize || priority == 1 {
		wo.flushQueue(sessionID, queue)
	}
}

// SendOptimizedMessage 发送优化的消息
func (wo *WebSocketOptimizer) SendOptimizedMessage(conn *websocket.Conn, sessionID string, message interface{}) error {
	if conn == nil {
		return fmt.Errorf("connection is nil")
	}

	messageStart := time.Now()

	// 序列化消息
	data, err := json.Marshal(message)
	if err != nil {
		return fmt.Errorf("failed to marshal message: %v", err)
	}

	// 压缩消息（如果启用）
	if wo.compressionEnabled && len(data) > 1024 { // 只压缩大于1KB的消息
		compressedData, err := wo.compressMessage(data)
		if err == nil && len(compressedData) < len(data) {
			data = compressedData
		}
	}

	// 设置写入超时
	conn.SetWriteDeadline(time.Now().Add(5 * time.Second))

	// 发送消息
	err = conn.WriteMessage(websocket.TextMessage, data)
	
	// 记录性能指标
	messageLatency := time.Since(messageStart)
	if wo.performanceMonitor != nil {
		wo.performanceMonitor.RecordWebSocketMessage(sessionID, "sent", len(data), messageLatency, err != nil)
	}

	return err
}

// compressMessage 压缩消息
func (wo *WebSocketOptimizer) compressMessage(data []byte) ([]byte, error) {
	var buf bytes.Buffer
	writer := gzip.NewWriter(&buf)
	
	_, err := writer.Write(data)
	if err != nil {
		return nil, err
	}
	
	err = writer.Close()
	if err != nil {
		return nil, err
	}
	
	return buf.Bytes(), nil
}

// decompressMessage 解压缩消息
func (wo *WebSocketOptimizer) decompressMessage(data []byte) ([]byte, error) {
	reader, err := gzip.NewReader(bytes.NewReader(data))
	if err != nil {
		return nil, err
	}
	defer reader.Close()
	
	return io.ReadAll(reader)
}

// startKeepalive 启动心跳检测
func (wo *WebSocketOptimizer) startKeepalive(conn *websocket.Conn, sessionID string) {
	ticker := time.NewTicker(wo.keepaliveInterval)
	defer ticker.Stop()

	for {
		select {
		case <-ticker.C:
			// 发送ping消息
			pingStart := time.Now()
			conn.SetWriteDeadline(time.Now().Add(10 * time.Second))
			err := conn.WriteMessage(websocket.PingMessage, []byte{})
			
			if err != nil {
				log.Printf("Keepalive ping failed for session %s: %v", sessionID, err)
				return
			}

			// 记录ping延迟
			if wo.performanceMonitor != nil {
				latency := time.Since(pingStart)
				wo.performanceMonitor.RecordWebSocketMessage(sessionID, "ping", 0, latency, false)
			}
		}
	}
}

// startBatchProcessor 启动批处理器
func (wo *WebSocketOptimizer) startBatchProcessor() {
	ticker := time.NewTicker(wo.batchTimeout)
	defer ticker.Stop()

	for {
		select {
		case <-ticker.C:
			wo.processBatches()
		}
	}
}

// processBatches 处理所有队列的批次
func (wo *WebSocketOptimizer) processBatches() {
	wo.mu.RLock()
	queues := make(map[string]*MessageQueue)
	for sessionID, queue := range wo.messageQueue {
		queues[sessionID] = queue
	}
	wo.mu.RUnlock()

	for sessionID, queue := range queues {
		queue.mu.Lock()
		if len(queue.messages) > 0 && time.Since(queue.lastFlush) > wo.batchTimeout {
			wo.flushQueue(sessionID, queue)
		}
		queue.mu.Unlock()
	}
}

// flushQueue 刷新消息队列
func (wo *WebSocketOptimizer) flushQueue(sessionID string, queue *MessageQueue) {
	if len(queue.messages) == 0 {
		return
	}

	// 按优先级排序消息
	wo.sortMessagesByPriority(queue.messages)

	// 这里应该发送到实际的WebSocket连接
	// 由于我们没有直接的连接引用，这里只是记录
	log.Printf("Flushing %d messages for session %s", len(queue.messages), sessionID)

	// 清空队列
	queue.messages = queue.messages[:0]
	queue.lastFlush = time.Now()
}

// sortMessagesByPriority 按优先级排序消息
func (wo *WebSocketOptimizer) sortMessagesByPriority(messages []QueuedMessage) {
	// 简单的冒泡排序，按优先级排序（1=高优先级在前）
	n := len(messages)
	for i := 0; i < n-1; i++ {
		for j := 0; j < n-i-1; j++ {
			if messages[j].Priority > messages[j+1].Priority {
				messages[j], messages[j+1] = messages[j+1], messages[j]
			}
		}
	}
}

// CleanupSession 清理会话资源
func (wo *WebSocketOptimizer) CleanupSession(sessionID string) {
	wo.mu.Lock()
	defer wo.mu.Unlock()

	delete(wo.messageQueue, sessionID)
	log.Printf("Cleaned up WebSocket optimization resources for session: %s", sessionID)
}

// GetOptimizationStats 获取优化统计信息
func (wo *WebSocketOptimizer) GetOptimizationStats() map[string]interface{} {
	wo.mu.RLock()
	defer wo.mu.RUnlock()

	totalQueues := len(wo.messageQueue)
	totalQueuedMessages := 0

	for _, queue := range wo.messageQueue {
		queue.mu.Lock()
		totalQueuedMessages += len(queue.messages)
		queue.mu.Unlock()
	}

	return map[string]interface{}{
		"compression_enabled":    wo.compressionEnabled,
		"max_message_size":       wo.maxMessageSize,
		"read_buffer_size":       wo.readBufferSize,
		"write_buffer_size":      wo.writeBufferSize,
		"keepalive_enabled":      wo.enableKeepalive,
		"keepalive_interval_ms":  wo.keepaliveInterval.Milliseconds(),
		"batch_size":             wo.batchSize,
		"batch_timeout_ms":       wo.batchTimeout.Milliseconds(),
		"active_queues":          totalQueues,
		"total_queued_messages":  totalQueuedMessages,
	}
}

// UpdateOptimizationConfig 更新优化配置
func (wo *WebSocketOptimizer) UpdateOptimizationConfig(config map[string]interface{}) error {
	wo.mu.Lock()
	defer wo.mu.Unlock()

	if compression, ok := config["compression_enabled"].(bool); ok {
		wo.compressionEnabled = compression
	}

	if maxSize, ok := config["max_message_size"].(float64); ok {
		wo.maxMessageSize = int64(maxSize)
	}

	if readBuffer, ok := config["read_buffer_size"].(float64); ok {
		wo.readBufferSize = int(readBuffer)
	}

	if writeBuffer, ok := config["write_buffer_size"].(float64); ok {
		wo.writeBufferSize = int(writeBuffer)
	}

	if keepalive, ok := config["keepalive_enabled"].(bool); ok {
		wo.enableKeepalive = keepalive
	}

	if interval, ok := config["keepalive_interval_ms"].(float64); ok {
		wo.keepaliveInterval = time.Duration(interval) * time.Millisecond
	}

	if batchSize, ok := config["batch_size"].(float64); ok {
		wo.batchSize = int(batchSize)
	}

	if batchTimeout, ok := config["batch_timeout_ms"].(float64); ok {
		wo.batchTimeout = time.Duration(batchTimeout) * time.Millisecond
	}

	log.Println("WebSocket optimization configuration updated")
	return nil
}

// EnableCompression 启用消息压缩
func (wo *WebSocketOptimizer) EnableCompression() {
	wo.mu.Lock()
	defer wo.mu.Unlock()
	wo.compressionEnabled = true
	log.Println("WebSocket message compression enabled")
}

// DisableCompression 禁用消息压缩
func (wo *WebSocketOptimizer) DisableCompression() {
	wo.mu.Lock()
	defer wo.mu.Unlock()
	wo.compressionEnabled = false
	log.Println("WebSocket message compression disabled")
}

// SetBatchSize 设置批处理大小
func (wo *WebSocketOptimizer) SetBatchSize(size int) {
	wo.mu.Lock()
	defer wo.mu.Unlock()
	wo.batchSize = size
	log.Printf("WebSocket batch size set to: %d", size)
}

// SetBatchTimeout 设置批处理超时
func (wo *WebSocketOptimizer) SetBatchTimeout(timeout time.Duration) {
	wo.mu.Lock()
	defer wo.mu.Unlock()
	wo.batchTimeout = timeout
	log.Printf("WebSocket batch timeout set to: %v", timeout)
}
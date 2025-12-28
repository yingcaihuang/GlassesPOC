package service

import (
	"testing"
	"time"
)

func TestPerformanceMonitorCreation(t *testing.T) {
	pm := NewPerformanceMonitor()
	if pm == nil {
		t.Fatal("Failed to create performance monitor")
	}

	// Test basic functionality
	if pm.performanceThresholds.MaxAudioLatency != 500*time.Millisecond {
		t.Errorf("Expected max audio latency 500ms, got %v", pm.performanceThresholds.MaxAudioLatency)
	}

	// Test system metrics collector
	if pm.systemMetricsCollector == nil {
		t.Error("System metrics collector should not be nil")
	}

	// Test WebSocket optimizer
	if pm.websocketOptimizer == nil {
		t.Error("WebSocket optimizer should not be nil")
	}

	// Cleanup
	pm.Shutdown()
}

func TestAudioLatencyMonitoring(t *testing.T) {
	pm := NewPerformanceMonitor()
	defer pm.Shutdown()

	sessionID := "test-session-123"
	userID := "test-user-456"

	// Start monitoring
	pm.StartAudioLatencyMonitoring(sessionID, userID)

	// Simulate audio processing
	processingStart := time.Now()
	time.Sleep(10 * time.Millisecond) // Simulate processing time
	transmissionStart := time.Now()
	time.Sleep(5 * time.Millisecond) // Simulate transmission time

	// Measure latency
	pm.MeasureAudioLatency(sessionID, processingStart, transmissionStart)

	// Get metrics
	metrics := pm.GetAudioLatencyMetrics(sessionID)
	if metrics == nil {
		t.Fatal("Audio latency metrics should not be nil")
	}

	if metrics.SessionID != sessionID {
		t.Errorf("Expected session ID %s, got %s", sessionID, metrics.SessionID)
	}

	if metrics.UserID != userID {
		t.Errorf("Expected user ID %s, got %s", userID, metrics.UserID)
	}

	if metrics.SampleCount != 1 {
		t.Errorf("Expected sample count 1, got %d", metrics.SampleCount)
	}

	if metrics.TotalLatency <= 0 {
		t.Error("Total latency should be greater than 0")
	}
}

func TestWebSocketMonitoring(t *testing.T) {
	pm := NewPerformanceMonitor()
	defer pm.Shutdown()

	sessionID := "test-ws-session-123"

	// Start monitoring
	pm.StartWebSocketMonitoring(sessionID)

	// Record some messages
	pm.RecordWebSocketMessage(sessionID, "sent", 1024, 50*time.Millisecond, false)
	pm.RecordWebSocketMessage(sessionID, "received", 512, 30*time.Millisecond, false)
	pm.RecordWebSocketMessage(sessionID, "sent", 2048, 100*time.Millisecond, true) // Error message

	// Get metrics
	metrics := pm.GetWebSocketMetrics(sessionID)
	if metrics == nil {
		t.Fatal("WebSocket metrics should not be nil")
	}

	if metrics.MessagesSent != 2 {
		t.Errorf("Expected 2 messages sent, got %d", metrics.MessagesSent)
	}

	if metrics.MessagesReceived != 1 {
		t.Errorf("Expected 1 message received, got %d", metrics.MessagesReceived)
	}

	if metrics.ErrorCount != 1 {
		t.Errorf("Expected 1 error, got %d", metrics.ErrorCount)
	}

	if metrics.BytesSent != 3072 { // 1024 + 2048
		t.Errorf("Expected 3072 bytes sent, got %d", metrics.BytesSent)
	}

	if metrics.BytesReceived != 512 {
		t.Errorf("Expected 512 bytes received, got %d", metrics.BytesReceived)
	}
}

func TestConnectionPool(t *testing.T) {
	pm := NewPerformanceMonitor()
	defer pm.Shutdown()

	sessionID1 := "session-1"
	sessionID2 := "session-2"
	userID := "test-user"

	// Get connections
	conn1 := pm.GetConnection(sessionID1, userID)
	if conn1 == nil {
		t.Fatal("Should get a connection")
	}

	conn2 := pm.GetConnection(sessionID2, userID)
	if conn2 == nil {
		t.Fatal("Should get a connection")
	}

	// Check stats
	stats := pm.GetConnectionPoolStats()
	if stats["active_connections"].(int) != 2 {
		t.Errorf("Expected 2 active connections, got %v", stats["active_connections"])
	}

	if stats["total_created"].(int64) != 2 {
		t.Errorf("Expected 2 total created, got %v", stats["total_created"])
	}

	// Release connections
	pm.ReleaseConnection(sessionID1)
	pm.ReleaseConnection(sessionID2)

	// Check stats again
	stats = pm.GetConnectionPoolStats()
	if stats["active_connections"].(int) != 0 {
		t.Errorf("Expected 0 active connections, got %v", stats["active_connections"])
	}
}

func TestResourceMetrics(t *testing.T) {
	pm := NewPerformanceMonitor()
	defer pm.Shutdown()

	// Update metrics
	pm.UpdateResourceMetrics(75.5, 1024*1024*512, 50.0, 150, 1024*1024*256, 10*time.Millisecond)

	// Get metrics
	metrics := pm.GetResourceMetrics()
	if metrics == nil {
		t.Fatal("Resource metrics should not be nil")
	}

	if metrics.CPUUsage != 75.5 {
		t.Errorf("Expected CPU usage 75.5, got %f", metrics.CPUUsage)
	}

	if metrics.MemoryUsage != 1024*1024*512 {
		t.Errorf("Expected memory usage %d, got %d", 1024*1024*512, metrics.MemoryUsage)
	}

	if metrics.GoroutineCount != 150 {
		t.Errorf("Expected goroutine count 150, got %d", metrics.GoroutineCount)
	}
}

func TestPerformanceThresholds(t *testing.T) {
	pm := NewPerformanceMonitor()
	defer pm.Shutdown()

	// Test default thresholds
	if pm.performanceThresholds.MaxAudioLatency != 500*time.Millisecond {
		t.Errorf("Expected max audio latency 500ms, got %v", pm.performanceThresholds.MaxAudioLatency)
	}

	// Update thresholds
	newThresholds := &PerformanceThresholds{
		MaxAudioLatency:   300 * time.Millisecond,
		MaxMessageLatency: 50 * time.Millisecond,
		MaxCPUUsage:       90.0,
		MaxMemoryUsage:    2 * 1024 * 1024 * 1024, // 2GB
		MaxGoroutines:     2000,
		MinQualityScore:   80.0,
		AlertCooldown:     3 * time.Minute,
	}

	pm.SetPerformanceThresholds(newThresholds)

	if pm.performanceThresholds.MaxAudioLatency != 300*time.Millisecond {
		t.Errorf("Expected updated max audio latency 300ms, got %v", pm.performanceThresholds.MaxAudioLatency)
	}

	if pm.performanceThresholds.MaxCPUUsage != 90.0 {
		t.Errorf("Expected updated max CPU usage 90.0, got %f", pm.performanceThresholds.MaxCPUUsage)
	}
}
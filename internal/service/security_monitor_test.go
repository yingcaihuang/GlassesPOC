package service

import (
	"testing"
	"time"
)

func TestSecurityMonitor_StartSession(t *testing.T) {
	sm := NewSecurityMonitor()
	defer sm.Shutdown()

	userID := "test-user-123"
	userEmail := "test@example.com"
	clientIP := "192.168.1.100"
	userAgent := "Test-Agent/1.0"

	session, err := sm.StartSession(userID, userEmail, clientIP, userAgent)
	if err != nil {
		t.Fatalf("Failed to start session: %v", err)
	}

	if session.UserID != userID {
		t.Errorf("Expected UserID %s, got %s", userID, session.UserID)
	}

	if session.Status != SessionStatusActive {
		t.Errorf("Expected status %s, got %s", SessionStatusActive, session.Status)
	}

	if session.ClientIP != clientIP {
		t.Errorf("Expected ClientIP %s, got %s", clientIP, session.ClientIP)
	}
}

func TestSecurityMonitor_SessionTimeout(t *testing.T) {
	sm := NewSecurityMonitor()
	defer sm.Shutdown()

	// Set a very short timeout for testing
	sm.SetSessionTimeout(100 * time.Millisecond)

	session, err := sm.StartSession("test-user", "test@example.com", "127.0.0.1", "Test-Agent")
	if err != nil {
		t.Fatalf("Failed to start session: %v", err)
	}

	// Wait for timeout
	time.Sleep(150 * time.Millisecond)

	timeoutEvents := sm.CheckSessionTimeout()
	if len(timeoutEvents) != 1 {
		t.Errorf("Expected 1 timeout event, got %d", len(timeoutEvents))
	}

	if timeoutEvents[0].SessionID != session.ID {
		t.Errorf("Expected timeout for session %s, got %s", session.ID, timeoutEvents[0].SessionID)
	}
}

func TestSecurityMonitor_ConnectionMonitoring(t *testing.T) {
	sm := NewSecurityMonitor()
	defer sm.Shutdown()

	sessionID := "test-session-123"
	userID := "test-user-123"

	// Start monitoring
	sm.StartConnectionMonitoring(sessionID, userID)

	// Update metrics
	sm.UpdateConnectionMetric(sessionID, 50.0, 1024, false)
	sm.UpdateConnectionMetric(sessionID, 75.0, 2048, false)

	// Get quality
	metric := sm.GetConnectionQuality(sessionID)
	if metric == nil {
		t.Fatal("Expected connection metric, got nil")
	}

	if metric.SessionID != sessionID {
		t.Errorf("Expected SessionID %s, got %s", sessionID, metric.SessionID)
	}

	if metric.PingCount != 2 {
		t.Errorf("Expected PingCount 2, got %d", metric.PingCount)
	}

	if metric.Quality != "excellent" {
		t.Errorf("Expected quality 'excellent', got '%s'", metric.Quality)
	}
}

func TestSecurityMonitor_AudioDataPrivacy(t *testing.T) {
	sm := NewSecurityMonitor()
	defer sm.Shutdown()

	// Privacy should be enabled by default
	if !sm.EnsureAudioDataPrivacy() {
		t.Error("Expected privacy mode to be enabled by default")
	}

	// Test validation
	err := sm.ValidateAudioDataHandling("process_audio")
	if err != nil {
		t.Errorf("Expected valid operation, got error: %v", err)
	}

	err = sm.ValidateAudioDataHandling("store_audio")
	if err == nil {
		t.Error("Expected error for forbidden operation, got nil")
	}
}

func TestSecurityMonitor_AccessLogging(t *testing.T) {
	sm := NewSecurityMonitor()
	defer sm.Shutdown()

	userID := "test-user"
	userEmail := "test@example.com"
	sessionID := "test-session"

	// Log an access
	sm.LogAccess(userID, userEmail, sessionID, "GET", "/api/test", "GET", 
		"127.0.0.1", "Test-Agent", 200, 100*time.Millisecond, "")

	// Get logs
	logs := sm.GetAccessLogs(10)
	if len(logs) != 1 {
		t.Errorf("Expected 1 log entry, got %d", len(logs))
	}

	log := logs[0]
	if log.UserID != userID {
		t.Errorf("Expected UserID %s, got %s", userID, log.UserID)
	}

	if log.StatusCode != 200 {
		t.Errorf("Expected StatusCode 200, got %d", log.StatusCode)
	}
}

func TestSecurityMonitor_SessionStats(t *testing.T) {
	sm := NewSecurityMonitor()
	defer sm.Shutdown()

	// Start a few sessions
	sm.StartSession("user1", "user1@example.com", "127.0.0.1", "Agent1")
	sm.StartSession("user2", "user2@example.com", "127.0.0.2", "Agent2")

	stats := sm.GetSessionStats()
	
	totalSessions, ok := stats["total_sessions"].(int)
	if !ok || totalSessions != 2 {
		t.Errorf("Expected total_sessions 2, got %v", stats["total_sessions"])
	}

	activeSessions, ok := stats["active_sessions"].(int)
	if !ok || activeSessions != 2 {
		t.Errorf("Expected active_sessions 2, got %v", stats["active_sessions"])
	}
}
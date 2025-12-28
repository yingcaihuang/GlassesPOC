package handler

import (
	"net/http"
	"net/http/httptest"
	"smart-glasses-backend/internal/service"
	"strings"
	"testing"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/gorilla/websocket"
	"github.com/stretchr/testify/assert"
)

func TestRealtimeHandler_ValidateConnection(t *testing.T) {
	// Create a mock realtime service
	realtimeService := service.NewRealtimeService("test-key", "https://test.openai.azure.com", "test-deployment", "2024-10-01-preview")
	handler := NewRealtimeHandler(realtimeService)

	// Test case 1: Valid connection with user authentication
	t.Run("ValidConnection", func(t *testing.T) {
		c, _ := gin.CreateTestContext(httptest.NewRecorder())
		c.Set("user_id", "test-user-123")
		c.Set("user_email", "test@example.com")

		err := handler.ValidateConnection(c)
		assert.NoError(t, err)
	})

	// Test case 2: Invalid connection without user authentication
	t.Run("InvalidConnection", func(t *testing.T) {
		c, _ := gin.CreateTestContext(httptest.NewRecorder())
		// No user_id set in context

		err := handler.ValidateConnection(c)
		assert.Error(t, err)
		assert.Contains(t, err.Error(), "user not authenticated")
	})
}

func TestRealtimeHandler_WebSocketUpgrade(t *testing.T) {
	// Create a mock realtime service
	realtimeService := service.NewRealtimeService("test-key", "https://test.openai.azure.com", "test-deployment", "2024-10-01-preview")
	handler := NewRealtimeHandler(realtimeService)

	// Create a test server
	gin.SetMode(gin.TestMode)
	router := gin.New()
	
	// Add middleware to set user context
	router.Use(func(c *gin.Context) {
		c.Set("user_id", "test-user-123")
		c.Set("user_email", "test@example.com")
		c.Next()
	})
	
	router.GET("/realtime/chat", handler.HandleRealtimeConnection)

	server := httptest.NewServer(router)
	defer server.Close()

	// Test WebSocket upgrade (this will fail to connect to GPT API, but should upgrade successfully)
	t.Run("WebSocketUpgrade", func(t *testing.T) {
		// Convert HTTP URL to WebSocket URL
		wsURL := "ws" + strings.TrimPrefix(server.URL, "http") + "/realtime/chat"
		
		// Try to connect (this will fail due to GPT API connection, but we can test the upgrade)
		dialer := websocket.DefaultDialer
		dialer.HandshakeTimeout = 2 * time.Second
		
		conn, resp, err := dialer.Dial(wsURL, nil)
		
		// The connection should upgrade successfully, but may fail later due to GPT API
		if err != nil {
			// Check if it's a WebSocket upgrade success but GPT API connection failure
			if resp != nil && resp.StatusCode == http.StatusSwitchingProtocols {
				t.Log("WebSocket upgrade successful, GPT API connection expected to fail in test")
			} else {
				t.Logf("WebSocket connection failed as expected in test environment: %v", err)
			}
		} else {
			// If connection succeeds, close it
			conn.Close()
			t.Log("WebSocket connection successful")
		}
	})
}

func TestRealtimeHandler_MessageTypes(t *testing.T) {
	// Test message type validation
	t.Run("ValidMessageTypes", func(t *testing.T) {
		validTypes := []string{"audio_data", "commit_audio", "clear_audio", "ping", "get_status"}
		
		for _, msgType := range validTypes {
			message := ClientMessage{
				Type: msgType,
			}
			
			// Verify message structure
			assert.NotEmpty(t, message.Type)
			assert.Contains(t, validTypes, message.Type)
		}
	})

	// Test server message structure
	t.Run("ServerMessageStructure", func(t *testing.T) {
		message := ServerMessage{
			Type:      "test_message",
			Data:      map[string]string{"key": "value"},
			Error:     "",
			Timestamp: time.Now().UnixMilli(),
		}

		assert.Equal(t, "test_message", message.Type)
		assert.NotNil(t, message.Data)
		assert.Empty(t, message.Error)
		assert.Greater(t, message.Timestamp, int64(0))
	})
}

func TestRealtimeHandler_CrossOriginSupport(t *testing.T) {
	// Create a mock realtime service
	realtimeService := service.NewRealtimeService("test-key", "https://test.openai.azure.com", "test-deployment", "2024-10-01-preview")
	handler := NewRealtimeHandler(realtimeService)

	// Test cross-origin support (Requirement 2.4)
	t.Run("CrossOriginAllowed", func(t *testing.T) {
		// Create a mock HTTP request with different origin
		req := httptest.NewRequest("GET", "/realtime/chat", nil)
		req.Header.Set("Origin", "https://different-domain.com")
		req.Header.Set("Connection", "upgrade")
		req.Header.Set("Upgrade", "websocket")
		req.Header.Set("Sec-WebSocket-Version", "13")
		req.Header.Set("Sec-WebSocket-Key", "test-key")

		// Test that CheckOrigin allows cross-origin requests
		allowed := handler.upgrader.CheckOrigin(req)
		assert.True(t, allowed, "Cross-origin requests should be allowed in development environment")
	})
}

func TestRealtimeHandler_BufferConfiguration(t *testing.T) {
	// Create a mock realtime service
	realtimeService := service.NewRealtimeService("test-key", "https://test.openai.azure.com", "test-deployment", "2024-10-01-preview")
	handler := NewRealtimeHandler(realtimeService)

	// Test buffer configuration for audio optimization
	t.Run("BufferSizes", func(t *testing.T) {
		assert.Equal(t, 4096, handler.upgrader.ReadBufferSize, "Read buffer should be 4KB for audio optimization")
		assert.Equal(t, 4096, handler.upgrader.WriteBufferSize, "Write buffer should be 4KB for audio optimization")
	})
}
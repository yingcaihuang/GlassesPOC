package handler

import (
	"context"
	"log"
	"net/http"
	"smart-glasses-backend/internal/service"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/gorilla/websocket"
)

type RealtimeHandler struct {
	upgrader        websocket.Upgrader
	realtimeService *service.RealtimeService
}

type ClientMessage struct {
	Type      string `json:"type"`
	Audio     string `json:"audio,omitempty"`
	SessionID string `json:"session_id,omitempty"`
}

type ServerMessage struct {
	Type      string      `json:"type"`
	Data      interface{} `json:"data,omitempty"`
	Error     string      `json:"error,omitempty"`
	Timestamp int64       `json:"timestamp"`
}

func NewRealtimeHandler(realtimeService *service.RealtimeService) *RealtimeHandler {
	return &RealtimeHandler{
		realtimeService: realtimeService,
		upgrader: websocket.Upgrader{
			CheckOrigin: func(r *http.Request) bool {
				return true // 允许所有跨域连接（开发环境）
			},
			ReadBufferSize:  4096,
			WriteBufferSize: 4096,
		},
	}
}

// HandleRealtimeConnection 处理实时WebSocket连接，集成GPT Realtime API
func (h *RealtimeHandler) HandleRealtimeConnection(c *gin.Context) {
	// 获取用户信息
	userID, exists := c.Get("user_id")
	if !exists {
		log.Printf("User ID not found in context")
		c.JSON(http.StatusUnauthorized, gin.H{"error": "authentication required"})
		return
	}

	userEmail, _ := c.Get("user_email")
	
	log.Printf("Realtime connection request from user: %s (%s)", userID, userEmail)

	// WebSocket升级
	conn, err := h.upgrader.Upgrade(c.Writer, c.Request, nil)
	if err != nil {
		log.Printf("WebSocket upgrade failed: %v", err)
		c.JSON(http.StatusBadRequest, gin.H{
			"error": "websocket upgrade failed",
			"user_message": "WebSocket连接升级失败",
		})
		return
	}
	defer conn.Close()

	log.Printf("WebSocket connection established successfully for user: %s", userID)

	// 发送连接成功消息
	err = conn.WriteJSON(map[string]interface{}{
		"type": "connection_established",
		"user_id": userID,
		"status": "connected",
		"timestamp": time.Now().Unix(),
		"message": "WebSocket连接成功建立",
	})
	if err != nil {
		log.Printf("Failed to send connection message: %v", err)
		return
	}

	// 连接到GPT Realtime API
	ctx := context.Background()
	gptConn, err := h.realtimeService.ConnectToGPTRealtime(ctx)
	if err != nil {
		log.Printf("Failed to connect to GPT Realtime API: %v", err)
		log.Printf("Falling back to mock mode for testing")
		
		// 发送警告消息但继续处理
		conn.WriteJSON(map[string]interface{}{
			"type": "warning",
			"message": "GPT服务暂时不可用，使用测试模式",
			"timestamp": time.Now().Unix(),
		})
		
		// 使用模拟模式处理消息
		h.handleMockMode(conn, userID)
		return
	}
	defer gptConn.Close()

	log.Printf("Connected to GPT Realtime API for user: %s", userID)

	// 配置GPT会话
	err = h.realtimeService.ConfigureSession(gptConn)
	if err != nil {
		log.Printf("Failed to configure GPT session: %v", err)
		conn.WriteJSON(map[string]interface{}{
			"type": "error",
			"error": "session_config_failed",
			"message": "GPT会话配置失败",
			"timestamp": time.Now().Unix(),
		})
		return
	}

	// 启动GPT响应处理协程
	go h.realtimeService.HandleRealtimeResponse(gptConn, conn)

	// 客户端消息处理循环
	h.handleGPTMode(conn, gptConn, userID)
}

// handleMockMode 处理模拟模式（当GPT API不可用时）
func (h *RealtimeHandler) handleMockMode(conn *websocket.Conn, userID interface{}) {
	for {
		var msg map[string]interface{}
		err := conn.ReadJSON(&msg)
		if err != nil {
			log.Printf("WebSocket read error: %v", err)
			break
		}
		
		msgType, ok := msg["type"].(string)
		if !ok {
			continue
		}
		
		switch msgType {
		case "configure_session":
			conn.WriteJSON(map[string]interface{}{
				"type": "session_configured",
				"status": "success",
				"timestamp": time.Now().Unix(),
				"message": "会话配置成功（测试模式）",
			})
			
		case "commit_audio":
			// 模拟GPT回复
			conn.WriteJSON(map[string]interface{}{
				"type": "text_response",
				"text": "我听到了您的语音消息。当前处于测试模式，GPT Realtime API暂时不可用。请检查API配置后重试。",
				"timestamp": time.Now().Unix(),
			})
			
			conn.WriteJSON(map[string]interface{}{
				"type": "response_complete",
				"timestamp": time.Now().Unix(),
				"message": "音频处理完成（测试模式）",
			})
		}
	}
}

// handleGPTMode 处理真正的GPT模式
func (h *RealtimeHandler) handleGPTMode(conn *websocket.Conn, gptConn *websocket.Conn, userID interface{}) {
	for {
		var msg map[string]interface{}
		err := conn.ReadJSON(&msg)
		if err != nil {
			log.Printf("WebSocket read error: %v", err)
			break
		}
		
		msgType, ok := msg["type"].(string)
		if !ok {
			log.Printf("Invalid message type from %s: %v", userID, msg)
			continue
		}
		
		log.Printf("Received message type '%s' from %s", msgType, userID)
		
		// 根据消息类型处理
		switch msgType {
		case "configure_session":
			// 会话配置确认
			response := map[string]interface{}{
				"type": "session_configured",
				"status": "success",
				"timestamp": time.Now().Unix(),
				"message": "会话配置成功",
			}
			err = conn.WriteJSON(response)
			
		case "audio_data":
			// 处理音频数据 - 发送到GPT API
			if audioData, ok := msg["audio"].(string); ok {
				log.Printf("Received audio_data message from user: %s, base64 length: %d", userID, len(audioData))
				
				// 验证和解码音频数据
				decodedAudio, err := h.realtimeService.ValidateAudioData(audioData)
				if err != nil {
					log.Printf("Audio validation failed: %v", err)
					continue
				}
				
				log.Printf("Decoded audio data size: %d bytes", len(decodedAudio))
				
				// 发送音频数据到GPT API
				err = h.realtimeService.SendAudioData(gptConn, decodedAudio)
				if err != nil {
					log.Printf("Failed to send audio to GPT API: %v", err)
					conn.WriteJSON(map[string]interface{}{
						"type": "error",
						"error": "audio_send_failed",
						"message": "音频发送失败",
						"timestamp": time.Now().Unix(),
					})
				} else {
					log.Printf("Successfully sent audio data to GPT API")
				}
			} else {
				log.Printf("Received audio_data message without audio field from user: %s", userID)
			}
			
		case "commit_audio":
			// 提交音频缓冲区到GPT API
			log.Printf("Committing audio buffer for user: %s", userID)
			err = h.realtimeService.CommitAudioBuffer(gptConn)
			if err != nil {
				log.Printf("Failed to commit audio buffer: %v", err)
				conn.WriteJSON(map[string]interface{}{
					"type": "error",
					"error": "audio_commit_failed",
					"message": "音频提交失败",
					"timestamp": time.Now().Unix(),
				})
			}
			
		case "test":
			// 测试消息 - 回显
			response := map[string]interface{}{
				"type": "echo",
				"original": msg,
				"timestamp": time.Now().Unix(),
				"message": "消息已收到并回显",
			}
			err = conn.WriteJSON(response)
			
		default:
			// 未知消息类型
			log.Printf("Unknown message type '%s' from %s", msgType, userID)
			response := map[string]interface{}{
				"type": "error",
				"error": "unknown_message_type",
				"timestamp": time.Now().Unix(),
				"message": "未知的消息类型",
			}
			err = conn.WriteJSON(response)
		}
		
		if err != nil {
			log.Printf("WebSocket write error: %v", err)
			break
		}
	}
	
	log.Printf("WebSocket connection closed for user: %s", userID)
}

// HandleRealtimeConnectionSimple 别名，保持兼容性
func (h *RealtimeHandler) HandleRealtimeConnectionSimple(c *gin.Context) {
	h.HandleRealtimeConnection(c)
}
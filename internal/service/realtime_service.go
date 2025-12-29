package service

import (
	"context"
	"fmt"
	"io"
	"log"
	"net/http"
	"net/url"
	"sync"
	"time"

	"github.com/gorilla/websocket"
)

// RealtimeService 实现 GPT Realtime API 核心服务
type RealtimeService struct {
	apiKey             string
	endpoint           string
	deploymentName     string
	apiVersion         string
	mu                 sync.RWMutex
	connections        map[string]*websocket.Conn // 连接池管理
	audioProcessor     *AudioProcessor            // 音频处理组件
	errorHandler       *ErrorHandler              // 错误处理组件
	securityMonitor    *SecurityMonitor           // 安全监控组件
	performanceMonitor *PerformanceMonitor        // 性能监控组件
}

// SessionConfig 会话配置结构
type SessionConfig struct {
	Model             string                 `json:"model"`
	Modalities        []string               `json:"modalities"`
	Instructions      string                 `json:"instructions"`
	Voice             string                 `json:"voice"`
	InputAudioFormat  string                 `json:"input_audio_format"`
	OutputAudioFormat string                 `json:"output_audio_format"`
	TurnDetection     map[string]interface{} `json:"turn_detection"`
}

// RealtimeMessage GPT Realtime API 消息结构
type RealtimeMessage struct {
	Type  string      `json:"type"`
	Audio string      `json:"audio,omitempty"`
	Delta string      `json:"delta,omitempty"`
	Data  interface{} `json:"data,omitempty"`
	Error string      `json:"error,omitempty"`
}

// AudioMessage 音频消息结构
type AudioMessage struct {
	Type      string    `json:"type"`
	Audio     string    `json:"audio,omitempty"`
	Timestamp time.Time `json:"timestamp"`
	SessionID string    `json:"session_id"`
}

// ErrorResponse 错误响应结构
type ErrorResponse struct {
	Type    string `json:"type"`
	Code    string `json:"code"`
	Message string `json:"message"`
	Details string `json:"details,omitempty"`
}

// NewRealtimeService 创建新的 Realtime 服务实例
func NewRealtimeService(apiKey, endpoint, deploymentName, apiVersion string) *RealtimeService {
	return &RealtimeService{
		apiKey:             apiKey,
		endpoint:           endpoint,
		deploymentName:     deploymentName,
		apiVersion:         apiVersion,
		connections:        make(map[string]*websocket.Conn),
		audioProcessor:     NewAudioProcessor(),     // 初始化音频处理组件
		errorHandler:       NewErrorHandler(),       // 初始化错误处理组件
		securityMonitor:    NewSecurityMonitor(),    // 初始化安全监控组件
		performanceMonitor: NewPerformanceMonitor(), // 初始化性能监控组件
	}
}

// ConnectToGPTRealtime 连接到 Azure OpenAI GPT Realtime API
// Requirements: 4.1 - 使用 WebSocket 协议连接到 Azure OpenAI Realtime API
func (s *RealtimeService) ConnectToGPTRealtime(ctx context.Context) (*websocket.Conn, error) {
	// 构建 Azure OpenAI Realtime API WebSocket URL
	// 根据Azure官方文档，格式应该是：
	// wss://{your-resource-name}.openai.azure.com/openai/realtime?api-version={api-version}&deployment={deployment-name}
	
	u, err := url.Parse(s.endpoint)
	if err != nil {
		errorInfo := s.errorHandler.HandleGPTAPIError(s.endpoint, "INVALID_ENDPOINT", err.Error())
		s.errorHandler.LogError(errorInfo)
		return nil, fmt.Errorf("invalid endpoint: %v", err)
	}

	// 设置WebSocket协议和路径
	u.Scheme = "wss"
	u.Path = "/openai/realtime"

	// 设置查询参数
	query := u.Query()
	query.Set("api-version", s.apiVersion)
	query.Set("deployment", s.deploymentName)
	u.RawQuery = query.Encode()

	// 设置请求头 - 根据Azure官方文档
	headers := http.Header{}
	headers.Set("api-key", s.apiKey)
	headers.Set("OpenAI-Beta", "realtime=v1")
	
	log.Printf("Connecting to Azure OpenAI Realtime API: %s", u.String())

	// 连接 WebSocket
	dialer := websocket.DefaultDialer
	dialer.HandshakeTimeout = 30 * time.Second

	conn, resp, err := dialer.DialContext(ctx, u.String(), headers)
	if err != nil {
		// 记录详细的错误信息
		var respBody string
		if resp != nil {
			if body, readErr := io.ReadAll(resp.Body); readErr == nil {
				respBody = string(body)
			}
			log.Printf("WebSocket handshake failed. Status: %d, Headers: %v, Body: %s", 
				resp.StatusCode, resp.Header, respBody)
		}
		
		errorInfo := s.errorHandler.HandleGPTAPIError(u.String(), "CONNECTION_FAILED", 
			fmt.Sprintf("websocket handshake failed: %v", err))
		s.errorHandler.LogError(errorInfo)
		return nil, fmt.Errorf("failed to connect to GPT Realtime API: %v", err)
	}

	// 设置连接参数
	conn.SetReadDeadline(time.Now().Add(60 * time.Second))
	conn.SetWriteDeadline(time.Now().Add(10 * time.Second))

	// 重置连接尝试次数（连接成功）
	s.errorHandler.ResetConnectionAttempts(u.String())
	log.Printf("Successfully connected to Azure OpenAI Realtime API: %s", u.String())
	return conn, nil
}

// ConfigureSession 配置会话
// Requirements: 4.2-4.8 - 发送会话配置消息，配置模型、音频格式、语音、指令和VAD
func (s *RealtimeService) ConfigureSession(conn *websocket.Conn) error {
	// 根据Azure官方文档的会话配置格式
	config := map[string]interface{}{
		"type": "session.update",
		"session": map[string]interface{}{
			"model":             "gpt-4o-realtime-preview", // Requirement 4.3
			"modalities":        []string{"text", "audio"},
			"instructions":      "你是一个友好的AI助手，可以进行语音对话。请用中文回复。", // Requirement 4.7
			"voice":             "alloy",                        // Requirement 4.6
			"input_audio_format":  "pcm16",                      // Requirement 4.4
			"output_audio_format": "pcm16",                      // Requirement 4.5
			"input_audio_transcription": map[string]interface{}{
				"model": "whisper-1",
			},
			"turn_detection": map[string]interface{}{ // Requirement 4.8 - 启用服务器端VAD
				"type":                "server_vad",
				"threshold":           0.5,
				"prefix_padding_ms":   300,
				"silence_duration_ms": 200,
			},
		},
	}

	if err := conn.WriteJSON(config); err != nil {
		return fmt.Errorf("failed to send session config: %v", err)
	}

	log.Println("Session configuration sent successfully")
	return nil
}

// SendAudioData 发送音频数据到 GPT Realtime API
// Requirements: 3.1-3.3 - 验证Base64格式，解码并转发到GPT API
func (s *RealtimeService) SendAudioData(conn *websocket.Conn, audioData []byte) error {
	if conn == nil {
		return fmt.Errorf("connection is nil")
	}

	// 验证音频数据不为空
	if len(audioData) == 0 {
		return fmt.Errorf("audio data is empty")
	}

	// 开始性能监控
	processingStart := time.Now()

	// Requirements: 10.2 - 确保音频数据隐私保护
	if err := s.securityMonitor.ValidateAudioDataHandling("process_audio"); err != nil {
		log.Printf("Audio data privacy validation failed: %v", err)
		return fmt.Errorf("audio data privacy validation failed: %v", err)
	}

	// 使用音频处理器验证和处理音频数据
	err := s.audioProcessor.ValidateAudioFormat(audioData)
	if err != nil {
		// Requirements: 3.4 - 记录错误并继续处理
		log.Printf("Audio format validation failed: %v", err)
		if recoveredErr := s.audioProcessor.RecoverFromError(err, "SendAudioData"); recoveredErr != nil {
			return recoveredErr
		}
		// 如果错误已恢复，继续处理
	}

	// 编码为Base64用于传输 (Requirement 7.4)
	encodedAudio := s.audioProcessor.EncodeAudioToBase64(audioData)
	log.Printf("Sending audio data to GPT API: original size=%d bytes, base64 length=%d", len(audioData), len(encodedAudio))

	// 根据GPT Realtime API规范发送音频数据
	msg := map[string]interface{}{
		"type":  "input_audio_buffer.append",
		"audio": encodedAudio,
	}

	// 传输开始时间
	transmissionStart := time.Now()

	// 设置写入超时
	conn.SetWriteDeadline(time.Now().Add(5 * time.Second))

	if err := conn.WriteJSON(msg); err != nil {
		log.Printf("Error sending audio data: %v", err) // Requirement 3.4 - 记录错误
		return fmt.Errorf("failed to send audio data: %v", err)
	}

	// 记录性能指标 - 音频延迟监控 (Requirements: 9.1)
	sessionID := fmt.Sprintf("conn_%p", conn)
	s.performanceMonitor.MeasureAudioLatency(sessionID, processingStart, transmissionStart)

	return nil
}

// CommitAudioBuffer 提交音频缓冲区
func (s *RealtimeService) CommitAudioBuffer(conn *websocket.Conn) error {
	if conn == nil {
		return fmt.Errorf("connection is nil")
	}

	msg := map[string]string{
		"type": "input_audio_buffer.commit",
	}

	conn.SetWriteDeadline(time.Now().Add(5 * time.Second))

	if err := conn.WriteJSON(msg); err != nil {
		return fmt.Errorf("failed to commit audio buffer: %v", err)
	}

	return nil
}

// HandleRealtimeResponse 处理来自 GPT Realtime API 的响应
// Requirements: 5.1-5.5 - 转发音频/文本响应，发送完成信号，处理错误，保持低延迟
func (s *RealtimeService) HandleRealtimeResponse(gptConn *websocket.Conn, clientConn *websocket.Conn) {
	defer func() {
		if r := recover(); r != nil {
			log.Printf("Panic in HandleRealtimeResponse: %v", r)
			// 使用错误处理器处理panic
			panicErr := fmt.Errorf("panic in HandleRealtimeResponse: %v", r)
			errorInfo, _ := s.errorHandler.HandleError(panicErr)
			s.errorHandler.LogError(errorInfo)
		}
	}()

	for {
		// 设置读取超时
		gptConn.SetReadDeadline(time.Now().Add(60 * time.Second))

		var response map[string]interface{}
		err := gptConn.ReadJSON(&response)
		if err != nil {
			// 使用错误处理器处理连接错误
			connErr := &ConnectionError{
				Endpoint: "GPT Realtime API",
				Reason:   err.Error(),
				Attempts: s.errorHandler.GetConnectionAttempts("gpt_api"),
			}
			errorInfo, _ := s.errorHandler.HandleError(connErr)
			s.errorHandler.LogError(errorInfo)
			
			// 发送用户友好的错误信息到客户端 (Requirement 5.4)
			s.sendErrorToClient(clientConn, "connection_error", errorInfo.UserMessage, err.Error())
			break
		}

		responseType, ok := response["type"].(string)
		if !ok {
			log.Printf("Invalid response type from GPT API: %v", response)
			continue
		}

		log.Printf("Received from GPT API: %s", responseType)

		// 处理不同类型的响应，保持实时性 (Requirement 5.5)
		switch responseType {
		case "response.audio.delta":
			// Requirement 5.1 - 转发音频响应到客户端
			if audioData, ok := response["delta"].(string); ok {
				log.Printf("Sending audio response to client: %d bytes", len(audioData))
				clientMsg := map[string]interface{}{
					"type":      "audio_response",
					"audio":     audioData,
					"timestamp": time.Now().UnixMilli(),
				}
				s.sendToClientWithTimeout(clientConn, clientMsg)
				log.Printf("Audio response sent to client successfully")
			} else {
				log.Printf("No audio data in response.audio.delta: %v", response)
			}

		case "response.text.delta":
			// Requirement 5.2 - 转发文本响应到客户端
			if textData, ok := response["delta"].(string); ok {
				clientMsg := map[string]interface{}{
					"type":      "text_response",
					"text":      textData,
					"timestamp": time.Now().UnixMilli(),
				}
				s.sendToClientWithTimeout(clientConn, clientMsg)
			}

		case "response.done":
			// Requirement 5.3 - 发送完成信号
			clientMsg := map[string]interface{}{
				"type":      "response_complete",
				"timestamp": time.Now().UnixMilli(),
			}
			s.sendToClientWithTimeout(clientConn, clientMsg)

		case "error":
			// Requirement 5.4 - 发送错误信息到客户端，使用错误处理器
			log.Printf("GPT API error: %v", response)
			errorMsg := "Unknown error"
			errorCode := "UNKNOWN_ERROR"
			
			if errData, ok := response["error"].(map[string]interface{}); ok {
				if msg, ok := errData["message"].(string); ok {
					errorMsg = msg
				}
				if code, ok := errData["code"].(string); ok {
					errorCode = code
				}
			}
			
			// 使用错误处理器创建用户友好的错误信息
			errorInfo := s.errorHandler.HandleGPTAPIError("GPT Realtime API", errorCode, errorMsg)
			s.errorHandler.LogError(errorInfo)
			s.sendErrorToClient(clientConn, "gpt_api_error", errorInfo.UserMessage, fmt.Sprintf("%v", response))

		case "session.created":
			log.Println("Session created successfully")

		case "session.updated":
			log.Println("Session updated successfully")

		case "input_audio_buffer.committed":
			log.Println("Audio buffer committed")

		case "input_audio_buffer.cleared":
			log.Println("Audio buffer cleared")

		case "conversation.item.created":
			log.Println("Conversation item created")

		case "response.created":
			log.Println("Response created")

		case "response.output_item.added":
			log.Println("Response output item added")

		case "response.content_part.added":
			log.Println("Response content part added")

		case "response.audio.done":
			log.Println("Audio response completed")

		case "response.text.done":
			log.Println("Text response completed")

		default:
			log.Printf("Unhandled response type: %s", responseType)
		}
	}
}

// sendToClientWithTimeout 带超时的客户端消息发送
func (s *RealtimeService) sendToClientWithTimeout(clientConn *websocket.Conn, message interface{}) {
	if clientConn == nil {
		log.Printf("Cannot send message: client connection is nil")
		return
	}

	// 记录WebSocket消息性能 (Requirements: 9.2)
	messageStart := time.Now()
	sessionID := fmt.Sprintf("conn_%p", clientConn)

	// 记录发送的消息类型
	if msgMap, ok := message.(map[string]interface{}); ok {
		if msgType, ok := msgMap["type"].(string); ok {
			log.Printf("Sending message to client: type=%s", msgType)
		}
	}

	clientConn.SetWriteDeadline(time.Now().Add(2 * time.Second))
	err := clientConn.WriteJSON(message)
	
	// 计算消息延迟并记录
	messageLatency := time.Since(messageStart)
	messageSize := 0 // 实际实现中应该计算消息大小
	
	s.performanceMonitor.RecordWebSocketMessage(sessionID, "sent", messageSize, messageLatency, err != nil)

	if err != nil {
		log.Printf("Error sending message to client: %v", err)
	} else {
		log.Printf("Message sent to client successfully in %v", messageLatency)
	}
}

// sendErrorToClient 发送错误信息到客户端
func (s *RealtimeService) sendErrorToClient(clientConn *websocket.Conn, code, message, details string) {
	if clientConn == nil {
		return
	}

	errorMsg := ErrorResponse{
		Type:    "error",
		Code:    code,
		Message: message,
		Details: details,
	}

	s.sendToClientWithTimeout(clientConn, errorMsg)
}

// ValidateAudioData 验证音频数据格式
// Requirements: 3.1 - 验证数据格式为Base64编码
func (s *RealtimeService) ValidateAudioData(audioData string) ([]byte, error) {
	// 使用音频处理器进行验证和解码
	decodedData, err := s.audioProcessor.DecodeBase64Audio(audioData)
	if err != nil {
		// 尝试错误恢复
		if recoveredErr := s.audioProcessor.RecoverFromError(err, "ValidateAudioData"); recoveredErr != nil {
			return nil, recoveredErr
		}
		// 如果错误已恢复，返回空数据但不报错
		return []byte{}, nil
	}

	return decodedData, nil
}

// ProcessAudioStream 处理实时音频流
// Requirements: 3.5 - 支持实时音频流处理（100ms块）
func (s *RealtimeService) ProcessAudioStream(conn *websocket.Conn, audioChunk []byte) error {
	if len(audioChunk) == 0 {
		return fmt.Errorf("audio chunk is empty")
	}

	// 使用音频处理器处理实时音频块
	processedChunk, err := s.audioProcessor.ProcessRealtimeAudioChunk(audioChunk)
	if err != nil {
		// 尝试错误恢复
		if recoveredErr := s.audioProcessor.RecoverFromError(err, "ProcessAudioStream"); recoveredErr != nil {
			return recoveredErr
		}
		// 如果错误已恢复，跳过当前块
		log.Printf("Skipping audio chunk due to recovered error: %v", err)
		return nil
	}

	return s.SendAudioData(conn, processedChunk)
}

// CloseConnection 关闭连接
func (s *RealtimeService) CloseConnection(conn *websocket.Conn) error {
	if conn == nil {
		return nil
	}

	// 发送关闭消息
	closeMsg := websocket.FormatCloseMessage(websocket.CloseNormalClosure, "Session ended")
	conn.WriteMessage(websocket.CloseMessage, closeMsg)

	return conn.Close()
}

// GetConnectionStatus 获取连接状态
func (s *RealtimeService) GetConnectionStatus(conn *websocket.Conn) bool {
	if conn == nil {
		return false
	}

	// 尝试发送ping消息检查连接状态
	err := conn.WriteMessage(websocket.PingMessage, []byte{})
	return err == nil
}

// GetAudioProcessor 获取音频处理器实例
func (s *RealtimeService) GetAudioProcessor() *AudioProcessor {
	return s.audioProcessor
}

// GetErrorHandler 获取错误处理器实例
func (s *RealtimeService) GetErrorHandler() *ErrorHandler {
	return s.errorHandler
}

// GetSecurityMonitor 获取安全监控实例
func (s *RealtimeService) GetSecurityMonitor() *SecurityMonitor {
	return s.securityMonitor
}

// GetPerformanceMonitor 获取性能监控实例
func (s *RealtimeService) GetPerformanceMonitor() *PerformanceMonitor {
	return s.performanceMonitor
}

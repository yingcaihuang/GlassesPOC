package service

import (
	"context"
	"fmt"
	"log"
	"sync"
	"time"

	"github.com/gorilla/websocket"
)

// ErrorHandler 错误处理和恢复机制
type ErrorHandler struct {
	mu                sync.RWMutex
	reconnectAttempts map[string]int    // 重连尝试次数记录
	maxRetries        int               // 最大重试次数
	retryInterval     time.Duration     // 重试间隔
	circuitBreaker    bool              // 熔断器状态
	errorCallbacks    map[string]func() // 错误回调函数
}

// ErrorType 错误类型枚举
type ErrorType string

const (
	ErrorTypeConnection    ErrorType = "connection_error"
	ErrorTypeGPTAPI        ErrorType = "gpt_api_error"
	ErrorTypePermission    ErrorType = "permission_error"
	ErrorTypeAudioPlayback ErrorType = "audio_playback_error"
	ErrorTypeValidation    ErrorType = "validation_error"
	ErrorTypeTimeout       ErrorType = "timeout_error"
)

// RecoveryAction 恢复动作枚举
type RecoveryAction string

const (
	ActionRetryWithBackoff RecoveryAction = "retry_with_backoff"
	ActionFailFast         RecoveryAction = "fail_fast"
	ActionContinueProcess  RecoveryAction = "continue_processing"
	ActionLogAndContinue   RecoveryAction = "log_and_continue"
	ActionCircuitBreaker   RecoveryAction = "circuit_breaker"
)

// ErrorInfo 错误信息结构
type ErrorInfo struct {
	Type        ErrorType   `json:"type"`
	Code        string      `json:"code"`
	Message     string      `json:"message"`
	Details     string      `json:"details,omitempty"`
	Timestamp   time.Time   `json:"timestamp"`
	UserMessage string      `json:"user_message"` // 用户友好的错误消息
	Recoverable bool        `json:"recoverable"`
	Action      RecoveryAction `json:"action"`
}

// ConnectionError WebSocket连接错误
type ConnectionError struct {
	Endpoint string
	Reason   string
	Attempts int
}

func (e *ConnectionError) Error() string {
	return fmt.Sprintf("connection error to %s: %s (attempts: %d)", e.Endpoint, e.Reason, e.Attempts)
}

// GPTAPIError GPT API错误
type GPTAPIError struct {
	Endpoint string
	Code     string
	Message  string
}

func (e *GPTAPIError) Error() string {
	return fmt.Sprintf("GPT API error [%s]: %s", e.Code, e.Message)
}

// PermissionError 权限错误
type PermissionError struct {
	Permission string
	Reason     string
}

func (e *PermissionError) Error() string {
	return fmt.Sprintf("permission error for %s: %s", e.Permission, e.Reason)
}

// AudioPlaybackError 音频播放错误
type AudioPlaybackError struct {
	Reason  string
	Details string
}

func (e *AudioPlaybackError) Error() string {
	return fmt.Sprintf("audio playback error: %s - %s", e.Reason, e.Details)
}

// NewErrorHandler 创建新的错误处理器
func NewErrorHandler() *ErrorHandler {
	return &ErrorHandler{
		reconnectAttempts: make(map[string]int),
		maxRetries:        3,
		retryInterval:     5 * time.Second,
		circuitBreaker:    false,
		errorCallbacks:    make(map[string]func()),
	}
}

// HandleError 处理错误并返回恢复动作
// Requirements: 8.1, 8.2, 8.3, 8.4, 8.5 - 处理各种错误情况并提供恢复机制
func (eh *ErrorHandler) HandleError(err error) (*ErrorInfo, RecoveryAction) {
	if err == nil {
		return nil, ActionContinueProcess
	}

	errorInfo := &ErrorInfo{
		Timestamp: time.Now(),
	}

	switch e := err.(type) {
	case *ConnectionError:
		// Requirement 8.1 - WebSocket连接断开时尝试自动重连
		errorInfo.Type = ErrorTypeConnection
		errorInfo.Code = "CONNECTION_LOST"
		errorInfo.Message = e.Error()
		errorInfo.Details = fmt.Sprintf("Connection to %s failed after %d attempts", e.Endpoint, e.Attempts)
		errorInfo.UserMessage = "连接已断开，正在尝试重新连接..."
		errorInfo.Recoverable = true
		errorInfo.Action = ActionRetryWithBackoff
		
		log.Printf("Connection error: %v", e)
		return errorInfo, ActionRetryWithBackoff

	case *GPTAPIError:
		// Requirement 8.2 - GPT API连接失败时向用户显示错误信息
		errorInfo.Type = ErrorTypeGPTAPI
		errorInfo.Code = e.Code
		errorInfo.Message = e.Message
		errorInfo.Details = fmt.Sprintf("GPT API endpoint: %s", e.Endpoint)
		errorInfo.UserMessage = "AI服务暂时不可用，请稍后重试"
		errorInfo.Recoverable = false
		errorInfo.Action = ActionFailFast
		
		log.Printf("GPT API error: %v", e)
		return errorInfo, ActionFailFast

	case *PermissionError:
		// Requirement 8.3 - 麦克风权限被拒绝时显示权限请求提示
		errorInfo.Type = ErrorTypePermission
		errorInfo.Code = "PERMISSION_DENIED"
		errorInfo.Message = e.Error()
		errorInfo.Details = fmt.Sprintf("Permission: %s, Reason: %s", e.Permission, e.Reason)
		errorInfo.UserMessage = "需要麦克风权限才能进行语音对话，请在浏览器中允许麦克风访问"
		errorInfo.Recoverable = true
		errorInfo.Action = ActionFailFast
		
		log.Printf("Permission error: %v", e)
		return errorInfo, ActionFailFast

	case *AudioPlaybackError:
		// Requirement 8.4 - 音频播放失败时记录错误并继续处理
		errorInfo.Type = ErrorTypeAudioPlayback
		errorInfo.Code = "PLAYBACK_FAILED"
		errorInfo.Message = e.Error()
		errorInfo.Details = e.Details
		errorInfo.UserMessage = "音频播放出现问题，但对话可以继续"
		errorInfo.Recoverable = true
		errorInfo.Action = ActionLogAndContinue
		
		log.Printf("Audio playback error: %v", e)
		return errorInfo, ActionLogAndContinue

	default:
		// 其他未知错误
		errorInfo.Type = ErrorTypeValidation
		errorInfo.Code = "UNKNOWN_ERROR"
		errorInfo.Message = err.Error()
		errorInfo.Details = "Unknown error type"
		errorInfo.UserMessage = "发生了未知错误，请重试"
		errorInfo.Recoverable = true
		errorInfo.Action = ActionLogAndContinue
		
		log.Printf("Unknown error: %v", err)
		return errorInfo, ActionLogAndContinue
	}
}

// HandleWebSocketConnectionError 处理WebSocket连接错误
// Requirements: 8.1 - WebSocket连接断开时尝试自动重连
func (eh *ErrorHandler) HandleWebSocketConnectionError(endpoint string, err error) (*ErrorInfo, bool) {
	eh.mu.Lock()
	defer eh.mu.Unlock()

	// 增加重连尝试次数
	eh.reconnectAttempts[endpoint]++
	attempts := eh.reconnectAttempts[endpoint]

	connErr := &ConnectionError{
		Endpoint: endpoint,
		Reason:   err.Error(),
		Attempts: attempts,
	}

	errorInfo, action := eh.HandleError(connErr)

	// 检查是否超过最大重试次数
	if attempts >= eh.maxRetries {
		log.Printf("Max reconnection attempts reached for %s", endpoint)
		errorInfo.UserMessage = "连接失败，请检查网络连接后重试"
		errorInfo.Recoverable = false
		return errorInfo, false // 不再重试
	}

	// 可以重试
	shouldRetry := action == ActionRetryWithBackoff
	if shouldRetry {
		log.Printf("Will retry connection to %s in %v (attempt %d/%d)", 
			endpoint, eh.retryInterval, attempts, eh.maxRetries)
	}

	return errorInfo, shouldRetry
}

// ResetConnectionAttempts 重置连接尝试次数
func (eh *ErrorHandler) ResetConnectionAttempts(endpoint string) {
	eh.mu.Lock()
	defer eh.mu.Unlock()
	
	delete(eh.reconnectAttempts, endpoint)
	log.Printf("Reset connection attempts for %s", endpoint)
}

// RetryWithBackoff 带退避的重试机制
func (eh *ErrorHandler) RetryWithBackoff(ctx context.Context, operation func() error, maxRetries int) error {
	var lastErr error
	
	for attempt := 1; attempt <= maxRetries; attempt++ {
		select {
		case <-ctx.Done():
			return ctx.Err()
		default:
		}

		err := operation()
		if err == nil {
			return nil // 成功
		}

		lastErr = err
		log.Printf("Operation failed (attempt %d/%d): %v", attempt, maxRetries, err)

		if attempt < maxRetries {
			// 指数退避
			backoffDuration := time.Duration(attempt) * eh.retryInterval
			log.Printf("Retrying in %v...", backoffDuration)
			
			select {
			case <-ctx.Done():
				return ctx.Err()
			case <-time.After(backoffDuration):
				// 继续下一次重试
			}
		}
	}

	return fmt.Errorf("operation failed after %d attempts: %v", maxRetries, lastErr)
}

// HandleGPTAPIError 处理GPT API错误
// Requirements: 8.2 - GPT API连接失败时向用户显示错误信息
func (eh *ErrorHandler) HandleGPTAPIError(endpoint, code, message string) *ErrorInfo {
	gptErr := &GPTAPIError{
		Endpoint: endpoint,
		Code:     code,
		Message:  message,
	}

	errorInfo, _ := eh.HandleError(gptErr)
	return errorInfo
}

// HandlePermissionError 处理权限错误
// Requirements: 8.3 - 麦克风权限被拒绝时显示权限请求提示
func (eh *ErrorHandler) HandlePermissionError(permission, reason string) *ErrorInfo {
	permErr := &PermissionError{
		Permission: permission,
		Reason:     reason,
	}

	errorInfo, _ := eh.HandleError(permErr)
	return errorInfo
}

// HandleAudioPlaybackError 处理音频播放错误
// Requirements: 8.4 - 音频播放失败时记录错误并继续处理
func (eh *ErrorHandler) HandleAudioPlaybackError(reason, details string) *ErrorInfo {
	audioErr := &AudioPlaybackError{
		Reason:  reason,
		Details: details,
	}

	errorInfo, _ := eh.HandleError(audioErr)
	return errorInfo
}

// CreateUserFriendlyMessage 创建用户友好的错误消息
// Requirements: 8.5 - 提供用户友好的错误消息
func (eh *ErrorHandler) CreateUserFriendlyMessage(errorType ErrorType, details string) string {
	switch errorType {
	case ErrorTypeConnection:
		return "网络连接出现问题，正在尝试重新连接..."
	case ErrorTypeGPTAPI:
		return "AI服务暂时不可用，请稍后重试"
	case ErrorTypePermission:
		return "需要麦克风权限才能进行语音对话，请在浏览器中允许麦克风访问"
	case ErrorTypeAudioPlayback:
		return "音频播放出现问题，但对话可以继续"
	case ErrorTypeTimeout:
		return "操作超时，请检查网络连接"
	case ErrorTypeValidation:
		return "数据格式错误，请重试"
	default:
		return "发生了未知错误，请重试"
	}
}

// IsRecoverable 检查错误是否可恢复
func (eh *ErrorHandler) IsRecoverable(err error) bool {
	errorInfo, _ := eh.HandleError(err)
	if errorInfo == nil {
		return true
	}
	return errorInfo.Recoverable
}

// SetMaxRetries 设置最大重试次数
func (eh *ErrorHandler) SetMaxRetries(maxRetries int) {
	eh.mu.Lock()
	defer eh.mu.Unlock()
	eh.maxRetries = maxRetries
}

// SetRetryInterval 设置重试间隔
func (eh *ErrorHandler) SetRetryInterval(interval time.Duration) {
	eh.mu.Lock()
	defer eh.mu.Unlock()
	eh.retryInterval = interval
}

// GetConnectionAttempts 获取连接尝试次数
func (eh *ErrorHandler) GetConnectionAttempts(endpoint string) int {
	eh.mu.RLock()
	defer eh.mu.RUnlock()
	return eh.reconnectAttempts[endpoint]
}

// EnableCircuitBreaker 启用熔断器
func (eh *ErrorHandler) EnableCircuitBreaker() {
	eh.mu.Lock()
	defer eh.mu.Unlock()
	eh.circuitBreaker = true
	log.Println("Circuit breaker enabled")
}

// DisableCircuitBreaker 禁用熔断器
func (eh *ErrorHandler) DisableCircuitBreaker() {
	eh.mu.Lock()
	defer eh.mu.Unlock()
	eh.circuitBreaker = false
	log.Println("Circuit breaker disabled")
}

// IsCircuitBreakerOpen 检查熔断器是否开启
func (eh *ErrorHandler) IsCircuitBreakerOpen() bool {
	eh.mu.RLock()
	defer eh.mu.RUnlock()
	return eh.circuitBreaker
}

// RegisterErrorCallback 注册错误回调函数
func (eh *ErrorHandler) RegisterErrorCallback(errorType string, callback func()) {
	eh.mu.Lock()
	defer eh.mu.Unlock()
	eh.errorCallbacks[errorType] = callback
}

// TriggerErrorCallback 触发错误回调
func (eh *ErrorHandler) TriggerErrorCallback(errorType string) {
	eh.mu.RLock()
	callback, exists := eh.errorCallbacks[errorType]
	eh.mu.RUnlock()

	if exists && callback != nil {
		go callback() // 异步执行回调
	}
}

// LogError 记录错误信息
func (eh *ErrorHandler) LogError(errorInfo *ErrorInfo) {
	log.Printf("Error [%s:%s]: %s - %s (User: %s, Recoverable: %t)", 
		errorInfo.Type, errorInfo.Code, errorInfo.Message, errorInfo.Details, 
		errorInfo.UserMessage, errorInfo.Recoverable)
}

// CreateWebSocketReconnector 创建WebSocket重连器
func (eh *ErrorHandler) CreateWebSocketReconnector(
	ctx context.Context,
	connectFunc func() (*websocket.Conn, error),
	onReconnect func(*websocket.Conn),
) {
	go func() {
		for {
			select {
			case <-ctx.Done():
				return
			default:
			}

			conn, err := connectFunc()
			if err != nil {
				errorInfo, shouldRetry := eh.HandleWebSocketConnectionError("websocket", err)
				eh.LogError(errorInfo)

				if !shouldRetry {
					log.Println("Stopping reconnection attempts")
					return
				}

				// 等待重试间隔
				select {
				case <-ctx.Done():
					return
				case <-time.After(eh.retryInterval):
					continue
				}
			} else {
				// 连接成功，重置尝试次数
				eh.ResetConnectionAttempts("websocket")
				log.Println("WebSocket reconnection successful")
				
				if onReconnect != nil {
					onReconnect(conn)
				}
				return
			}
		}
	}()
}
// Frontend error handling utility for GPT Realtime WebRTC
// Requirements: 8.3 - 麦克风权限被拒绝时显示权限请求提示

// 全局AudioContext用于音频播放，避免重复创建导致的卡顿
let globalAudioContext: AudioContext | null = null
// 音频播放队列管理
let audioPlaybackQueue: Promise<void> = Promise.resolve()
let currentAudioSource: AudioBufferSourceNode | null = null

export interface ErrorInfo {
  type: ErrorType
  code: string
  message: string
  userMessage: string
  recoverable: boolean
  timestamp: Date
}

export enum ErrorType {
  CONNECTION = 'connection_error',
  PERMISSION = 'permission_error',
  AUDIO_PLAYBACK = 'audio_playback_error',
  WEBSOCKET = 'websocket_error',
  MICROPHONE = 'microphone_error',
  NETWORK = 'network_error'
}

export class FrontendErrorHandler {
  private static instance: FrontendErrorHandler
  private errorCallbacks: Map<ErrorType, ((error: ErrorInfo) => void)[]> = new Map()

  private constructor() {}

  public static getInstance(): FrontendErrorHandler {
    if (!FrontendErrorHandler.instance) {
      FrontendErrorHandler.instance = new FrontendErrorHandler()
    }
    return FrontendErrorHandler.instance
  }

  // Handle microphone permission errors
  // Requirements: 8.3 - 麦克风权限被拒绝时显示权限请求提示
  public handleMicrophonePermissionError(error: DOMException): ErrorInfo {
    let userMessage = ''
    let code = 'PERMISSION_DENIED'

    switch (error.name) {
      case 'NotAllowedError':
        userMessage = '需要麦克风权限才能进行语音对话。请点击浏览器地址栏的麦克风图标，选择"允许"，然后刷新页面重试。'
        code = 'MICROPHONE_PERMISSION_DENIED'
        break
      case 'NotFoundError':
        userMessage = '未找到麦克风设备。请确保您的设备已连接麦克风并重试。'
        code = 'MICROPHONE_NOT_FOUND'
        break
      case 'NotReadableError':
        userMessage = '无法访问麦克风，可能被其他应用程序占用。请关闭其他使用麦克风的应用程序后重试。'
        code = 'MICROPHONE_NOT_READABLE'
        break
      case 'OverconstrainedError':
        userMessage = '麦克风不支持所需的音频格式。请尝试使用其他麦克风设备。'
        code = 'MICROPHONE_OVERCONSTRAINED'
        break
      case 'SecurityError':
        userMessage = '由于安全限制无法访问麦克风。请确保您在安全的HTTPS环境中使用此功能。'
        code = 'MICROPHONE_SECURITY_ERROR'
        break
      default:
        userMessage = '麦克风访问失败，请检查设备设置后重试。'
        code = 'MICROPHONE_UNKNOWN_ERROR'
    }

    const errorInfo: ErrorInfo = {
      type: ErrorType.PERMISSION,
      code,
      message: error.message,
      userMessage,
      recoverable: error.name === 'NotAllowedError', // 权限错误通常可以通过用户操作恢复
      timestamp: new Date()
    }

    this.logError(errorInfo)
    this.triggerCallbacks(ErrorType.PERMISSION, errorInfo)
    
    return errorInfo
  }

  // Handle audio playback errors
  // Requirements: 8.4 - 音频播放失败时记录错误并继续处理
  public handleAudioPlaybackError(error: Error, details?: string): ErrorInfo {
    const errorInfo: ErrorInfo = {
      type: ErrorType.AUDIO_PLAYBACK,
      code: 'AUDIO_PLAYBACK_FAILED',
      message: error.message,
      userMessage: '音频播放出现问题，但对话可以继续。如果问题持续，请检查您的音频设备设置。',
      recoverable: true, // 音频播放错误通常不影响整体功能
      timestamp: new Date()
    }

    if (details) {
      console.debug('Audio playback error details:', details)
    }

    this.logError(errorInfo)
    this.triggerCallbacks(ErrorType.AUDIO_PLAYBACK, errorInfo)
    
    return errorInfo
  }

  // Handle WebSocket connection errors
  // Requirements: 8.1 - WebSocket连接断开时尝试自动重连
  public handleWebSocketError(error: Event | Error, endpoint?: string): ErrorInfo {
    let message = 'WebSocket connection error'
    let userMessage = '网络连接出现问题，正在尝试重新连接...'
    
    if (error instanceof Error) {
      message = error.message
    } else if (error.type) {
      message = `WebSocket ${error.type} event`
    }

    const errorInfo: ErrorInfo = {
      type: ErrorType.WEBSOCKET,
      code: 'WEBSOCKET_CONNECTION_ERROR',
      message,
      userMessage,
      recoverable: true, // WebSocket错误通常可以通过重连恢复
      timestamp: new Date()
    }

    if (endpoint) {
      console.debug('WebSocket error endpoint:', endpoint)
    }

    this.logError(errorInfo)
    this.triggerCallbacks(ErrorType.WEBSOCKET, errorInfo)
    
    return errorInfo
  }

  // Handle network errors
  public handleNetworkError(error: Error): ErrorInfo {
    const errorInfo: ErrorInfo = {
      type: ErrorType.NETWORK,
      code: 'NETWORK_ERROR',
      message: error.message,
      userMessage: '网络连接不稳定，请检查您的网络连接后重试。',
      recoverable: true,
      timestamp: new Date()
    }

    this.logError(errorInfo)
    this.triggerCallbacks(ErrorType.NETWORK, errorInfo)
    
    return errorInfo
  }

  // Create user-friendly error messages
  // Requirements: 8.5 - 提供用户友好的错误消息
  public createUserFriendlyMessage(errorType: ErrorType, originalMessage?: string): string {
    switch (errorType) {
      case ErrorType.CONNECTION:
        return '网络连接出现问题，正在尝试重新连接...'
      case ErrorType.PERMISSION:
        return '需要麦克风权限才能进行语音对话，请在浏览器中允许麦克风访问'
      case ErrorType.AUDIO_PLAYBACK:
        return '音频播放出现问题，但对话可以继续'
      case ErrorType.WEBSOCKET:
        return '连接已断开，正在尝试重新连接...'
      case ErrorType.MICROPHONE:
        return '麦克风访问失败，请检查设备设置'
      case ErrorType.NETWORK:
        return '网络连接不稳定，请检查您的网络连接'
      default:
        return originalMessage || '发生了未知错误，请重试'
    }
  }

  // Register error callback
  public onError(errorType: ErrorType, callback: (error: ErrorInfo) => void): void {
    if (!this.errorCallbacks.has(errorType)) {
      this.errorCallbacks.set(errorType, [])
    }
    this.errorCallbacks.get(errorType)!.push(callback)
  }

  // Remove error callback
  public offError(errorType: ErrorType, callback: (error: ErrorInfo) => void): void {
    const callbacks = this.errorCallbacks.get(errorType)
    if (callbacks) {
      const index = callbacks.indexOf(callback)
      if (index > -1) {
        callbacks.splice(index, 1)
      }
    }
  }

  // Trigger error callbacks
  private triggerCallbacks(errorType: ErrorType, errorInfo: ErrorInfo): void {
    const callbacks = this.errorCallbacks.get(errorType)
    if (callbacks) {
      callbacks.forEach(callback => {
        try {
          callback(errorInfo)
        } catch (err) {
          console.error('Error in error callback:', err)
        }
      })
    }
  }

  // Log error information
  private logError(errorInfo: ErrorInfo): void {
    console.error(`[${errorInfo.type}:${errorInfo.code}] ${errorInfo.message}`)
    console.error(`User message: ${errorInfo.userMessage}`)
    console.error(`Recoverable: ${errorInfo.recoverable}`)
    console.error(`Timestamp: ${errorInfo.timestamp.toISOString()}`)
  }

  // Check if error is recoverable
  public isRecoverable(errorInfo: ErrorInfo): boolean {
    return errorInfo.recoverable
  }

  // Show permission request dialog
  public showPermissionRequestDialog(): void {
    const message = `
      语音对话功能需要访问您的麦克风。
      
      请按照以下步骤启用麦克风权限：
      1. 点击浏览器地址栏左侧的锁形图标或麦克风图标
      2. 选择"允许"麦克风访问
      3. 刷新页面重试
      
      如果仍然无法使用，请检查您的浏览器设置中是否允许此网站访问麦克风。
    `
    
    alert(message)
  }

  // Retry mechanism for recoverable errors
  public async retryOperation<T>(
    operation: () => Promise<T>,
    maxRetries: number = 3,
    delay: number = 1000
  ): Promise<T> {
    let lastError: Error
    
    for (let attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        return await operation()
      } catch (error) {
        lastError = error as Error
        console.warn(`Operation failed (attempt ${attempt}/${maxRetries}):`, error)
        
        if (attempt < maxRetries) {
          await new Promise(resolve => setTimeout(resolve, delay * attempt))
        }
      }
    }
    
    throw lastError!
  }
}

// Export singleton instance
export const errorHandler = FrontendErrorHandler.getInstance()

// Utility functions for common error scenarios
export const handleMicrophonePermission = async (): Promise<MediaStream> => {
  try {
    const stream = await navigator.mediaDevices.getUserMedia({
      audio: {
        sampleRate: 24000,  // 更新为24kHz以匹配GPT要求
        channelCount: 1,
        echoCancellation: true,
        noiseSuppression: true,
        autoGainControl: true
      }
    })
    return stream
  } catch (error) {
    const errorInfo = errorHandler.handleMicrophonePermissionError(error as DOMException)
    
    if (errorInfo.code === 'MICROPHONE_PERMISSION_DENIED') {
      errorHandler.showPermissionRequestDialog()
    }
    
    throw error
  }
}

export const handleAudioPlayback = async (audioData: string): Promise<void> => {
  // 将音频播放加入队列，避免重叠播放
  audioPlaybackQueue = audioPlaybackQueue.then(async () => {
    try {
      // 停止当前播放的音频（如果有）
      if (currentAudioSource) {
        currentAudioSource.stop()
        currentAudioSource = null
      }
      
      // Decode base64 audio data
      const binaryData = atob(audioData)
      const arrayBuffer = new ArrayBuffer(binaryData.length)
      const uint8Array = new Uint8Array(arrayBuffer)
      
      for (let i = 0; i < binaryData.length; i++) {
        uint8Array[i] = binaryData.charCodeAt(i)
      }

      // 使用全局AudioContext避免重复创建
      if (!globalAudioContext) {
        globalAudioContext = new (window.AudioContext || (window as any).webkitAudioContext)({
          sampleRate: 24000 // GPT uses 24kHz
        })
      }
      
      // 确保AudioContext处于运行状态
      if (globalAudioContext.state === 'suspended') {
        await globalAudioContext.resume()
      }
      
      // Convert PCM16 bytes to Float32 samples
      const pcm16Data = new Int16Array(arrayBuffer)
      const originalSampleCount = pcm16Data.length
      
      if (originalSampleCount === 0) {
        console.warn('Empty audio data received, skipping playback')
        return
      }
      
      // 添加静音填充以减少爆破音（开头和结尾各添加240个样本，约10ms）
      const paddingSamples = 240 // 10ms at 24kHz
      const totalSampleCount = originalSampleCount + (paddingSamples * 2)
      const audioBuffer = globalAudioContext.createBuffer(1, totalSampleCount, 24000) // mono, 24kHz
      const channelData = audioBuffer.getChannelData(0)
      
      // 开头静音填充
      for (let i = 0; i < paddingSamples; i++) {
        channelData[i] = 0
      }
      
      // Convert PCM16 to Float32 (-1 to 1 range) with better precision
      for (let i = 0; i < originalSampleCount; i++) {
        channelData[i + paddingSamples] = Math.max(-1, Math.min(1, pcm16Data[i] / 32768.0))
      }
      
      // 结尾静音填充
      for (let i = originalSampleCount + paddingSamples; i < totalSampleCount; i++) {
        channelData[i] = 0
      }
      
      // 创建音频源并播放
      const source = globalAudioContext.createBufferSource()
      source.buffer = audioBuffer
      currentAudioSource = source
      
      // 添加音量控制和低通滤波器减少噪音
      const gainNode = globalAudioContext.createGain()
      const filterNode = globalAudioContext.createBiquadFilter()
      
      gainNode.gain.value = 0.7 // 适中的音量
      filterNode.type = 'lowpass'
      filterNode.frequency.value = 8000 // 8kHz低通滤波，去除高频噪音
      filterNode.Q.value = 1
      
      // 添加淡入淡出效果避免爆破音
      const fadeTime = 0.01 // 10ms淡入淡出
      const currentTime = globalAudioContext.currentTime
      
      // 淡入效果
      gainNode.gain.setValueAtTime(0, currentTime)
      gainNode.gain.linearRampToValueAtTime(0.7, currentTime + fadeTime)
      
      // 淡出效果（在音频结束前）
      const audioEndTime = currentTime + audioBuffer.duration
      gainNode.gain.setValueAtTime(0.7, audioEndTime - fadeTime)
      gainNode.gain.linearRampToValueAtTime(0, audioEndTime)
      
      source.connect(filterNode)
      filterNode.connect(gainNode)
      gainNode.connect(globalAudioContext.destination)
      
      // 返回Promise以便等待播放完成
      return new Promise<void>((resolve, reject) => {
        source.onended = () => {
          console.log(`✓ GPT audio playback completed: ${audioBuffer.duration.toFixed(2)}s`)
          currentAudioSource = null
          resolve()
        }
        
        try {
          source.start()
          console.log(`🔊 Playing GPT audio: ${originalSampleCount} samples (${totalSampleCount} with padding), ${audioBuffer.duration.toFixed(2)}s`)
          
          // 设置超时以防音频卡住
          setTimeout(() => {
            if (currentAudioSource === source) {
              console.warn('Audio playback timeout, stopping source')
              try {
                source.stop()
              } catch (e) {
                console.warn('Error stopping timed out audio source:', e)
              }
              currentAudioSource = null
              resolve()
            }
          }, audioBuffer.duration * 1000 + 1000) // 音频时长 + 1秒缓冲
          
        } catch (error) {
          console.error('Failed to start audio source:', error)
          currentAudioSource = null
          reject(error)
        }
      })
      
    } catch (error) {
      errorHandler.handleAudioPlaybackError(error as Error, `Failed to play PCM16 audio data of length ${audioData.length}`)
      throw error
    }
  })
  
  return audioPlaybackQueue
}

// 清理音频资源
export const cleanupAudioResources = (): void => {
  if (currentAudioSource) {
    try {
      currentAudioSource.stop()
    } catch (error) {
      console.warn('Error stopping current audio source:', error)
    }
    currentAudioSource = null
  }
  
  if (globalAudioContext && globalAudioContext.state !== 'closed') {
    try {
      globalAudioContext.close()
    } catch (error) {
      console.warn('Error closing global audio context:', error)
    }
    globalAudioContext = null
  }
  
  // 重置播放队列
  audioPlaybackQueue = Promise.resolve()
}
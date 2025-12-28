import { useState, useEffect, useRef, useCallback } from 'react'
import { useAuth } from '../contexts/AuthContext'
import { Mic, MicOff, Wifi, WifiOff, AlertCircle, Volume2, Activity } from 'lucide-react'
import { RealtimeMessage, WebSocketMessage, AudioConfig } from '../types'
import { errorHandler, ErrorType, handleMicrophonePermission, handleAudioPlayback } from '../utils/errorHandler'

const AUDIO_CONFIG: AudioConfig = {
  sampleRate: 24000,  // GPT Realtime API要求24kHz
  channelCount: 1,
  echoCancellation: true,
  noiseSuppression: true,
  autoGainControl: true
}

// Audio processing constants for better real-time performance
const AUDIO_CHUNK_SIZE = 100 // ms

export default function RealtimeChat() {
  const { token } = useAuth()
  const [messages, setMessages] = useState<RealtimeMessage[]>([])
  const [isConnected, setIsConnected] = useState(false)
  const [isListening, setIsListening] = useState(false)
  const [isProcessing, setIsProcessing] = useState(false)
  const [error, setError] = useState('')
  const [audioLevel, setAudioLevel] = useState(0)
  const [connectionQuality, setConnectionQuality] = useState<'good' | 'fair' | 'poor'>('good')
  const [isAudioPlaying, setIsAudioPlaying] = useState(false)
  const [reconnectAttempts, setReconnectAttempts] = useState(0)

  // Refs for WebSocket and audio components
  const websocketRef = useRef<WebSocket | null>(null)
  const mediaRecorderRef = useRef<MediaRecorder | null>(null)
  const audioContextRef = useRef<AudioContext | null>(null)
  const analyserRef = useRef<AnalyserNode | null>(null)
  const audioStreamRef = useRef<MediaStream | null>(null)
  const messagesContainerRef = useRef<HTMLDivElement>(null)
  const animationFrameRef = useRef<number>()
  const reconnectTimeoutRef = useRef<number>()
  const audioVisualizationRef = useRef<HTMLCanvasElement>(null)
  const audioChunksRef = useRef<{rawAudioData?: Float32Array[], isProcessing?: boolean, scriptProcessor?: ScriptProcessorNode}>({}) // 用于累积原始音频数据

  // WebSocket connection with enhanced error handling and reconnection
  const connectWebSocket = useCallback(() => {
    if (!token) {
      setError('请先登录后再使用语音功能')
      setIsConnected(false)
      return
    }

    // Clean up existing connection
    if (websocketRef.current) {
      websocketRef.current.close()
    }

    const wsUrl = `ws://localhost:3000/api/v1/realtime/chat?token=${token}`
    const ws = new WebSocket(wsUrl)
    websocketRef.current = ws

    // Connection timeout
    const connectionTimeout = setTimeout(() => {
      if (ws.readyState === WebSocket.CONNECTING) {
        ws.close()
        setError('连接超时，请检查网络连接')
      }
    }, 10000)

    ws.onopen = () => {
      clearTimeout(connectionTimeout)
      setIsConnected(true)
      setError('')
      setReconnectAttempts(0)
      setConnectionQuality('good')
      console.log('WebSocket connected')
      
      // Send initial configuration
      ws.send(JSON.stringify({
        type: 'configure_session',
        config: {
          audio_format: 'pcm16',
          sample_rate: AUDIO_CONFIG.sampleRate,  // 24000
          channels: AUDIO_CONFIG.channelCount
        }
      }))
    }

    ws.onmessage = (event) => {
      try {
        const data: WebSocketMessage = JSON.parse(event.data)
        handleWebSocketMessage(data)
        
        // Update connection quality based on message frequency
        setConnectionQuality('good')
      } catch (err) {
        console.error('Failed to parse WebSocket message:', err)
        setConnectionQuality('poor')
      }
    }

    ws.onclose = (event) => {
      clearTimeout(connectionTimeout)
      setIsConnected(false)
      console.log('WebSocket disconnected:', event.code, event.reason)
      
      // Handle different close codes
      if (event.code === 1006) {
        setError('网络连接出现问题，正在尝试重新连接...')
      } else if (event.code === 1011) {
        setError('服务器内部错误，请稍后重试')
      } else if (event.code === 1008) {
        setError('认证失败，请重新登录')
        return // Don't attempt reconnection for auth failures
      }
      
      // Attempt reconnection if not a clean close
      if (event.code !== 1000 && reconnectAttempts < 5) {
        const delay = Math.min(1000 * Math.pow(2, reconnectAttempts), 30000)
        setReconnectAttempts(prev => prev + 1)
        
        reconnectTimeoutRef.current = setTimeout(() => {
          console.log(`Attempting reconnection (${reconnectAttempts + 1}/5)`)
          connectWebSocket()
        }, delay)
      }
    }

    ws.onerror = (err) => {
      clearTimeout(connectionTimeout)
      const errorInfo = errorHandler.handleWebSocketError(err, wsUrl)
      setError(errorInfo.userMessage)
      setConnectionQuality('poor')
      console.error('WebSocket error:', err)
    }
  }, [token, reconnectAttempts])

  // Enhanced WebSocket message handling
  const handleWebSocketMessage = useCallback((data: WebSocketMessage) => {
    switch (data.type) {
      case 'connection_established':
        console.log('WebSocket connection established:', data)
        // Connection is ready, no additional action needed
        break
        
      case 'text_response':
        if (data.text) {
          addMessage('assistant', data.text)
        }
        break
        
      case 'audio_response':
        if (data.audio) {
          playAudioResponse(data.audio)
        }
        break
        
      case 'response_complete':
        setIsProcessing(false)
        break
        
      case 'session_configured':
        console.log('Session configured successfully')
        break
        
      case 'connection_quality':
        if (data.data?.quality) {
          setConnectionQuality(data.data.quality)
        }
        break
        
      case 'error':
        setError('处理错误: ' + JSON.stringify(data.error))
        setIsProcessing(false)
        break
        
      case 'echo':
        console.log('Echo response received:', data)
        break
        
      default:
        console.log('Unknown message type:', data.type, data)
    }
  }, [])

  // Enhanced audio response playback with visual feedback
  const playAudioResponse = useCallback(async (audioData: string) => {
    try {
      setIsAudioPlaying(true)
      await handleAudioPlayback(audioData)
    } catch (err) {
      console.error('Failed to play audio response:', err)
    } finally {
      setIsAudioPlaying(false)
    }
  }, [])

  // 发送原始音频数据到GPT
  const sendRawAudioToGPT = useCallback((audioData: Float32Array) => {
    if (!websocketRef.current || websocketRef.current.readyState !== WebSocket.OPEN) return

    try {
      console.log(`Processing raw audio data: ${audioData.length} samples, ${(audioData.length / 24000).toFixed(2)}s`)
      
      // 直接转换为PCM16
      const pcm16Data = new Int16Array(audioData.length)
      for (let i = 0; i < audioData.length; i++) {
        const sample = Math.max(-1, Math.min(1, audioData[i]))
        pcm16Data[i] = Math.round(sample * 32767)
      }
      
      // 转换为字节数组
      const bytes = new Uint8Array(pcm16Data.length * 2)
      for (let i = 0; i < pcm16Data.length; i++) {
        const value = pcm16Data[i]
        bytes[i * 2] = value & 0xFF
        bytes[i * 2 + 1] = (value >> 8) & 0xFF
      }
      
      console.log(`Converted raw audio to PCM16: ${bytes.length} bytes`)
      
      // 编码为base64
      const blob = new Blob([bytes])
      const reader = new FileReader()
      
      reader.onload = function() {
        const result = reader.result
        if (typeof result === 'string') {
          const base64Audio = result.split(',')[1]
          
          // 发送到GPT API
          websocketRef.current?.send(JSON.stringify({
            type: 'audio_data',
            audio: base64Audio,
            format: 'pcm16',
            timestamp: Date.now()
          }))
          
          console.log(`Sent raw audio: ${base64Audio.length} chars, ${(audioData.length / 24000).toFixed(2)}s`)
        }
      }
      
      reader.onerror = function() {
        console.error('FileReader encoding failed for raw audio')
      }
      
      reader.readAsDataURL(blob)
      
    } catch (err) {
      console.error('Failed to process raw audio data:', err)
    }
  }, [])

  // Enhanced recording with better WebRTC integration
  const startListening = useCallback(async () => {
    try {
      // Use error handler for microphone permission
      const stream = await handleMicrophonePermission()
      audioStreamRef.current = stream

      // Set up enhanced audio context with better processing
      audioContextRef.current = new AudioContext({ 
        sampleRate: AUDIO_CONFIG.sampleRate,
        latencyHint: 'interactive'
      })
      
      // 确保AudioContext处于运行状态 - 需要用户交互
      if (audioContextRef.current.state === 'suspended') {
        console.log('AudioContext is suspended, attempting to resume...')
        await audioContextRef.current.resume()
        console.log('AudioContext resumed, state:', audioContextRef.current.state)
      }
      
      // 如果仍然是suspended，可能需要用户交互
      if (audioContextRef.current.state === 'suspended') {
        console.warn('AudioContext still suspended after resume attempt. This may require user interaction.')
        // 尝试通过播放静音来激活AudioContext
        const oscillator = audioContextRef.current.createOscillator()
        const gainNode = audioContextRef.current.createGain()
        gainNode.gain.value = 0 // 静音
        oscillator.connect(gainNode)
        gainNode.connect(audioContextRef.current.destination)
        oscillator.start()
        oscillator.stop(audioContextRef.current.currentTime + 0.1)
        
        // 再次尝试resume
        await audioContextRef.current.resume()
        console.log('AudioContext state after silent activation:', audioContextRef.current.state)
      }
      
      const source = audioContextRef.current.createMediaStreamSource(stream)
      analyserRef.current = audioContextRef.current.createAnalyser()
      analyserRef.current.fftSize = 2048
      analyserRef.current.smoothingTimeConstant = 0.8
      
      // Create gain node for volume control
      const gainNode = audioContextRef.current.createGain()
      gainNode.gain.value = 1.0
      
      // 使用ScriptProcessor进行实时音频处理
      const scriptProcessor = audioContextRef.current.createScriptProcessor(4096, 1, 1)
      audioChunksRef.current.scriptProcessor = scriptProcessor
      
      // 简化音频连接链：source → scriptProcessor → destination
      // 同时保持analyser用于可视化：source → analyser
      source.connect(scriptProcessor)
      source.connect(analyserRef.current) // 用于可视化
      scriptProcessor.connect(audioContextRef.current.destination)
      
      console.log('Audio processing chain connected: source → scriptProcessor → destination')
      console.log('Audio visualization chain: source → analyser')
      console.log('AudioContext state:', audioContextRef.current.state)
      console.log('AudioContext sample rate:', audioContextRef.current.sampleRate)
      console.log('ScriptProcessor created with buffer size:', scriptProcessor.bufferSize)

      // Start enhanced audio level monitoring and visualization
      startAudioVisualization()

      // Set up MediaRecorder for continuous streaming
      let mimeType = 'audio/webm'
      
      // 优先使用最兼容的格式
      const preferredFormats = [
        'audio/webm',
        'audio/mp4',
        'audio/ogg'
      ]
      
      for (const format of preferredFormats) {
        if (MediaRecorder.isTypeSupported(format)) {
          mimeType = format
          console.log('Using MediaRecorder format:', format)
          break
        }
      }
      
      const mediaRecorder = new MediaRecorder(stream, {
        mimeType,
        audioBitsPerSecond: 24000 // 降低比特率，减少数据量
      })
      mediaRecorderRef.current = mediaRecorder

      // 持续监听模式：使用Web Audio API直接处理原始音频数据
      mediaRecorder.ondataavailable = (event) => {
        if (event.data.size > 0) {
          // 不再使用MediaRecorder的数据，改用Web Audio API
          console.log(`MediaRecorder data available: ${event.data.size} bytes (ignored)`)
        }
      }
      
      // 设置监听状态为true，确保ScriptProcessor回调能正常工作
      setIsListening(true)
      audioChunksRef.current.isProcessing = true
      
      // 添加更多调试信息
      let processCount = 0
      
      scriptProcessor.onaudioprocess = (event) => {
        processCount++
        
        if (processCount === 1) {
          console.log('🎵 ScriptProcessor first call - audio processing started!')
          console.log('Event details:', {
            inputBuffer: event.inputBuffer,
            outputBuffer: event.outputBuffer,
            playbackTime: event.playbackTime
          })
        }
        
        // 使用ref标志而不是React状态，避免闭包问题
        if (!audioChunksRef.current.isProcessing) {
          if (processCount % 100 === 0) { // 每100次打印一次，避免日志过多
            console.log(`ScriptProcessor called but processing disabled (call #${processCount})`)
          }
          return
        }
        
        const inputBuffer = event.inputBuffer
        const inputData = inputBuffer.getChannelData(0)
        
        if (processCount % 50 === 0) { // 每50次打印一次处理日志
          console.log(`ScriptProcessor processing: ${inputData.length} samples (call #${processCount})`)
        }
        
        // 检查音频数据是否有内容
        let hasAudio = false
        for (let i = 0; i < inputData.length; i++) {
          if (Math.abs(inputData[i]) > 0.001) { // 检查是否有明显的音频信号
            hasAudio = true
            break
          }
        }
        
        if (hasAudio && processCount % 10 === 0) {
          console.log(`🔊 Audio detected in samples (call #${processCount})`)
        }
        
        // 累积原始音频数据
        if (!audioChunksRef.current.rawAudioData) {
          audioChunksRef.current.rawAudioData = []
        }
        
        // 复制音频数据
        const audioChunk = new Float32Array(inputData.length)
        audioChunk.set(inputData)
        audioChunksRef.current.rawAudioData.push(audioChunk)
        
        // 计算累积的样本数（约1秒的音频数据 = 24000样本）
        const totalSamples = audioChunksRef.current.rawAudioData.reduce((sum, chunk) => sum + chunk.length, 0)
        
        if (totalSamples >= 24000) { // 约1秒的24kHz音频
          console.log(`🎯 Processing raw audio: ${audioChunksRef.current.rawAudioData.length} chunks, ${totalSamples} samples`)
          
          // 合并所有音频数据
          const combinedData = new Float32Array(totalSamples)
          let offset = 0
          for (const chunk of audioChunksRef.current.rawAudioData) {
            combinedData.set(chunk, offset)
            offset += chunk.length
          }
          
          // 清空累积数据
          audioChunksRef.current.rawAudioData = []
          
          // 直接处理音频数据
          sendRawAudioToGPT(combinedData)
        }
      }
      
      // 确保AudioContext处于运行状态
      if (audioContextRef.current.state === 'suspended') {
        console.log('AudioContext is suspended, attempting to resume...')
        await audioContextRef.current.resume()
        console.log('AudioContext resumed, state:', audioContextRef.current.state)
      }
      
      // 验证音频连接
      console.log('Audio nodes connected:')
      console.log('- Source node:', source)
      console.log('- Gain node:', gainNode)
      console.log('- ScriptProcessor:', scriptProcessor)
      console.log('- Analyser:', analyserRef.current)
      console.log('- Destination:', audioContextRef.current.destination)
      
      // 测试音频流是否活跃
      const tracks = stream.getTracks()
      console.log('Media stream tracks:', tracks.map(track => ({
        kind: track.kind,
        enabled: track.enabled,
        readyState: track.readyState,
        muted: track.muted
      })))

      mediaRecorder.onstop = () => {
        console.log('监听已停止')
      }

      // 开始持续录制，每100ms发送一次数据
      mediaRecorder.start(AUDIO_CHUNK_SIZE) // Send data every 100ms for real-time processing
      setError('') // Clear any previous errors
      
      addMessage('user', '开始监听...')
    } catch (err) {
      console.error('Failed to start listening:', err)
      
      // Handle specific microphone permission errors
      if (err instanceof DOMException) {
        const errorInfo = errorHandler.handleMicrophonePermissionError(err)
        setError(errorInfo.userMessage)
      } else {
        setError('无法开始监听，请检查麦克风权限和设备连接')
      }
    }
  }, [])

  // Enhanced stop listening with cleanup
  const stopListening = useCallback(() => {
    // 停止音频处理
    audioChunksRef.current.isProcessing = false
    
    if (mediaRecorderRef.current && mediaRecorderRef.current.state === 'recording') {
      mediaRecorderRef.current.stop()
    }
    
    // 断开ScriptProcessor连接
    if (audioChunksRef.current.scriptProcessor) {
      audioChunksRef.current.scriptProcessor.disconnect()
      audioChunksRef.current.scriptProcessor = undefined
    }
    
    // 处理剩余的原始音频数据
    setTimeout(() => {
      if (audioChunksRef.current.rawAudioData && audioChunksRef.current.rawAudioData.length > 0) {
        console.log(`Processing remaining raw audio chunks: ${audioChunksRef.current.rawAudioData.length}`)
        
        // 合并剩余的音频数据
        const totalSamples = audioChunksRef.current.rawAudioData.reduce((sum, chunk) => sum + chunk.length, 0)
        const combinedData = new Float32Array(totalSamples)
        let offset = 0
        for (const chunk of audioChunksRef.current.rawAudioData) {
          combinedData.set(chunk, offset)
          offset += chunk.length
        }
        
        // 清空并处理
        audioChunksRef.current.rawAudioData = []
        sendRawAudioToGPT(combinedData)
      }
    }, 200)
    
    if (audioStreamRef.current) {
      audioStreamRef.current.getTracks().forEach(track => track.stop())
      audioStreamRef.current = null
    }
    
    if (audioContextRef.current && audioContextRef.current.state !== 'closed') {
      audioContextRef.current.close()
      audioContextRef.current = null
    }
    
    if (animationFrameRef.current) {
      cancelAnimationFrame(animationFrameRef.current)
    }
    
    setIsListening(false)
    setAudioLevel(0)
    
    addMessage('user', '停止监听')
  }, [sendRawAudioToGPT])

  // Toggle listening
  const toggleListening = useCallback(async () => {
    if (isListening) {
      stopListening()
    } else {
      await startListening()
    }
  }, [isListening, startListening, stopListening])

  // Enhanced audio chunk processing - no longer used in continuous listening mode
  // Audio processing moved to processAudioChunkRealtime

  // Enhanced audio visualization with canvas-based waveform
  const startAudioVisualization = useCallback(() => {
    if (!analyserRef.current || !audioVisualizationRef.current) return

    const canvas = audioVisualizationRef.current
    const canvasContext = canvas.getContext('2d')
    if (!canvasContext) return

    const dataArray = new Uint8Array(analyserRef.current.frequencyBinCount)
    const bufferLength = analyserRef.current.frequencyBinCount
    
    const draw = () => {
      if (!isListening || !analyserRef.current) return
      
      analyserRef.current.getByteFrequencyData(dataArray)
      
      // Calculate audio level
      const average = dataArray.reduce((a, b) => a + b) / dataArray.length
      setAudioLevel((average / 255) * 100)
      
      // Draw waveform visualization
      canvasContext.fillStyle = 'rgb(240, 240, 240)'
      canvasContext.fillRect(0, 0, canvas.width, canvas.height)
      
      canvasContext.lineWidth = 2
      canvasContext.strokeStyle = 'rgb(59, 130, 246)' // Blue color
      canvasContext.beginPath()
      
      const sliceWidth = canvas.width / bufferLength
      let x = 0
      
      for (let i = 0; i < bufferLength; i++) {
        const v = dataArray[i] / 128.0
        const y = v * canvas.height / 2
        
        if (i === 0) {
          canvasContext.moveTo(x, y)
        } else {
          canvasContext.lineTo(x, y)
        }
        
        x += sliceWidth
      }
      
      canvasContext.lineTo(canvas.width, canvas.height / 2)
      canvasContext.stroke()
      
      animationFrameRef.current = requestAnimationFrame(draw)
    }
    
    draw()
  }, [isListening])

  // Enhanced message handling with better timestamps and metadata
  const addMessage = useCallback((type: 'user' | 'assistant', text: string, metadata?: any) => {
    const newMessage: RealtimeMessage = {
      id: Date.now().toString(),
      type,
      text,
      timestamp: new Date(),
      ...metadata
    }
    
    setMessages(prev => [...prev, newMessage])
    
    // Auto-scroll to bottom with smooth behavior
    setTimeout(() => {
      if (messagesContainerRef.current) {
        messagesContainerRef.current.scrollTo({
          top: messagesContainerRef.current.scrollHeight,
          behavior: 'smooth'
        })
      }
    }, 100)
  }, [])

  const getConnectionQualityIcon = (quality: string) => {
    switch (quality) {
      case 'good': return <Wifi className="w-4 h-4" />
      case 'fair': return <Wifi className="w-4 h-4" />
      case 'poor': return <WifiOff className="w-4 h-4" />
      default: return <WifiOff className="w-4 h-4" />
    }
  }

  // Format time
  const formatTime = (date: Date) => {
    return date.toLocaleTimeString('zh-CN', { 
      hour: '2-digit', 
      minute: '2-digit' 
    })
  }

  // Enhanced cleanup on unmount
  useEffect(() => {
    connectWebSocket()
    
    // Set up error handling callbacks
    const handlePermissionError = (errorInfo: any) => {
      setError(errorInfo.userMessage)
    }
    
    const handleAudioError = (errorInfo: any) => {
      console.warn('Audio playback error:', errorInfo.userMessage)
    }
    
    const handleWebSocketError = (errorInfo: any) => {
      setError(errorInfo.userMessage)
    }
    
    errorHandler.onError(ErrorType.PERMISSION, handlePermissionError)
    errorHandler.onError(ErrorType.AUDIO_PLAYBACK, handleAudioError)
    errorHandler.onError(ErrorType.WEBSOCKET, handleWebSocketError)
    
    return () => {
      // Clean up WebSocket
      if (websocketRef.current) {
        websocketRef.current.close()
      }
      
      // Clean up listening
      stopListening()
      
      // Clean up reconnection timeout
      if (reconnectTimeoutRef.current) {
        clearTimeout(reconnectTimeoutRef.current)
      }
      
      // Clean up error handlers
      errorHandler.offError(ErrorType.PERMISSION, handlePermissionError)
      errorHandler.offError(ErrorType.AUDIO_PLAYBACK, handleAudioError)
      errorHandler.offError(ErrorType.WEBSOCKET, handleWebSocketError)
    }
  }, [connectWebSocket, stopListening])

  return (
    <div className="max-w-4xl mx-auto h-full flex flex-col">
      {/* Enhanced Header with Connection Quality */}
      <div className="flex justify-between items-center mb-6 pb-4 border-b border-gray-200">
        <h1 className="text-2xl font-bold text-gray-900">GPT 实时语音对话</h1>
        <div className="flex items-center gap-4">
          {/* Connection Status */}
          <div className={`flex items-center gap-2 px-3 py-1 rounded-full text-sm font-medium ${
            isConnected 
              ? 'bg-green-100 text-green-800' 
              : 'bg-red-100 text-red-800'
          }`}>
            {getConnectionQualityIcon(connectionQuality)}
            {isConnected ? '已连接' : '未连接'}
          </div>
          
          {/* Audio Status */}
          {isAudioPlaying && (
            <div className="flex items-center gap-2 px-3 py-1 rounded-full text-sm font-medium bg-blue-100 text-blue-800">
              <Volume2 className="w-4 h-4" />
              播放中
            </div>
          )}
          
          {/* Reconnection Status */}
          {reconnectAttempts > 0 && (
            <div className="flex items-center gap-2 px-3 py-1 rounded-full text-sm font-medium bg-yellow-100 text-yellow-800">
              <Activity className="w-4 h-4 animate-pulse" />
              重连中 ({reconnectAttempts}/5)
            </div>
          )}
        </div>
      </div>

      {/* Enhanced Messages Display */}
      <div 
        ref={messagesContainerRef}
        className="flex-1 overflow-y-auto mb-6 space-y-4 px-2"
      >
        {messages.length === 0 ? (
          <div className="flex items-center justify-center h-full text-gray-500">
            <div className="text-center">
              <Mic className="w-12 h-12 mx-auto mb-4 text-gray-300" />
              <p className="text-lg font-medium">开始您的语音对话</p>
              <p className="text-sm">点击录音按钮与 GPT 进行实时语音交流</p>
            </div>
          </div>
        ) : (
          messages.map((message) => (
            <div
              key={message.id}
              className={`flex ${message.type === 'user' ? 'justify-end' : 'justify-start'}`}
            >
              <div className={`max-w-xs lg:max-w-md px-4 py-3 rounded-2xl shadow-sm ${
                message.type === 'user'
                  ? 'bg-blue-500 text-white rounded-br-md'
                  : 'bg-white text-gray-900 border border-gray-200 rounded-bl-md'
              }`}>
                <div className="text-sm leading-relaxed">{message.text}</div>
                <div className={`text-xs mt-2 flex items-center gap-1 ${
                  message.type === 'user' ? 'text-blue-100' : 'text-gray-500'
                }`}>
                  {message.type === 'assistant' && <Volume2 className="w-3 h-3" />}
                  {formatTime(message.timestamp)}
                </div>
              </div>
            </div>
          ))
        )}
        
        {/* Typing indicator when processing */}
        {isProcessing && (
          <div className="flex justify-start">
            <div className="bg-white border border-gray-200 px-4 py-3 rounded-2xl rounded-bl-md shadow-sm">
              <div className="flex items-center gap-1">
                <div className="flex gap-1">
                  <div className="w-2 h-2 bg-gray-400 rounded-full animate-bounce" style={{ animationDelay: '0ms' }} />
                  <div className="w-2 h-2 bg-gray-400 rounded-full animate-bounce" style={{ animationDelay: '150ms' }} />
                  <div className="w-2 h-2 bg-gray-400 rounded-full animate-bounce" style={{ animationDelay: '300ms' }} />
                </div>
                <span className="text-xs text-gray-500 ml-2">GPT 正在思考...</span>
              </div>
            </div>
          </div>
        )}
      </div>

      {/* Enhanced Audio Controls with Visualization */}
      <div className="bg-gray-50 rounded-lg p-6 space-y-4">
        <div className="flex flex-col items-center space-y-4">
          {/* Main Listening Button */}
          <button
            onClick={toggleListening}
            disabled={!isConnected}
            className={`flex items-center gap-3 px-8 py-4 rounded-full text-white font-medium transition-all duration-300 transform ${
              isListening
                ? 'bg-red-500 hover:bg-red-600 animate-pulse scale-110'
                : 'bg-blue-500 hover:bg-blue-600 hover:scale-105'
            } disabled:bg-gray-400 disabled:cursor-not-allowed disabled:hover:scale-100 disabled:animate-none`}
          >
            {isListening ? <MicOff className="w-6 h-6" /> : <Mic className="w-6 h-6" />}
            <span className="text-lg">
              {isListening ? '停止监听' : '开始监听'}
            </span>
          </button>

          {/* Enhanced Audio Visualization */}
          {isListening && (
            <div className="w-full max-w-md space-y-3">
              {/* Canvas-based Waveform Visualization */}
              <div className="bg-white rounded-lg p-4 border-2 border-blue-200">
                <canvas
                  ref={audioVisualizationRef}
                  width={400}
                  height={100}
                  className="w-full h-20 rounded"
                />
              </div>
              
              {/* Audio Level Bar */}
              <div className="w-full">
                <div className="flex justify-between text-xs text-gray-500 mb-1">
                  <span>音量</span>
                  <span>{Math.round(audioLevel)}%</span>
                </div>
                <div className="w-full h-3 bg-gray-200 rounded-full overflow-hidden">
                  <div 
                    className="h-full bg-gradient-to-r from-green-400 via-yellow-400 to-red-500 transition-all duration-100 rounded-full"
                    style={{ width: `${audioLevel}%` }}
                  />
                </div>
              </div>
              
              {/* Listening Indicator */}
              <div className="flex items-center justify-center gap-2 text-green-600">
                <div className="w-3 h-3 bg-green-500 rounded-full animate-pulse" />
                <span className="text-sm font-medium">正在监听...</span>
              </div>
            </div>
          )}
        </div>

        {/* Enhanced Status Info */}
        <div className="flex justify-center min-h-[50px] items-center">
          {isProcessing && (
            <div className="flex items-center gap-3 text-blue-600 bg-blue-50 px-4 py-2 rounded-lg">
              <div className="w-5 h-5 border-2 border-blue-600 border-t-transparent rounded-full animate-spin" />
              <span className="font-medium">正在处理语音...</span>
            </div>
          )}
          
          {error && (
            <div className="flex items-center gap-3 text-red-600 bg-red-50 px-4 py-2 rounded-lg max-w-md">
              <AlertCircle className="w-5 h-5 flex-shrink-0" />
              <span className="text-sm">{error}</span>
              {!isConnected && (
                <button
                  onClick={connectWebSocket}
                  className="ml-2 px-3 py-1 bg-red-600 text-white text-xs rounded hover:bg-red-700 transition-colors"
                >
                  重试连接
                </button>
              )}
            </div>
          )}
          
          {!error && !isProcessing && isConnected && !isListening && (
            <div className="text-gray-500 text-sm">
              点击开始监听按钮开始语音对话
            </div>
          )}
        </div>
      </div>
    </div>
  )
}
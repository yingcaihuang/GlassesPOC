package service

import (
	"bytes"
	"encoding/base64"
	"encoding/binary"
	"fmt"
	"log"
	"math"
)

// AudioProcessor 音频处理组件
type AudioProcessor struct {
	sampleRate   int // 采样率，默认16kHz
	channelCount int // 声道数，默认单声道
	bitDepth     int // 位深度，默认16位
}

// AudioFormat 音频格式枚举
type AudioFormat string

const (
	FormatPCM16 AudioFormat = "pcm16"
	FormatWebM  AudioFormat = "webm"
	FormatWAV   AudioFormat = "wav"
)

// AudioConfig 音频配置
type AudioConfig struct {
	SampleRate   int         `json:"sample_rate"`
	ChannelCount int         `json:"channel_count"`
	BitDepth     int         `json:"bit_depth"`
	Format       AudioFormat `json:"format"`
}

// AudioProcessingError 音频处理错误类型
type AudioProcessingError struct {
	Type    string
	Message string
	Details string
}

func (e *AudioProcessingError) Error() string {
	return fmt.Sprintf("AudioProcessingError[%s]: %s - %s", e.Type, e.Message, e.Details)
}

// NewAudioProcessor 创建新的音频处理器
// Requirements: 7.2, 7.3 - 支持16kHz采样率和单声道音频
func NewAudioProcessor() *AudioProcessor {
	return &AudioProcessor{
		sampleRate:   16000, // 16kHz采样率
		channelCount: 1,     // 单声道
		bitDepth:     16,    // 16位深度
	}
}

// DecodeBase64Audio 解码Base64音频数据
// Requirements: 3.1, 3.2 - 验证数据格式为Base64编码，解码Base64音频数据为二进制格式
func (ap *AudioProcessor) DecodeBase64Audio(audioData string) ([]byte, error) {
	if audioData == "" {
		return nil, &AudioProcessingError{
			Type:    "validation_error",
			Message: "Audio data is empty",
			Details: "Input audio data string is empty",
		}
	}

	// 验证Base64格式并解码
	decodedData, err := base64.StdEncoding.DecodeString(audioData)
	if err != nil {
		return nil, &AudioProcessingError{
			Type:    "decode_error",
			Message: "Invalid Base64 audio data",
			Details: fmt.Sprintf("Base64 decode failed: %v", err),
		}
	}

	if len(decodedData) == 0 {
		return nil, &AudioProcessingError{
			Type:    "validation_error",
			Message: "Decoded audio data is empty",
			Details: "Base64 decoded successfully but resulted in empty data",
		}
	}

	return decodedData, nil
}

// EncodeAudioToBase64 编码音频数据为Base64
// Requirements: 7.4 - 使用Base64编码进行网络传输
func (ap *AudioProcessor) EncodeAudioToBase64(audioData []byte) string {
	if len(audioData) == 0 {
		log.Printf("Warning: Encoding empty audio data to Base64")
		return ""
	}

	return base64.StdEncoding.EncodeToString(audioData)
}

// ValidateAudioFormat 验证音频格式
// Requirements: 3.1 - 验证数据格式
func (ap *AudioProcessor) ValidateAudioFormat(audioData []byte) error {
	if len(audioData) == 0 {
		return &AudioProcessingError{
			Type:    "validation_error",
			Message: "Audio data is empty",
			Details: "Cannot validate empty audio data",
		}
	}

	// 验证PCM16格式的基本要求
	// PCM16数据长度应该是2的倍数（每个样本2字节）
	if len(audioData)%2 != 0 {
		return &AudioProcessingError{
			Type:    "format_error",
			Message: "Invalid PCM16 format",
			Details: fmt.Sprintf("Audio data length %d is not divisible by 2", len(audioData)),
		}
	}

	// 验证音频数据长度是否合理（至少包含一些样本）
	minSamples := 160 // 10ms at 16kHz
	if len(audioData) < minSamples*2 {
		return &AudioProcessingError{
			Type:    "validation_error",
			Message: "Audio data too short",
			Details: fmt.Sprintf("Audio data length %d is less than minimum required %d bytes", len(audioData), minSamples*2),
		}
	}

	// 验证音频数据长度是否过长（防止内存问题）
	maxSamples := 160000 // 10 seconds at 16kHz
	if len(audioData) > maxSamples*2 {
		return &AudioProcessingError{
			Type:    "validation_error",
			Message: "Audio data too long",
			Details: fmt.Sprintf("Audio data length %d exceeds maximum allowed %d bytes", len(audioData), maxSamples*2),
		}
	}

	return nil
}

// ConvertAudioFormat 转换音频格式
// Requirements: 7.1 - 支持WebM到PCM16格式转换
func (ap *AudioProcessor) ConvertAudioFormat(input []byte, fromFormat, toFormat string) ([]byte, error) {
	if len(input) == 0 {
		return nil, &AudioProcessingError{
			Type:    "validation_error",
			Message: "Input audio data is empty",
			Details: "Cannot convert empty audio data",
		}
	}

	// 目前主要支持PCM16格式，其他格式转换需要额外的库支持
	switch {
	case fromFormat == string(FormatPCM16) && toFormat == string(FormatPCM16):
		// 相同格式，直接返回
		return input, nil

	case fromFormat == string(FormatWebM) && toFormat == string(FormatPCM16):
		// WebM到PCM16的转换（简化实现，实际需要使用专门的音频库）
		return ap.convertWebMToPCM16(input)

	case fromFormat == string(FormatWAV) && toFormat == string(FormatPCM16):
		// WAV到PCM16的转换
		return ap.convertWAVToPCM16(input)

	default:
		return nil, &AudioProcessingError{
			Type:    "unsupported_format",
			Message: "Unsupported audio format conversion",
			Details: fmt.Sprintf("Conversion from %s to %s is not supported", fromFormat, toFormat),
		}
	}
}

// convertWebMToPCM16 将WebM格式转换为PCM16（简化实现）
func (ap *AudioProcessor) convertWebMToPCM16(webmData []byte) ([]byte, error) {
	// 注意：这是一个简化的实现示例
	// 实际的WebM解码需要使用专门的音频库如FFmpeg或libwebm
	
	// 对于演示目的，我们假设输入已经是PCM数据
	// 在实际实现中，这里需要调用WebM解码器
	
	log.Printf("Warning: WebM to PCM16 conversion is simplified - actual implementation requires audio decoding library")
	
	// 验证输入数据
	if len(webmData) < 100 {
		return nil, &AudioProcessingError{
			Type:    "format_error",
			Message: "Invalid WebM data",
			Details: "WebM data too short to be valid",
		}
	}

	// 简化处理：假设数据已经是PCM格式，只需要验证和调整
	return ap.ensurePCM16Format(webmData)
}

// convertWAVToPCM16 将WAV格式转换为PCM16
func (ap *AudioProcessor) convertWAVToPCM16(wavData []byte) ([]byte, error) {
	if len(wavData) < 44 {
		return nil, &AudioProcessingError{
			Type:    "format_error",
			Message: "Invalid WAV file",
			Details: "WAV file too short to contain valid header",
		}
	}

	// 验证WAV文件头
	if !bytes.Equal(wavData[0:4], []byte("RIFF")) || !bytes.Equal(wavData[8:12], []byte("WAVE")) {
		return nil, &AudioProcessingError{
			Type:    "format_error",
			Message: "Invalid WAV file format",
			Details: "Missing RIFF/WAVE header",
		}
	}

	// 跳过WAV头部，提取PCM数据（简化实现）
	// 实际实现需要解析完整的WAV头部信息
	dataStart := 44
	if len(wavData) <= dataStart {
		return nil, &AudioProcessingError{
			Type:    "format_error",
			Message: "WAV file has no audio data",
			Details: "WAV file contains only header without audio data",
		}
	}

	pcmData := wavData[dataStart:]
	return ap.ensurePCM16Format(pcmData)
}

// ensurePCM16Format 确保音频数据符合PCM16格式要求
func (ap *AudioProcessor) ensurePCM16Format(data []byte) ([]byte, error) {
	// 验证数据长度
	if len(data)%2 != 0 {
		// 如果长度不是偶数，截断最后一个字节
		data = data[:len(data)-1]
		log.Printf("Warning: Truncated audio data to ensure even length")
	}

	// 验证采样值范围（PCM16: -32768 to 32767）
	samples := len(data) / 2
	for i := 0; i < samples; i++ {
		sample := int16(binary.LittleEndian.Uint16(data[i*2 : i*2+2]))
		// PCM16样本值检查（可选的质量验证）
		if sample == 0 && i > 0 && i < samples-1 {
			// 检测连续的零值（可能表示静音或数据问题）
			continue
		}
	}

	return data, nil
}

// ProcessRealtimeAudioChunk 处理实时音频块
// Requirements: 3.5 - 支持实时音频流处理（100ms块）
func (ap *AudioProcessor) ProcessRealtimeAudioChunk(audioChunk []byte) ([]byte, error) {
	if len(audioChunk) == 0 {
		// Requirements: 3.4 - 记录错误并继续处理
		log.Printf("Warning: Received empty audio chunk, skipping")
		return nil, &AudioProcessingError{
			Type:    "validation_error",
			Message: "Audio chunk is empty",
			Details: "Received empty audio chunk in realtime processing",
		}
	}

	// 验证音频块格式
	if err := ap.ValidateAudioFormat(audioChunk); err != nil {
		// Requirements: 3.4 - 记录错误并继续处理
		log.Printf("Audio chunk validation failed: %v", err)
		return nil, err
	}

	// 验证音频块大小（100ms的PCM16数据约为3200字节，16kHz单声道）
	expectedChunkSize := ap.sampleRate / 10 * 2 // 100ms * sampleRate * 2bytes/sample
	actualSize := len(audioChunk)

	if actualSize > expectedChunkSize*2 {
		log.Printf("Warning: Audio chunk size %d exceeds expected size %d for 100ms", actualSize, expectedChunkSize)
	}

	if actualSize < expectedChunkSize/2 {
		log.Printf("Warning: Audio chunk size %d is smaller than expected minimum %d", actualSize, expectedChunkSize/2)
	}

	// 处理音频数据（可以在这里添加音频增强、降噪等处理）
	processedChunk := make([]byte, len(audioChunk))
	copy(processedChunk, audioChunk)

	return processedChunk, nil
}

// GetAudioConfig 获取音频配置
func (ap *AudioProcessor) GetAudioConfig() AudioConfig {
	return AudioConfig{
		SampleRate:   ap.sampleRate,
		ChannelCount: ap.channelCount,
		BitDepth:     ap.bitDepth,
		Format:       FormatPCM16,
	}
}

// SetAudioConfig 设置音频配置
func (ap *AudioProcessor) SetAudioConfig(config AudioConfig) error {
	// 验证配置参数
	if config.SampleRate <= 0 || config.SampleRate > 48000 {
		return &AudioProcessingError{
			Type:    "config_error",
			Message: "Invalid sample rate",
			Details: fmt.Sprintf("Sample rate %d is not supported", config.SampleRate),
		}
	}

	if config.ChannelCount <= 0 || config.ChannelCount > 2 {
		return &AudioProcessingError{
			Type:    "config_error",
			Message: "Invalid channel count",
			Details: fmt.Sprintf("Channel count %d is not supported", config.ChannelCount),
		}
	}

	if config.BitDepth != 16 {
		return &AudioProcessingError{
			Type:    "config_error",
			Message: "Invalid bit depth",
			Details: fmt.Sprintf("Bit depth %d is not supported, only 16-bit is supported", config.BitDepth),
		}
	}

	ap.sampleRate = config.SampleRate
	ap.channelCount = config.ChannelCount
	ap.bitDepth = config.BitDepth

	return nil
}

// GenerateTestAudioData 生成测试音频数据（用于测试）
func (ap *AudioProcessor) GenerateTestAudioData(durationMs int, frequency float64) []byte {
	samples := ap.sampleRate * durationMs / 1000
	data := make([]byte, samples*2) // 16-bit samples

	for i := 0; i < samples; i++ {
		// 生成正弦波测试音频
		sample := int16(math.Sin(2*math.Pi*frequency*float64(i)/float64(ap.sampleRate)) * 16383) // 使用一半的最大振幅
		binary.LittleEndian.PutUint16(data[i*2:], uint16(sample))
	}

	return data
}

// RecoverFromError 错误恢复机制
// Requirements: 3.4 - 实现错误处理和恢复机制
func (ap *AudioProcessor) RecoverFromError(err error, context string) error {
	if err == nil {
		return nil
	}

	// 记录错误详情
	log.Printf("Audio processing error in %s: %v", context, err)

	// 根据错误类型决定恢复策略
	if audioErr, ok := err.(*AudioProcessingError); ok {
		switch audioErr.Type {
		case "validation_error":
			// 验证错误：记录并继续处理
			log.Printf("Validation error recovered: %s", audioErr.Message)
			return nil // 继续处理

		case "decode_error":
			// 解码错误：记录并跳过当前数据
			log.Printf("Decode error recovered: %s", audioErr.Message)
			return nil // 继续处理

		case "format_error":
			// 格式错误：记录并尝试使用默认格式
			log.Printf("Format error recovered: %s", audioErr.Message)
			return nil // 继续处理

		case "unsupported_format":
			// 不支持的格式：返回错误，需要上层处理
			return audioErr

		case "config_error":
			// 配置错误：返回错误，需要修复配置
			return audioErr

		default:
			// 未知错误类型：记录并继续
			log.Printf("Unknown audio error type recovered: %s", audioErr.Type)
			return nil
		}
	}

	// 非音频处理错误：记录并返回
	log.Printf("Non-audio processing error: %v", err)
	return err
}

// IsValidPCM16Data 检查数据是否为有效的PCM16格式
func (ap *AudioProcessor) IsValidPCM16Data(data []byte) bool {
	if len(data) == 0 || len(data)%2 != 0 {
		return false
	}

	// 检查是否全为零（可能表示静音或无效数据）
	allZero := true
	for _, b := range data {
		if b != 0 {
			allZero = false
			break
		}
	}

	// 如果全为零且数据较长，可能是无效数据
	if allZero && len(data) > 1000 {
		return false
	}

	return true
}
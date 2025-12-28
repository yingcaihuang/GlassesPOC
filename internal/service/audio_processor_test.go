package service

import (
	"encoding/base64"
	"encoding/binary"
	"math"
	"testing"
)

func TestNewAudioProcessor(t *testing.T) {
	ap := NewAudioProcessor()
	
	if ap.sampleRate != 16000 {
		t.Errorf("Expected sample rate 16000, got %d", ap.sampleRate)
	}
	
	if ap.channelCount != 1 {
		t.Errorf("Expected channel count 1, got %d", ap.channelCount)
	}
	
	if ap.bitDepth != 16 {
		t.Errorf("Expected bit depth 16, got %d", ap.bitDepth)
	}
}

func TestDecodeBase64Audio(t *testing.T) {
	ap := NewAudioProcessor()
	
	// Test valid Base64 audio data
	testData := []byte{0x01, 0x02, 0x03, 0x04}
	encodedData := base64.StdEncoding.EncodeToString(testData)
	
	decoded, err := ap.DecodeBase64Audio(encodedData)
	if err != nil {
		t.Errorf("Expected no error, got %v", err)
	}
	
	if len(decoded) != len(testData) {
		t.Errorf("Expected decoded length %d, got %d", len(testData), len(decoded))
	}
	
	for i, b := range decoded {
		if b != testData[i] {
			t.Errorf("Expected byte %d at index %d, got %d", testData[i], i, b)
		}
	}
	
	// Test empty string
	_, err = ap.DecodeBase64Audio("")
	if err == nil {
		t.Error("Expected error for empty string")
	}
	
	// Test invalid Base64
	_, err = ap.DecodeBase64Audio("invalid-base64!")
	if err == nil {
		t.Error("Expected error for invalid Base64")
	}
}

func TestEncodeAudioToBase64(t *testing.T) {
	ap := NewAudioProcessor()
	
	testData := []byte{0x01, 0x02, 0x03, 0x04}
	encoded := ap.EncodeAudioToBase64(testData)
	
	expected := base64.StdEncoding.EncodeToString(testData)
	if encoded != expected {
		t.Errorf("Expected %s, got %s", expected, encoded)
	}
	
	// Test empty data
	encoded = ap.EncodeAudioToBase64([]byte{})
	if encoded != "" {
		t.Errorf("Expected empty string for empty data, got %s", encoded)
	}
}

func TestValidateAudioFormat(t *testing.T) {
	ap := NewAudioProcessor()
	
	// Test valid PCM16 data (even length, reasonable size)
	validData := make([]byte, 3200) // 100ms at 16kHz
	for i := 0; i < len(validData); i += 2 {
		binary.LittleEndian.PutUint16(validData[i:], uint16(i))
	}
	
	err := ap.ValidateAudioFormat(validData)
	if err != nil {
		t.Errorf("Expected no error for valid data, got %v", err)
	}
	
	// Test empty data
	err = ap.ValidateAudioFormat([]byte{})
	if err == nil {
		t.Error("Expected error for empty data")
	}
	
	// Test odd length data
	oddData := []byte{0x01, 0x02, 0x03}
	err = ap.ValidateAudioFormat(oddData)
	if err == nil {
		t.Error("Expected error for odd length data")
	}
	
	// Test too short data
	shortData := []byte{0x01, 0x02}
	err = ap.ValidateAudioFormat(shortData)
	if err == nil {
		t.Error("Expected error for too short data")
	}
	
	// Test too long data
	longData := make([]byte, 400000) // > 10 seconds
	err = ap.ValidateAudioFormat(longData)
	if err == nil {
		t.Error("Expected error for too long data")
	}
}

func TestConvertAudioFormat(t *testing.T) {
	ap := NewAudioProcessor()
	
	testData := make([]byte, 1000)
	for i := 0; i < len(testData); i += 2 {
		binary.LittleEndian.PutUint16(testData[i:], uint16(i))
	}
	
	// Test PCM16 to PCM16 (should return same data)
	converted, err := ap.ConvertAudioFormat(testData, string(FormatPCM16), string(FormatPCM16))
	if err != nil {
		t.Errorf("Expected no error for PCM16 to PCM16, got %v", err)
	}
	
	if len(converted) != len(testData) {
		t.Errorf("Expected same length, got %d vs %d", len(converted), len(testData))
	}
	
	// Test empty data
	_, err = ap.ConvertAudioFormat([]byte{}, string(FormatPCM16), string(FormatPCM16))
	if err == nil {
		t.Error("Expected error for empty data")
	}
	
	// Test unsupported conversion
	_, err = ap.ConvertAudioFormat(testData, "unsupported", string(FormatPCM16))
	if err == nil {
		t.Error("Expected error for unsupported format")
	}
}

func TestProcessRealtimeAudioChunk(t *testing.T) {
	ap := NewAudioProcessor()
	
	// Generate test audio chunk (100ms at 16kHz)
	chunkSize := 3200 // 100ms * 16000Hz * 2bytes/sample
	testChunk := make([]byte, chunkSize)
	for i := 0; i < chunkSize; i += 2 {
		sample := int16(math.Sin(2*math.Pi*440*float64(i/2)/16000) * 16383)
		binary.LittleEndian.PutUint16(testChunk[i:], uint16(sample))
	}
	
	processed, err := ap.ProcessRealtimeAudioChunk(testChunk)
	if err != nil {
		t.Errorf("Expected no error for valid chunk, got %v", err)
	}
	
	if len(processed) != len(testChunk) {
		t.Errorf("Expected same length, got %d vs %d", len(processed), len(testChunk))
	}
	
	// Test empty chunk
	_, err = ap.ProcessRealtimeAudioChunk([]byte{})
	if err == nil {
		t.Error("Expected error for empty chunk")
	}
	
	// Test invalid chunk (odd length)
	invalidChunk := []byte{0x01, 0x02, 0x03}
	_, err = ap.ProcessRealtimeAudioChunk(invalidChunk)
	if err == nil {
		t.Error("Expected error for invalid chunk")
	}
}

func TestGetAudioConfig(t *testing.T) {
	ap := NewAudioProcessor()
	config := ap.GetAudioConfig()
	
	if config.SampleRate != 16000 {
		t.Errorf("Expected sample rate 16000, got %d", config.SampleRate)
	}
	
	if config.ChannelCount != 1 {
		t.Errorf("Expected channel count 1, got %d", config.ChannelCount)
	}
	
	if config.BitDepth != 16 {
		t.Errorf("Expected bit depth 16, got %d", config.BitDepth)
	}
	
	if config.Format != FormatPCM16 {
		t.Errorf("Expected format PCM16, got %s", config.Format)
	}
}

func TestSetAudioConfig(t *testing.T) {
	ap := NewAudioProcessor()
	
	// Test valid config
	validConfig := AudioConfig{
		SampleRate:   16000,
		ChannelCount: 1,
		BitDepth:     16,
		Format:       FormatPCM16,
	}
	
	err := ap.SetAudioConfig(validConfig)
	if err != nil {
		t.Errorf("Expected no error for valid config, got %v", err)
	}
	
	// Test invalid sample rate
	invalidConfig := validConfig
	invalidConfig.SampleRate = 0
	err = ap.SetAudioConfig(invalidConfig)
	if err == nil {
		t.Error("Expected error for invalid sample rate")
	}
	
	// Test invalid channel count
	invalidConfig = validConfig
	invalidConfig.ChannelCount = 0
	err = ap.SetAudioConfig(invalidConfig)
	if err == nil {
		t.Error("Expected error for invalid channel count")
	}
	
	// Test invalid bit depth
	invalidConfig = validConfig
	invalidConfig.BitDepth = 8
	err = ap.SetAudioConfig(invalidConfig)
	if err == nil {
		t.Error("Expected error for invalid bit depth")
	}
}

func TestGenerateTestAudioData(t *testing.T) {
	ap := NewAudioProcessor()
	
	// Generate 100ms of 440Hz tone
	data := ap.GenerateTestAudioData(100, 440.0)
	
	expectedLength := 16000 * 100 / 1000 * 2 // 100ms * 16kHz * 2bytes/sample
	if len(data) != expectedLength {
		t.Errorf("Expected length %d, got %d", expectedLength, len(data))
	}
	
	// Verify it's valid PCM16 data
	err := ap.ValidateAudioFormat(data)
	if err != nil {
		t.Errorf("Generated data should be valid PCM16, got error: %v", err)
	}
}

func TestRecoverFromError(t *testing.T) {
	ap := NewAudioProcessor()
	
	// Test nil error
	err := ap.RecoverFromError(nil, "test")
	if err != nil {
		t.Errorf("Expected nil for nil error, got %v", err)
	}
	
	// Test validation error (should recover)
	validationErr := &AudioProcessingError{
		Type:    "validation_error",
		Message: "Test validation error",
	}
	err = ap.RecoverFromError(validationErr, "test")
	if err != nil {
		t.Errorf("Expected nil for validation error recovery, got %v", err)
	}
	
	// Test config error (should not recover)
	configErr := &AudioProcessingError{
		Type:    "config_error",
		Message: "Test config error",
	}
	err = ap.RecoverFromError(configErr, "test")
	if err == nil {
		t.Error("Expected error for config error, got nil")
	}
}

func TestIsValidPCM16Data(t *testing.T) {
	ap := NewAudioProcessor()
	
	// Test valid data
	validData := make([]byte, 1000)
	for i := 0; i < len(validData); i += 2 {
		binary.LittleEndian.PutUint16(validData[i:], uint16(i))
	}
	
	if !ap.IsValidPCM16Data(validData) {
		t.Error("Expected true for valid PCM16 data")
	}
	
	// Test empty data
	if ap.IsValidPCM16Data([]byte{}) {
		t.Error("Expected false for empty data")
	}
	
	// Test odd length data
	if ap.IsValidPCM16Data([]byte{0x01, 0x02, 0x03}) {
		t.Error("Expected false for odd length data")
	}
	
	// Test all zero data (long)
	zeroData := make([]byte, 2000)
	if ap.IsValidPCM16Data(zeroData) {
		t.Error("Expected false for long all-zero data")
	}
	
	// Test short zero data (should be valid)
	shortZeroData := make([]byte, 100)
	if !ap.IsValidPCM16Data(shortZeroData) {
		t.Error("Expected true for short zero data")
	}
}

// Test error types
func TestAudioProcessingError(t *testing.T) {
	err := &AudioProcessingError{
		Type:    "test_error",
		Message: "Test message",
		Details: "Test details",
	}
	
	expected := "AudioProcessingError[test_error]: Test message - Test details"
	if err.Error() != expected {
		t.Errorf("Expected %s, got %s", expected, err.Error())
	}
}

// Integration test for Base64 round trip
func TestBase64RoundTrip(t *testing.T) {
	ap := NewAudioProcessor()
	
	// Generate test data
	originalData := ap.GenerateTestAudioData(100, 440.0)
	
	// Encode to Base64
	encoded := ap.EncodeAudioToBase64(originalData)
	
	// Decode from Base64
	decoded, err := ap.DecodeBase64Audio(encoded)
	if err != nil {
		t.Errorf("Round trip failed: %v", err)
	}
	
	// Verify data integrity
	if len(decoded) != len(originalData) {
		t.Errorf("Round trip length mismatch: %d vs %d", len(decoded), len(originalData))
	}
	
	for i, b := range decoded {
		if b != originalData[i] {
			t.Errorf("Round trip data mismatch at index %d: %d vs %d", i, b, originalData[i])
		}
	}
}
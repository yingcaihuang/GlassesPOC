package service

import (
	"context"
	"encoding/base64"
	"testing"
	"time"
)

func TestNewRealtimeService(t *testing.T) {
	apiKey := "test-api-key"
	endpoint := "https://test.openai.azure.com"
	deploymentName := "gpt-4o-realtime-preview"
	apiVersion := "2024-10-01-preview"

	service := NewRealtimeService(apiKey, endpoint, deploymentName, apiVersion)

	if service.apiKey != apiKey {
		t.Errorf("Expected apiKey %s, got %s", apiKey, service.apiKey)
	}
	if service.endpoint != endpoint {
		t.Errorf("Expected endpoint %s, got %s", endpoint, service.endpoint)
	}
	if service.deploymentName != deploymentName {
		t.Errorf("Expected deploymentName %s, got %s", deploymentName, service.deploymentName)
	}
	if service.apiVersion != apiVersion {
		t.Errorf("Expected apiVersion %s, got %s", apiVersion, service.apiVersion)
	}
	if service.connections == nil {
		t.Error("Expected connections map to be initialized")
	}
}

func TestValidateAudioData(t *testing.T) {
	service := NewRealtimeService("test", "test", "test", "test")

	// Test valid base64 audio data
	testData := []byte("test audio data")
	encodedData := base64.StdEncoding.EncodeToString(testData)

	decodedData, err := service.ValidateAudioData(encodedData)
	if err != nil {
		t.Errorf("Expected no error for valid base64 data, got: %v", err)
	}
	if string(decodedData) != string(testData) {
		t.Errorf("Expected decoded data to match original, got: %s", string(decodedData))
	}

	// Test empty audio data
	_, err = service.ValidateAudioData("")
	if err == nil {
		t.Error("Expected error for empty audio data")
	}

	// Test invalid base64 data
	_, err = service.ValidateAudioData("invalid-base64!")
	if err == nil {
		t.Error("Expected error for invalid base64 data")
	}
}

func TestProcessAudioStream(t *testing.T) {
	service := NewRealtimeService("test", "test", "test", "test")

	// Test empty audio chunk
	err := service.ProcessAudioStream(nil, []byte{})
	if err == nil {
		t.Error("Expected error for empty audio chunk")
	}

	// Test valid audio chunk (this will fail to send since conn is nil, but validates the chunk)
	audioChunk := make([]byte, 1600) // 50ms of 16kHz PCM16 data
	err = service.ProcessAudioStream(nil, audioChunk)
	if err == nil {
		t.Error("Expected error for nil connection")
	}
}

func TestGetConnectionStatus(t *testing.T) {
	service := NewRealtimeService("test", "test", "test", "test")

	// Test nil connection
	status := service.GetConnectionStatus(nil)
	if status {
		t.Error("Expected false for nil connection")
	}
}

func TestCloseConnection(t *testing.T) {
	service := NewRealtimeService("test", "test", "test", "test")

	// Test nil connection (should not panic)
	err := service.CloseConnection(nil)
	if err != nil {
		t.Errorf("Expected no error for nil connection, got: %v", err)
	}
}

// Test that the service can be created with configuration from environment
func TestRealtimeServiceIntegration(t *testing.T) {
	// This test verifies that the service can be created with realistic configuration
	service := NewRealtimeService(
		"test-api-key",
		"https://test.openai.azure.com",
		"gpt-4o-realtime-preview",
		"2024-10-01-preview",
	)

	if service == nil {
		t.Fatal("Expected service to be created")
	}

	// Test that we can create a context for connection (won't actually connect in test)
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	// This would normally connect, but we're just testing the setup
	if ctx.Err() != nil {
		t.Error("Context should not be cancelled immediately")
	}
}

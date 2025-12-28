package config

import (
	"os"
	"testing"
)

func TestRealtimeConfigLoading(t *testing.T) {
	// Test environment variable loading for Realtime config
	testCases := []struct {
		name     string
		envVars  map[string]string
		expected RealtimeConfig
	}{
		{
			name: "Default values when no env vars set",
			envVars: map[string]string{},
			expected: RealtimeConfig{
				Endpoint:       "",
				APIKey:         "",
				DeploymentName: "gpt-4o-realtime-preview",
				APIVersion:     "2024-10-01-preview",
			},
		},
		{
			name: "Custom values from env vars",
			envVars: map[string]string{
				"AZURE_OPENAI_REALTIME_ENDPOINT":        "https://test.openai.azure.com/",
				"AZURE_OPENAI_REALTIME_API_KEY":         "test-key-123",
				"AZURE_OPENAI_REALTIME_DEPLOYMENT_NAME": "custom-deployment",
				"AZURE_OPENAI_REALTIME_API_VERSION":     "2024-11-01-preview",
			},
			expected: RealtimeConfig{
				Endpoint:       "https://test.openai.azure.com/",
				APIKey:         "test-key-123",
				DeploymentName: "custom-deployment",
				APIVersion:     "2024-11-01-preview",
			},
		},
	}

	for _, tc := range testCases {
		t.Run(tc.name, func(t *testing.T) {
			// Clear existing env vars
			os.Unsetenv("AZURE_OPENAI_REALTIME_ENDPOINT")
			os.Unsetenv("AZURE_OPENAI_REALTIME_API_KEY")
			os.Unsetenv("AZURE_OPENAI_REALTIME_DEPLOYMENT_NAME")
			os.Unsetenv("AZURE_OPENAI_REALTIME_API_VERSION")

			// Set test env vars
			for key, value := range tc.envVars {
				os.Setenv(key, value)
			}

			// Load config
			cfg, err := Load()
			if err != nil {
				t.Fatalf("Failed to load config: %v", err)
			}

			// Verify Realtime config
			if cfg.Realtime.Endpoint != tc.expected.Endpoint {
				t.Errorf("Expected Endpoint %s, got %s", tc.expected.Endpoint, cfg.Realtime.Endpoint)
			}
			if cfg.Realtime.APIKey != tc.expected.APIKey {
				t.Errorf("Expected APIKey %s, got %s", tc.expected.APIKey, cfg.Realtime.APIKey)
			}
			if cfg.Realtime.DeploymentName != tc.expected.DeploymentName {
				t.Errorf("Expected DeploymentName %s, got %s", tc.expected.DeploymentName, cfg.Realtime.DeploymentName)
			}
			if cfg.Realtime.APIVersion != tc.expected.APIVersion {
				t.Errorf("Expected APIVersion %s, got %s", tc.expected.APIVersion, cfg.Realtime.APIVersion)
			}

			// Clean up
			for key := range tc.envVars {
				os.Unsetenv(key)
			}
		})
	}
}

func TestBackwardCompatibility(t *testing.T) {
	// Test that existing Azure config is not affected by Realtime config
	os.Setenv("AZURE_OPENAI_ENDPOINT", "https://existing.openai.azure.com/")
	os.Setenv("AZURE_OPENAI_API_KEY", "existing-key")
	os.Setenv("AZURE_OPENAI_DEPLOYMENT_NAME", "gpt-4")
	os.Setenv("AZURE_OPENAI_API_VERSION", "2024-02-15-preview")

	// Also set Realtime config
	os.Setenv("AZURE_OPENAI_REALTIME_ENDPOINT", "https://realtime.openai.azure.com/")
	os.Setenv("AZURE_OPENAI_REALTIME_API_KEY", "realtime-key")

	cfg, err := Load()
	if err != nil {
		t.Fatalf("Failed to load config: %v", err)
	}

	// Verify existing Azure config is unchanged
	if cfg.Azure.Endpoint != "https://existing.openai.azure.com/" {
		t.Errorf("Azure config was affected by Realtime config")
	}
	if cfg.Azure.APIKey != "existing-key" {
		t.Errorf("Azure config was affected by Realtime config")
	}

	// Verify Realtime config is loaded correctly
	if cfg.Realtime.Endpoint != "https://realtime.openai.azure.com/" {
		t.Errorf("Realtime config not loaded correctly")
	}
	if cfg.Realtime.APIKey != "realtime-key" {
		t.Errorf("Realtime config not loaded correctly")
	}

	// Clean up
	os.Unsetenv("AZURE_OPENAI_ENDPOINT")
	os.Unsetenv("AZURE_OPENAI_API_KEY")
	os.Unsetenv("AZURE_OPENAI_DEPLOYMENT_NAME")
	os.Unsetenv("AZURE_OPENAI_API_VERSION")
	os.Unsetenv("AZURE_OPENAI_REALTIME_ENDPOINT")
	os.Unsetenv("AZURE_OPENAI_REALTIME_API_KEY")
}
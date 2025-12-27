package config

import (
	"os"
	"time"

	"github.com/joho/godotenv"
	"gopkg.in/yaml.v3"
)

type Config struct {
	Server   ServerConfig   `yaml:"server"`
	Database DatabaseConfig `yaml:"database"`
	JWT      JWTConfig      `yaml:"jwt"`
	Azure    AzureConfig    `yaml:"azure"`
}

type ServerConfig struct {
	Port string `yaml:"port"`
	Env  string `yaml:"env"`
}

type DatabaseConfig struct {
	PostgresDSN  string `yaml:"postgres_dsn"`
	RedisAddr    string `yaml:"redis_addr"`
	RedisPassword string `yaml:"redis_password"`
}

type JWTConfig struct {
	SecretKey          string        `yaml:"secret_key"`
	AccessTokenExpiry  time.Duration `yaml:"access_token_expiry"`
	RefreshTokenExpiry   time.Duration `yaml:"refresh_token_expiry"`
}

type AzureConfig struct {
	Endpoint      string `yaml:"endpoint"`
	APIKey        string `yaml:"api_key"`
	DeploymentName string `yaml:"deployment_name"`
	APIVersion    string `yaml:"api_version"`
}

func Load() (*Config, error) {
	// Load .env file if exists
	_ = godotenv.Load()

	cfg := &Config{
		Server: ServerConfig{
			Port: getEnv("SERVER_PORT", "8080"),
			Env:  getEnv("SERVER_ENV", "development"),
		},
		Database: DatabaseConfig{
			PostgresDSN:  getEnv("POSTGRES_DSN", "postgres://user:password@localhost:5432/smart_glasses?sslmode=disable"),
			RedisAddr:    getEnv("REDIS_ADDR", "localhost:6379"),
			RedisPassword: getEnv("REDIS_PASSWORD", ""),
		},
		JWT: JWTConfig{
			SecretKey:          getEnv("JWT_SECRET_KEY", "your-secret-key-change-in-production"),
			AccessTokenExpiry:  parseDuration(getEnv("JWT_ACCESS_TOKEN_EXPIRY", "1h")),
			RefreshTokenExpiry: parseDuration(getEnv("JWT_REFRESH_TOKEN_EXPIRY", "168h")), // 7 days
		},
		Azure: AzureConfig{
			Endpoint:      getEnv("AZURE_OPENAI_ENDPOINT", ""),
			APIKey:        getEnv("AZURE_OPENAI_API_KEY", ""),
			DeploymentName: getEnv("AZURE_OPENAI_DEPLOYMENT_NAME", "gpt-4"),
			APIVersion:    getEnv("AZURE_OPENAI_API_VERSION", "2024-02-15-preview"),
		},
	}

	// Try to load from config file
	configFile := getEnv("CONFIG_FILE", "configs/config.yaml")
	if _, err := os.Stat(configFile); err == nil {
		data, err := os.ReadFile(configFile)
		if err == nil {
			if err := yaml.Unmarshal(data, cfg); err == nil {
				// Override with environment variables if set
				overrideWithEnv(cfg)
			}
		}
	}

	return cfg, nil
}

func getEnv(key, defaultValue string) string {
	if value := os.Getenv(key); value != "" {
		return value
	}
	return defaultValue
}

func parseDuration(s string) time.Duration {
	d, err := time.ParseDuration(s)
	if err != nil {
		return time.Hour
	}
	return d
}

func overrideWithEnv(cfg *Config) {
	if port := os.Getenv("SERVER_PORT"); port != "" {
		cfg.Server.Port = port
	}
	if env := os.Getenv("SERVER_ENV"); env != "" {
		cfg.Server.Env = env
	}
	if dsn := os.Getenv("POSTGRES_DSN"); dsn != "" {
		cfg.Database.PostgresDSN = dsn
	}
	if addr := os.Getenv("REDIS_ADDR"); addr != "" {
		cfg.Database.RedisAddr = addr
	}
	if pwd := os.Getenv("REDIS_PASSWORD"); pwd != "" {
		cfg.Database.RedisPassword = pwd
	}
	if secret := os.Getenv("JWT_SECRET_KEY"); secret != "" {
		cfg.JWT.SecretKey = secret
	}
	if endpoint := os.Getenv("AZURE_OPENAI_ENDPOINT"); endpoint != "" {
		cfg.Azure.Endpoint = endpoint
	}
	if key := os.Getenv("AZURE_OPENAI_API_KEY"); key != "" {
		cfg.Azure.APIKey = key
	}
	if deployment := os.Getenv("AZURE_OPENAI_DEPLOYMENT_NAME"); deployment != "" {
		cfg.Azure.DeploymentName = deployment
	}
	if version := os.Getenv("AZURE_OPENAI_API_VERSION"); version != "" {
		cfg.Azure.APIVersion = version
	}
}


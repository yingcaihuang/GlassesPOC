#!/bin/bash

# 创建环境变量文件脚本
# 用于在 VM 上创建包含所有环境变量的文件

echo "Creating environment variables file"
echo "=================================="

# 创建环境变量文件
cat > /tmp/glass/deployment.env << EOF
CONTAINER_REGISTRY=${CONTAINER_REGISTRY:-smartglassesacr}
IMAGE_NAME=${IMAGE_NAME:-smart-glasses-app}
IMAGE_TAG=${IMAGE_TAG:-latest}
AZURE_OPENAI_ENDPOINT=${AZURE_OPENAI_ENDPOINT}
AZURE_OPENAI_API_KEY=${AZURE_OPENAI_API_KEY}
AZURE_OPENAI_DEPLOYMENT_NAME=${AZURE_OPENAI_DEPLOYMENT_NAME:-gpt-4o}
AZURE_OPENAI_API_VERSION=${AZURE_OPENAI_API_VERSION:-2024-08-01-preview}
AZURE_OPENAI_REALTIME_ENDPOINT=${AZURE_OPENAI_REALTIME_ENDPOINT}
AZURE_OPENAI_REALTIME_API_KEY=${AZURE_OPENAI_REALTIME_API_KEY}
AZURE_OPENAI_REALTIME_DEPLOYMENT_NAME=${AZURE_OPENAI_REALTIME_DEPLOYMENT_NAME:-gpt-realtime}
AZURE_OPENAI_REALTIME_API_VERSION=${AZURE_OPENAI_REALTIME_API_VERSION:-2024-10-01-preview}
POSTGRES_PASSWORD=${POSTGRES_PASSWORD:-MySecurePostgresPassword123}
JWT_SECRET_KEY=${JWT_SECRET_KEY:-your-very-secure-jwt-secret-key-at-least-32-characters-long}
EOF

echo "Environment variables file created: /tmp/glass/deployment.env"
echo "File content verification (hiding sensitive info):"
cat /tmp/glass/deployment.env | sed 's/=.*/=***/' | head -10

# 设置文件权限
chmod 600 /tmp/glass/deployment.env
chown azureuser:azureuser /tmp/glass/deployment.env 2>/dev/null || true

echo "File permissions set"
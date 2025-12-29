#!/bin/bash

# 简化的 Azure VM 部署脚本
# 专门为简化的 GitHub Actions 工作流设计

set -e

echo "🚀 开始简化 Azure VM 部署"
echo "📍 脚本执行信息:"
echo "   - 当前用户: $(whoami)"
echo "   - 当前目录: $(pwd)"
echo "   - 时间: $(date)"

# 确保 Docker 服务运行
echo "🐳 确保 Docker 服务运行..."
sudo systemctl start docker
sudo systemctl enable docker

# 修复 Docker 权限
echo "🔐 修复 Docker 权限..."
sudo usermod -aG docker azureuser
sudo chmod 666 /var/run/docker.sock

# 切换到 azureuser 执行部署
echo "🔄 切换到 azureuser 执行部署..."
sudo -u azureuser bash -c '
set -e

echo "👤 现在运行用户: $(whoami)"
echo "📁 当前目录: $(pwd)"

# 设置工作目录
cd /home/azureuser
mkdir -p smart-glasses-app
cd smart-glasses-app
echo "📍 应用目录: $(pwd)"

# 检查 Docker 访问
echo "🐳 检查 Docker 访问..."
if ! docker info >/dev/null 2>&1; then
    echo "❌ Docker 无法访问，等待权限生效..."
    sleep 10
    if ! docker info >/dev/null 2>&1; then
        echo "❌ Docker 仍然无法访问"
        exit 1
    fi
fi
echo "✅ Docker 访问正常"

# 登录 ACR
echo "🔐 登录 Azure Container Registry..."
echo "$ACR_PASSWORD" | docker login $CONTAINER_REGISTRY.azurecr.io --username $CONTAINER_REGISTRY --password-stdin
echo "✅ ACR 登录成功"

# 创建迁移目录和文件
mkdir -p migrations

# 创建数据库迁移文件
cat > migrations/001_init.sql << "SQL_EOF"
-- Create users table
CREATE TABLE IF NOT EXISTS users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    username VARCHAR(50) UNIQUE NOT NULL,
    email VARCHAR(100) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Create translation_history table
CREATE TABLE IF NOT EXISTS translation_history (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    source_text TEXT NOT NULL,
    translated_text TEXT NOT NULL,
    source_language VARCHAR(10) NOT NULL,
    target_language VARCHAR(10) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Create indexes
CREATE INDEX IF NOT EXISTS idx_users_email ON users(email);
CREATE INDEX IF NOT EXISTS idx_users_username ON users(username);
CREATE INDEX IF NOT EXISTS idx_translation_history_user_id ON translation_history(user_id);
CREATE INDEX IF NOT EXISTS idx_translation_history_created_at ON translation_history(created_at);
SQL_EOF

cat > migrations/002_add_statistics.sql << "SQL2_EOF"
-- Create token usage table for OpenAI token tracking
CREATE TABLE IF NOT EXISTS token_usage (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    input_tokens INTEGER NOT NULL DEFAULT 0,
    output_tokens INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Create index for faster queries
CREATE INDEX IF NOT EXISTS idx_token_usage_user_id ON token_usage(user_id);
CREATE INDEX IF NOT EXISTS idx_token_usage_created_at ON token_usage(created_at);
SQL2_EOF

# 创建 docker-compose.yml
cat > docker-compose.yml << "COMPOSE_EOF"
services:
  postgres:
    image: postgres:15-alpine
    container_name: smart-glasses-postgres
    environment:
      POSTGRES_USER: smartglasses
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD:-smartglasses123}
      POSTGRES_DB: smart_glasses
    ports:
      - "5432:5432"
    volumes:
      - postgres_data:/var/lib/postgresql/data
      - ./migrations:/docker-entrypoint-initdb.d
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U smartglasses"]
      interval: 10s
      timeout: 5s
      retries: 5
    restart: unless-stopped

  redis:
    image: redis:7-alpine
    container_name: smart-glasses-redis
    ports:
      - "6379:6379"
    volumes:
      - redis_data:/data
    command: redis-server --appendonly yes
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 10s
      timeout: 5s
      retries: 5
    restart: unless-stopped

  app:
    image: ${CONTAINER_REGISTRY}.azurecr.io/${IMAGE_NAME}-backend:${IMAGE_TAG}
    container_name: smart-glasses-app
    environment:
      SERVER_PORT: "8080"
      SERVER_ENV: "production"
      POSTGRES_DSN: "postgres://smartglasses:${POSTGRES_PASSWORD:-smartglasses123}@postgres:5432/smart_glasses?sslmode=disable"
      REDIS_ADDR: "redis:6379"
      REDIS_PASSWORD: ""
      JWT_SECRET_KEY: "${JWT_SECRET_KEY:-change-this-in-production}"
      JWT_ACCESS_TOKEN_EXPIRY: "1h"
      JWT_REFRESH_TOKEN_EXPIRY: "168h"
      AZURE_OPENAI_ENDPOINT: "${AZURE_OPENAI_ENDPOINT}"
      AZURE_OPENAI_API_KEY: "${AZURE_OPENAI_API_KEY}"
      AZURE_OPENAI_DEPLOYMENT_NAME: "${AZURE_OPENAI_DEPLOYMENT_NAME:-gpt-4o}"
      AZURE_OPENAI_API_VERSION: "${AZURE_OPENAI_API_VERSION:-2024-08-01-preview}"
      AZURE_OPENAI_REALTIME_ENDPOINT: "${AZURE_OPENAI_REALTIME_ENDPOINT}"
      AZURE_OPENAI_REALTIME_API_KEY: "${AZURE_OPENAI_REALTIME_API_KEY}"
      AZURE_OPENAI_REALTIME_DEPLOYMENT_NAME: "${AZURE_OPENAI_REALTIME_DEPLOYMENT_NAME:-gpt-realtime}"
      AZURE_OPENAI_REALTIME_API_VERSION: "${AZURE_OPENAI_REALTIME_API_VERSION:-2024-10-01-preview}"
    ports:
      - "8080:8080"
    depends_on:
      postgres:
        condition: service_healthy
      redis:
        condition: service_healthy
    restart: unless-stopped

  frontend:
    image: ${CONTAINER_REGISTRY}.azurecr.io/${IMAGE_NAME}-frontend:${IMAGE_TAG}
    container_name: smart-glasses-frontend
    ports:
      - "3000:80"
    depends_on:
      - app
    restart: unless-stopped

volumes:
  postgres_data:
  redis_data:
COMPOSE_EOF

# 创建 .env 文件
cat > .env << "ENV_EOF"
AZURE_OPENAI_ENDPOINT=${AZURE_OPENAI_ENDPOINT}
AZURE_OPENAI_API_KEY=${AZURE_OPENAI_API_KEY}
AZURE_OPENAI_DEPLOYMENT_NAME=${AZURE_OPENAI_DEPLOYMENT_NAME}
AZURE_OPENAI_API_VERSION=${AZURE_OPENAI_API_VERSION}
AZURE_OPENAI_REALTIME_ENDPOINT=${AZURE_OPENAI_REALTIME_ENDPOINT}
AZURE_OPENAI_REALTIME_API_KEY=${AZURE_OPENAI_REALTIME_API_KEY}
AZURE_OPENAI_REALTIME_DEPLOYMENT_NAME=${AZURE_OPENAI_REALTIME_DEPLOYMENT_NAME}
AZURE_OPENAI_REALTIME_API_VERSION=${AZURE_OPENAI_REALTIME_API_VERSION}
POSTGRES_PASSWORD=${POSTGRES_PASSWORD}
JWT_SECRET_KEY=${JWT_SECRET_KEY}
CONTAINER_REGISTRY=${CONTAINER_REGISTRY}
IMAGE_NAME=${IMAGE_NAME}
IMAGE_TAG=${IMAGE_TAG}
ENV_EOF

echo "📋 文件创建成功:"
ls -la

# 停止现有服务
echo "🛑 停止现有服务..."
docker-compose down || true

# 拉取最新镜像
echo "📥 拉取最新镜像..."
docker-compose pull

# 启动服务
echo "🚀 启动服务..."
docker-compose up -d

# 等待服务启动
echo "⏳ 等待服务启动..."
sleep 20

# 检查服务状态
echo "📊 检查服务状态..."
docker-compose ps

# 显示日志
echo "📜 显示服务日志:"
docker-compose logs --tail=30

echo "✅ 部署完成!"
'

echo "✅ VM 简化部署脚本完成!"
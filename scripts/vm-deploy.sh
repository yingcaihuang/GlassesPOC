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

# 登录 ACR 使用托管身份
echo "🔐 使用托管身份登录 Azure Container Registry..."

# 检查必要的环境变量
if [ -z "$CONTAINER_REGISTRY" ]; then
    echo "❌ CONTAINER_REGISTRY 环境变量未设置"
    echo "ℹ️  使用默认值: smartglassesacr"
    CONTAINER_REGISTRY="smartglassesacr"
fi

if [ -z "$IMAGE_NAME" ]; then
    echo "❌ IMAGE_NAME 环境变量未设置"
    echo "ℹ️  使用默认值: smart-glasses-app"
    IMAGE_NAME="smart-glasses-app"
fi

if [ -z "$IMAGE_TAG" ]; then
    echo "❌ IMAGE_TAG 环境变量未设置"
    echo "ℹ️  尝试获取最新镜像标签..."
    
    # 尝试获取最新的镜像标签
    LATEST_TAG=$(az acr repository show-tags --name $CONTAINER_REGISTRY --repository ${IMAGE_NAME}-backend --orderby time_desc --output tsv | head -1 2>/dev/null || echo "")
    
    if [ -n "$LATEST_TAG" ]; then
        IMAGE_TAG="$LATEST_TAG"
        echo "ℹ️  找到最新标签: $IMAGE_TAG"
    else
        echo "ℹ️  无法获取最新标签，使用默认值: latest"
        IMAGE_TAG="latest"
    fi
fi

echo "📋 使用的配置:"
echo "   - CONTAINER_REGISTRY: $CONTAINER_REGISTRY"
echo "   - IMAGE_NAME: $IMAGE_NAME"
echo "   - IMAGE_TAG: $IMAGE_TAG"

# 首先安装 Azure CLI（如果还没有安装）
if ! command -v az &> /dev/null; then
    echo "安装 Azure CLI..."
    curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash
fi

# 使用托管身份登录 Azure
echo "使用托管身份登录 Azure..."
if az login --identity; then
    echo "✅ 托管身份登录成功"
    
    # 登录到 ACR
    echo "登录到 ACR: $CONTAINER_REGISTRY.azurecr.io"
    if az acr login --name $CONTAINER_REGISTRY; then
        echo "✅ ACR 登录成功"
    else
        echo "❌ ACR 登录失败"
        echo "ℹ️  可能的原因："
        echo "   1. VM 托管身份没有 AcrPull 权限"
        echo "   2. ACR 不存在或名称错误: $CONTAINER_REGISTRY"
        echo "ℹ️  请运行手动角色分配脚本: ./scripts/assign-acr-role-manual.sh"
        exit 1
    fi
else
    echo "❌ 托管身份登录失败"
    echo "ℹ️  可能的原因："
    echo "   1. VM 没有分配托管身份"
    echo "   2. 托管身份配置有问题"
    echo "ℹ️  请检查 VM 托管身份配置"
    exit 1
fi

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
    image: ${CONTAINER_REGISTRY:-smartglassesacr}.azurecr.io/${IMAGE_NAME:-smart-glasses-app}-backend:${IMAGE_TAG:-latest}
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
    image: ${CONTAINER_REGISTRY:-smartglassesacr}.azurecr.io/${IMAGE_NAME:-smart-glasses-app}-frontend:${IMAGE_TAG:-latest}
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

# 清理旧的数据库数据（强制重新初始化）
echo "🗑️ 清理旧的数据库数据..."
docker volume rm smart-glasses-app_postgres_data 2>/dev/null || true

# 拉取最新镜像
echo "📥 拉取最新镜像..."
# 先尝试拉取，如果失败则检查可用的镜像标签
if ! docker-compose pull; then
    echo "⚠️  镜像拉取失败，尝试查找可用的镜像标签..."
    
    # 尝试获取最新的镜像标签
    echo "🔍 查找最新的镜像标签..."
    AVAILABLE_TAG=$(az acr repository show-tags --name $CONTAINER_REGISTRY --repository ${IMAGE_NAME}-backend --orderby time_desc --output tsv | head -1 2>/dev/null || echo "")
    
    if [ -n "$AVAILABLE_TAG" ]; then
        echo "✅ 找到可用标签: $AVAILABLE_TAG"
        echo "🔄 更新 IMAGE_TAG 并重新创建配置文件..."
        
        # 更新环境变量
        export IMAGE_TAG="$AVAILABLE_TAG"
        
        # 重新创建 .env 文件
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
        
        # 重新创建 docker-compose.yml 使用新标签
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
    image: ${CONTAINER_REGISTRY:-smartglassesacr}.azurecr.io/${IMAGE_NAME:-smart-glasses-app}-backend:${IMAGE_TAG}
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
    image: ${CONTAINER_REGISTRY:-smartglassesacr}.azurecr.io/${IMAGE_NAME:-smart-glasses-app}-frontend:${IMAGE_TAG}
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
        
        echo "🔄 使用新标签重新拉取镜像..."
        docker-compose pull
    else
        echo "❌ 无法找到可用的镜像标签"
        echo "ℹ️  请检查 ACR 中是否有镜像"
        exit 1
    fi
fi

# 启动服务
echo "🚀 启动服务..."
docker-compose up -d

# 等待服务启动
echo "⏳ 等待服务启动..."
sleep 30

# 检查服务状态
echo "📊 检查服务状态..."
docker-compose ps

# 强制执行数据库迁移
echo "🔧 强制执行数据库迁移..."
echo "⏳ 等待 PostgreSQL 完全启动..."
sleep 10

# 检查 PostgreSQL 是否准备就绪
for i in {1..30}; do
    if docker-compose exec -T postgres pg_isready -U smartglasses >/dev/null 2>&1; then
        echo "✅ PostgreSQL 已准备就绪"
        break
    else
        echo "⏳ 等待 PostgreSQL... (尝试 $i/30)"
        sleep 2
    fi
done

# 执行数据库迁移
echo "📝 执行数据库迁移脚本..."
docker-compose exec -T postgres psql -U smartglasses -d smart_glasses << "MIGRATION_SQL"
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

-- Create token usage table for OpenAI token tracking
CREATE TABLE IF NOT EXISTS token_usage (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    input_tokens INTEGER NOT NULL DEFAULT 0,
    output_tokens INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Create indexes
CREATE INDEX IF NOT EXISTS idx_users_email ON users(email);
CREATE INDEX IF NOT EXISTS idx_users_username ON users(username);
CREATE INDEX IF NOT EXISTS idx_translation_history_user_id ON translation_history(user_id);
CREATE INDEX IF NOT EXISTS idx_translation_history_created_at ON translation_history(created_at);
CREATE INDEX IF NOT EXISTS idx_token_usage_user_id ON token_usage(user_id);
CREATE INDEX IF NOT EXISTS idx_token_usage_created_at ON token_usage(created_at);

-- Show created tables
\dt
MIGRATION_SQL

echo "✅ 数据库迁移执行完成"

# 验证表是否创建成功
echo "🔍 验证数据库表..."
docker-compose exec -T postgres psql -U smartglasses -d smart_glasses -c "\dt" || echo "⚠️  无法列出表"

# 测试数据库连接
echo "🧪 测试数据库连接..."
docker-compose exec -T postgres psql -U smartglasses -d smart_glasses -c "SELECT '\''Database connection successful'\'' as status;" || echo "⚠️  数据库连接测试失败"

# 显示应用日志
echo "📜 显示应用日志:"
docker-compose logs --tail=20 app

echo "✅ 部署完成!"
'

echo "✅ VM 简化部署脚本完成!"
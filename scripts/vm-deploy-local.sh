#!/bin/bash

# Azure VM 本地部署脚本
# 不依赖网络下载，所有配置都在脚本中

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

print_header() {
    echo -e "${BLUE}🚀 $1${NC}"
    echo "=================================================="
}

# 主部署函数
main() {
    print_header "开始 Azure VM 本地部署"
    
    print_info "脚本执行信息:"
    echo "   - 当前用户: $(whoami)"
    echo "   - 当前目录: $(pwd)"
    echo "   - 家目录: $HOME"
    echo "   - 用户ID: $(id)"
    echo "   - 时间: $(date)"
    
    # 确保 Docker 服务运行
    print_info "确保 Docker 服务运行..."
    sudo systemctl start docker
    sudo systemctl enable docker
    
    # 修复 Docker 权限
    print_info "修复 Docker 权限..."
    sudo usermod -aG docker azureuser
    sudo chmod 666 /var/run/docker.sock
    
    # 切换到 azureuser 执行部署
    print_info "切换到 azureuser 执行部署..."
    sudo -u azureuser bash << 'DEPLOY_EOF'
        set -e
        
        echo "👤 现在运行用户: $(whoami)"
        echo "📁 当前目录: $(pwd)"
        echo "🏠 家目录: $HOME"
        echo "🆔 用户ID信息: $(id)"
        
        # 设置工作目录
        echo "📂 切换到家目录..."
        cd /home/azureuser
        echo "📍 当前工作目录: $(pwd)"
        
        # 创建应用目录
        echo "📁 创建应用目录..."
        mkdir -p smart-glasses-app
        cd smart-glasses-app
        echo "📍 应用目录: $(pwd)"
        echo "📋 部署前目录内容:"
        ls -la || echo "目录为空"
        
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
        echo "   - Registry: $CONTAINER_REGISTRY.azurecr.io"
        echo "   - Username: $CONTAINER_REGISTRY"
        echo "$ACR_PASSWORD" | docker login $CONTAINER_REGISTRY.azurecr.io --username $CONTAINER_REGISTRY --password-stdin
        echo "✅ ACR 登录成功"
        
        # 创建迁移目录和文件
        echo "📁 创建迁移目录: $(pwd)/migrations"
        mkdir -p migrations
        
        # 创建数据库迁移文件
        echo "📝 创建数据库迁移文件..."
        cat > migrations/001_init.sql << 'SQL_EOF'
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
        
        cat > migrations/002_add_statistics.sql << 'SQL2_EOF'
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
        echo "📝 创建 docker-compose.yml..."
        cat > docker-compose.yml << 'COMPOSE_EOF'
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
        echo "📝 创建 .env 文件: $(pwd)/.env"
        cat > .env << 'ENV_EOF'
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
        echo "   - 工作目录: $(pwd)"
        echo "   - 目录内容:"
        ls -la
        echo "   - 迁移目录:"
        ls -la migrations/ || echo "迁移目录未找到"
        
        # 停止现有服务
        echo "🛑 停止现有服务..."
        echo "   - 执行: docker-compose down"
        echo "   - 工作目录: $(pwd)"
        docker-compose down || true
        
        # 拉取最新镜像
        echo "📥 拉取最新镜像..."
        echo "   - 执行: docker-compose pull"
        echo "   - 工作目录: $(pwd)"
        docker-compose pull
        
        # 启动服务
        echo "🚀 启动服务..."
        echo "   - 执行: docker-compose up -d"
        echo "   - 工作目录: $(pwd)"
        echo "   - 用户: $(whoami)"
        docker-compose up -d
        
        # 等待服务启动
        echo "⏳ 等待服务启动..."
        sleep 15
        
        # 检查服务状态
        echo "📊 检查服务状态..."
        echo "   - 执行: docker-compose ps"
        echo "   - 工作目录: $(pwd)"
        docker-compose ps
        
        # 等待更长时间并再次检查
        echo "⏳ 等待服务稳定..."
        sleep 15
        
        echo "📊 再次检查服务状态..."
        docker-compose ps
        
        # 显示详细日志
        echo "📜 显示服务日志:"
        echo "   - 执行: docker-compose logs --tail=50"
        echo "   - 工作目录: $(pwd)"
        docker-compose logs --tail=50
        
        # 检查各个服务健康状态
        echo "🏥 检查各个服务健康状态..."
        
        # 检查 PostgreSQL
        echo "🔍 PostgreSQL 健康检查:"
        if docker-compose exec -T postgres pg_isready -U smartglasses; then
            echo "✅ PostgreSQL 准备就绪"
            
            # 检查数据库表
            echo "🔍 检查数据库表:"
            docker-compose exec -T postgres psql -U smartglasses -d smart_glasses -c "\dt" || echo "⚠️  无法列出表"
        else
            echo "❌ PostgreSQL 未准备就绪"
        fi
        
        # 检查 Redis
        echo "🔍 Redis 健康检查:"
        if docker-compose exec -T redis redis-cli ping; then
            echo "✅ Redis 准备就绪"
        else
            echo "❌ Redis 未准备就绪"
        fi
        
        # 检查后端是否响应
        echo "🔍 后端健康检查:"
        if curl -f http://localhost:8080/health 2>/dev/null; then
            echo "✅ 后端正在响应"
        else
            echo "❌ 后端未响应"
            echo "📜 后端日志:"
            docker-compose logs app --tail=20 || true
        fi
        
        echo "✅ 部署完成!"
        echo "📍 最终状态:"
        echo "   - 用户: $(whoami)"
        echo "   - 目录: $(pwd)"
        echo "   - 创建的文件:"
        ls -la
DEPLOY_EOF
    
    print_success "VM 本地部署脚本完成!"
    echo "📍 脚本完成用户: $(whoami)"
}

# 运行主函数
main "$@"
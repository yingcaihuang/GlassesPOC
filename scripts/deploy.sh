#!/bin/bash

# 智能眼镜应用部署脚本
# 用于 Azure VM 生产环境部署

set -e

echo "🚀 开始部署智能眼镜应用..."

# 检查 Docker 和 Docker Compose
if ! command -v docker &> /dev/null; then
    echo "❌ Docker 未安装，请先安装 Docker"
    exit 1
fi

if ! command -v docker-compose &> /dev/null; then
    echo "❌ Docker Compose 未安装，请先安装 Docker Compose"
    exit 1
fi

# 检查 Git
if ! command -v git &> /dev/null; then
    echo "❌ Git 未安装，请先安装 Git"
    exit 1
fi

# 如果在 Git 仓库中，拉取最新代码
if [ -d ".git" ]; then
    echo "📥 拉取最新代码..."
    git pull origin main || git pull origin master || echo "⚠️  无法拉取代码，使用当前版本"
fi

# 清理不需要的文件
echo "🧹 清理不需要的文件..."
rm -f test-*.html test-*.sh diagnose-*.sh final-verification.sh websocket-debug.html
rm -f *-REPORT.md *-FIX*.md *-SUCCESS*.md *-COMPLETE*.md
rm -f AUDIO-*.md CALL-STACK-*.md CONTINUOUS-*.md DOCKER-*.md
rm -f FIX-*.md GPT-*.md LOCAL-*.md QUICK*.md REALTIME-*.md
rm -f SCRIPTPROCESSOR-*.md SECURITY-*.md SETUP-*.md START-*.md
rm -f STATISTICS-*.md SYSTEM-*.md TASK-*.md WEB-AUDIO-*.md
rm -f checkpoint-*.md

# 检查环境变量文件
if [ ! -f ".env" ]; then
    echo "⚠️  .env 文件不存在，创建默认配置..."
    cat > .env << 'EOF'
# 请配置以下环境变量
AZURE_OPENAI_ENDPOINT=
AZURE_OPENAI_API_KEY=
AZURE_OPENAI_DEPLOYMENT_NAME=gpt-4o
AZURE_OPENAI_API_VERSION=2024-08-01-preview

AZURE_OPENAI_REALTIME_ENDPOINT=
AZURE_OPENAI_REALTIME_API_KEY=
AZURE_OPENAI_REALTIME_DEPLOYMENT_NAME=gpt-realtime
AZURE_OPENAI_REALTIME_API_VERSION=2024-10-01-preview

# 生产环境密码（请修改）
POSTGRES_PASSWORD=smartglasses123
JWT_SECRET_KEY=change-this-in-production
EOF
    echo "📝 请编辑 .env 文件配置必要的环境变量"
    exit 1
fi

# 停止现有服务
echo "🛑 停止现有服务..."
docker-compose -f docker-compose.production.yml down || true

# 清理旧镜像
echo "🧹 清理旧镜像..."
docker image prune -f

# 构建并启动服务
echo "🔨 构建并启动服务..."
docker-compose -f docker-compose.production.yml up -d --build

# 等待服务启动
echo "⏳ 等待服务启动..."
sleep 30

# 检查服务状态
echo "🔍 检查服务状态..."
docker-compose -f docker-compose.production.yml ps

# 健康检查
echo "🏥 执行健康检查..."
max_attempts=30
attempt=1

while [ $attempt -le $max_attempts ]; do
    if curl -f http://localhost:8080/health > /dev/null 2>&1; then
        echo "✅ 后端服务健康检查通过"
        break
    else
        echo "⏳ 等待后端服务启动... ($attempt/$max_attempts)"
        sleep 2
        ((attempt++))
    fi
done

if [ $attempt -gt $max_attempts ]; then
    echo "❌ 后端服务启动失败"
    docker-compose -f docker-compose.production.yml logs app
    exit 1
fi

# 检查前端服务
if curl -f http://localhost:3000 > /dev/null 2>&1; then
    echo "✅ 前端服务访问正常"
else
    echo "❌ 前端服务访问失败"
    docker-compose -f docker-compose.production.yml logs frontend
    exit 1
fi

echo ""
echo "🎉 部署完成！"
echo ""
echo "📱 应用访问地址:"
echo "   前端: http://localhost:3000"
echo "   后端: http://localhost:8080"
echo ""
echo "🔧 管理命令:"
echo "   查看日志: docker-compose -f docker-compose.production.yml logs -f"
echo "   停止服务: docker-compose -f docker-compose.production.yml down"
echo "   重启服务: docker-compose -f docker-compose.production.yml restart"
echo ""
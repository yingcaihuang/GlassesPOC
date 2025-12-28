#!/bin/bash

# GPT Realtime API 开发环境启动脚本

echo "🚀 启动 GPT Realtime API 开发环境..."

# 检查环境变量
if [ ! -f .env ]; then
    echo "❌ 未找到 .env 文件，请先配置环境变量"
    echo "📝 复制 .env.example 到 .env 并配置 Azure OpenAI 信息"
    exit 1
fi

# 检查 Go 依赖
echo "📦 检查 Go 依赖..."
go mod tidy

# 检查前端依赖
echo "📦 检查前端依赖..."
cd frontend
if [ ! -d node_modules ]; then
    echo "📥 安装前端依赖..."
    npm install
fi
cd ..

# 启动数据库服务（如果使用 Docker）
echo "🗄️ 启动数据库服务..."
if command -v docker-compose &> /dev/null; then
    docker-compose -f docker-compose.dev.yml up -d postgres redis
    echo "⏳ 等待数据库启动..."
    sleep 5
else
    echo "⚠️ 未找到 docker-compose，请确保 PostgreSQL 和 Redis 已启动"
fi

# 启动后端服务
echo "🔧 启动后端服务..."
go run cmd/server/main.go &
BACKEND_PID=$!

# 等待后端启动
echo "⏳ 等待后端服务启动..."
sleep 3

# 启动前端开发服务器
echo "🎨 启动前端开发服务器..."
cd frontend
npm run dev &
FRONTEND_PID=$!
cd ..

echo "✅ 开发环境启动完成！"
echo ""
echo "🌐 前端地址: http://localhost:5173"
echo "🔗 后端地址: http://localhost:8080"
echo "🎤 实时语音对话: http://localhost:5173/realtime-chat"
echo ""
echo "📋 测试步骤:"
echo "1. 访问 http://localhost:5173/login 登录系统"
echo "2. 进入实时语音对话页面"
echo "3. 点击'开始录音'按钮测试语音功能"
echo ""
echo "🛑 停止服务: Ctrl+C"

# 等待用户中断
trap "echo '🛑 正在停止服务...'; kill $BACKEND_PID $FRONTEND_PID 2>/dev/null; exit" INT

# 保持脚本运行
wait
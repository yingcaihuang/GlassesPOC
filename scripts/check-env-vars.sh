#!/bin/bash

# 快速检查环境变量脚本
# 用于验证 GitHub Secrets 是否正确传递到 VM

echo "🔍 检查环境变量传递情况"
echo "=================================="

echo "📍 当前目录: $(pwd)"
echo "👤 当前用户: $(whoami)"
echo ""

echo "🔧 检查环境变量:"
echo "CONTAINER_REGISTRY: ${CONTAINER_REGISTRY:-未设置}"
echo "IMAGE_NAME: ${IMAGE_NAME:-未设置}"
echo "IMAGE_TAG: ${IMAGE_TAG:-未设置}"
echo ""

echo "🌐 Azure OpenAI 配置:"
if [ -n "$AZURE_OPENAI_ENDPOINT" ]; then
    echo "✅ AZURE_OPENAI_ENDPOINT: ${AZURE_OPENAI_ENDPOINT:0:30}..."
else
    echo "❌ AZURE_OPENAI_ENDPOINT: 未设置"
fi

if [ -n "$AZURE_OPENAI_API_KEY" ]; then
    echo "✅ AZURE_OPENAI_API_KEY: ${AZURE_OPENAI_API_KEY:0:10}..."
else
    echo "❌ AZURE_OPENAI_API_KEY: 未设置"
fi

echo "AZURE_OPENAI_DEPLOYMENT_NAME: ${AZURE_OPENAI_DEPLOYMENT_NAME:-未设置}"
echo "AZURE_OPENAI_API_VERSION: ${AZURE_OPENAI_API_VERSION:-未设置}"
echo ""

echo "🔄 Azure OpenAI Realtime 配置:"
if [ -n "$AZURE_OPENAI_REALTIME_ENDPOINT" ]; then
    echo "✅ AZURE_OPENAI_REALTIME_ENDPOINT: ${AZURE_OPENAI_REALTIME_ENDPOINT:0:30}..."
else
    echo "❌ AZURE_OPENAI_REALTIME_ENDPOINT: 未设置"
fi

if [ -n "$AZURE_OPENAI_REALTIME_API_KEY" ]; then
    echo "✅ AZURE_OPENAI_REALTIME_API_KEY: ${AZURE_OPENAI_REALTIME_API_KEY:0:10}..."
else
    echo "❌ AZURE_OPENAI_REALTIME_API_KEY: 未设置"
fi

echo "AZURE_OPENAI_REALTIME_DEPLOYMENT_NAME: ${AZURE_OPENAI_REALTIME_DEPLOYMENT_NAME:-未设置}"
echo "AZURE_OPENAI_REALTIME_API_VERSION: ${AZURE_OPENAI_REALTIME_API_VERSION:-未设置}"
echo ""

echo "🔐 安全配置:"
if [ -n "$POSTGRES_PASSWORD" ]; then
    echo "✅ POSTGRES_PASSWORD: ***"
else
    echo "❌ POSTGRES_PASSWORD: 未设置"
fi

if [ -n "$JWT_SECRET_KEY" ]; then
    echo "✅ JWT_SECRET_KEY: ***"
else
    echo "❌ JWT_SECRET_KEY: 未设置"
fi

echo ""
echo "📄 检查 .env 文件:"
if [ -f "/tmp/glass/.env" ]; then
    echo "✅ /tmp/glass/.env 文件存在"
    echo "📝 文件内容（隐藏敏感信息）:"
    cat /tmp/glass/.env | sed 's/=.*/=***/' | head -10
else
    echo "❌ /tmp/glass/.env 文件不存在"
fi

echo ""
echo "🐳 检查 Docker 容器环境变量:"
if command -v docker >/dev/null 2>&1; then
    if docker ps | grep -q glass-app; then
        echo "✅ glass-app 容器正在运行"
        echo "📋 容器环境变量（部分）:"
        docker exec glass-app env | grep -E "AZURE_OPENAI|POSTGRES|JWT" | sed 's/=.*/=***/' || echo "无法获取容器环境变量"
    else
        echo "❌ glass-app 容器未运行"
    fi
else
    echo "❌ Docker 命令不可用"
fi

echo ""
echo "✅ 环境变量检查完成"
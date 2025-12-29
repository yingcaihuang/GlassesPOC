#!/bin/bash

# 手动部署脚本
# 用于在 VM 上手动测试部署过程

set -e

echo "🔧 手动部署测试"
echo "=================================="

# 检查是否在正确的目录
if [ ! -f "/tmp/glass/vm-deploy.sh" ]; then
    echo "❌ 请先确保在 /tmp/glass 目录下，并且 vm-deploy.sh 存在"
    echo "当前目录: $(pwd)"
    echo "可用文件:"
    ls -la /tmp/glass/ 2>/dev/null || echo "/tmp/glass 目录不存在"
    exit 1
fi

cd /tmp/glass

echo "📍 当前目录: $(pwd)"
echo "👤 当前用户: $(whoami)"

# 设置基本环境变量（用于测试）
export CONTAINER_REGISTRY="smartglassesacr"
export IMAGE_NAME="smart-glasses-app"
export IMAGE_TAG="latest"

# 这些需要从 GitHub Secrets 获取，这里设置为空进行测试
export AZURE_OPENAI_ENDPOINT=""
export AZURE_OPENAI_API_KEY=""
export AZURE_OPENAI_DEPLOYMENT_NAME="gpt-4o"
export AZURE_OPENAI_API_VERSION="2024-08-01-preview"
export AZURE_OPENAI_REALTIME_ENDPOINT=""
export AZURE_OPENAI_REALTIME_API_KEY=""
export AZURE_OPENAI_REALTIME_DEPLOYMENT_NAME="gpt-realtime"
export AZURE_OPENAI_REALTIME_API_VERSION="2024-10-01-preview"
export POSTGRES_PASSWORD="testpassword123"
export JWT_SECRET_KEY="test-jwt-secret-key-for-manual-testing-only"

echo "⚠️  注意: 这是手动测试，环境变量可能不完整"
echo "🔍 检查环境变量:"
./check-env-vars.sh

echo ""
echo "🚀 开始执行部署脚本:"
if ./vm-deploy.sh; then
    echo "✅ 部署脚本执行成功"
    echo ""
    echo "🔍 部署后状态检查:"
    ./debug-deployment.sh
else
    echo "❌ 部署脚本执行失败"
    echo ""
    echo "🔍 收集调试信息:"
    ./debug-deployment.sh
    exit 1
fi

echo ""
echo "✅ 手动部署测试完成"
echo "ℹ️  如果需要完整的环境变量，请通过 GitHub Actions 部署"
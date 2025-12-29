#!/bin/bash

# 部署调试脚本
# 用于检查部署状态和问题排查

echo "🔍 Glass 部署状态调试"
echo "=================================="

echo "📍 当前目录: $(pwd)"
echo "👤 当前用户: $(whoami)"
echo "🕐 当前时间: $(date)"
echo ""

echo "📁 /tmp/glass 目录状态:"
if [ -d "/tmp/glass" ]; then
    echo "✅ /tmp/glass 目录存在"
    echo "📋 目录内容:"
    ls -la /tmp/glass/
    echo ""
    
    echo "🔍 检查脚本文件:"
    for script in vm-deploy.sh glass-manager.sh check-env-vars.sh; do
        if [ -f "/tmp/glass/$script" ]; then
            echo "✅ $script 存在 ($(stat -c%s /tmp/glass/$script) bytes)"
        else
            echo "❌ $script 不存在"
        fi
    done
    echo ""
    
    echo "🔍 检查生成的文件:"
    for file in docker-compose.yml .env; do
        if [ -f "/tmp/glass/$file" ]; then
            echo "✅ $file 存在"
        else
            echo "❌ $file 不存在"
        fi
    done
    
    if [ -d "/tmp/glass/migrations" ]; then
        echo "✅ migrations 目录存在"
        ls -la /tmp/glass/migrations/
    else
        echo "❌ migrations 目录不存在"
    fi
else
    echo "❌ /tmp/glass 目录不存在"
fi

echo ""
echo "🐳 Docker 状态:"
if command -v docker >/dev/null 2>&1; then
    echo "✅ Docker 命令可用"
    echo "🔍 Docker 服务状态:"
    systemctl is-active docker || echo "Docker 服务未运行"
    
    echo "🔍 Docker 容器:"
    docker ps -a | grep glass || echo "没有找到 glass 相关容器"
    
    echo "🔍 Docker 卷:"
    docker volume ls | grep glass || echo "没有找到 glass 相关卷"
else
    echo "❌ Docker 命令不可用"
fi

echo ""
echo "🔍 环境变量检查:"
echo "CONTAINER_REGISTRY: ${CONTAINER_REGISTRY:-未设置}"
echo "IMAGE_NAME: ${IMAGE_NAME:-未设置}"
echo "IMAGE_TAG: ${IMAGE_TAG:-未设置}"

if [ -n "$AZURE_OPENAI_ENDPOINT" ]; then
    echo "✅ AZURE_OPENAI_ENDPOINT: ${AZURE_OPENAI_ENDPOINT:0:30}..."
else
    echo "❌ AZURE_OPENAI_ENDPOINT: 未设置"
fi

echo ""
echo "📜 检查系统日志 (最近的错误):"
journalctl --since "10 minutes ago" | grep -i error | tail -5 || echo "没有找到最近的错误日志"

echo ""
echo "🔍 检查 Azure CLI:"
if command -v az >/dev/null 2>&1; then
    echo "✅ Azure CLI 可用"
    az account show --query "name" -o tsv 2>/dev/null || echo "Azure CLI 未登录"
else
    echo "❌ Azure CLI 不可用"
fi

echo ""
echo "✅ 调试信息收集完成"
#!/bin/bash

# 创建环境变量文件脚本
# 用于在 VM 上创建包含所有环境变量的文件

echo "📝 创建环境变量文件"
echo "=================================="

# 创建环境变量文件
cat > /tmp/glass/deployment.env << EOF
CONTAINER_REGISTRY=${CONTAINER_REGISTRY}
IMAGE_NAME=${IMAGE_NAME}
IMAGE_TAG=${IMAGE_TAG}
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
EOF

echo "✅ 环境变量文件已创建: /tmp/glass/deployment.env"
echo "🔍 文件内容验证（隐藏敏感信息）:"
cat /tmp/glass/deployment.env | sed 's/=.*/=***/' | head -10

# 设置文件权限
chmod 600 /tmp/glass/deployment.env
chown azureuser:azureuser /tmp/glass/deployment.env

echo "✅ 文件权限已设置"
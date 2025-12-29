#!/bin/bash

# 使用最新镜像部署脚本

set -e

# 配置变量
RESOURCE_GROUP="smart-glasses-rg"
VM_NAME="smart-glasses-vm"
CONTAINER_REGISTRY="smartglassesacr"
IMAGE_NAME="smart-glasses-app"
# 使用我们看到的最新镜像标签
IMAGE_TAG="6f7244dc61e567bbed02ce6f82a3586aa2782869"

echo "🚀 使用最新镜像部署"
echo "=================================================="
echo "📋 使用的配置:"
echo "   - CONTAINER_REGISTRY: $CONTAINER_REGISTRY"
echo "   - IMAGE_NAME: $IMAGE_NAME"
echo "   - IMAGE_TAG: $IMAGE_TAG"

# 检查 Azure CLI
if ! command -v az &> /dev/null; then
    echo "❌ Azure CLI 未安装"
    exit 1
fi

if ! az account show &>/dev/null; then
    echo "❌ 未登录 Azure，请先运行 'az login'"
    exit 1
fi

echo "✅ Azure CLI 检查通过"

# 在 VM 上运行部署脚本
echo "📤 在 VM 上运行部署脚本..."
az vm run-command invoke \
    --resource-group "$RESOURCE_GROUP" \
    --name "$VM_NAME" \
    --command-id RunShellScript \
    --scripts "
        # 设置环境变量
        export CONTAINER_REGISTRY='$CONTAINER_REGISTRY'
        export IMAGE_NAME='$IMAGE_NAME'
        export IMAGE_TAG='$IMAGE_TAG'
        export POSTGRES_PASSWORD='smartglasses123'
        export JWT_SECRET_KEY='your-secret-key-here'
        export AZURE_OPENAI_ENDPOINT='your-endpoint'
        export AZURE_OPENAI_API_KEY='your-key'
        
        # 下载并运行部署脚本
        curl -s -o /tmp/vm-deploy.sh https://raw.githubusercontent.com/yingcaihuang/GlassesPOC/main/scripts/vm-deploy.sh
        chmod +x /tmp/vm-deploy.sh
        /tmp/vm-deploy.sh
    "

echo "✅ 部署完成！"
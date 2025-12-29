#!/bin/bash

# 快速 VM 检查脚本

RESOURCE_GROUP="smart-glasses-rg"
VM_NAME="smart-glasses-vm"

echo "🔍 快速检查 VM 状态..."

# 检查 Docker 容器状态
echo "检查 Docker 容器..."
az vm run-command invoke \
    --resource-group "$RESOURCE_GROUP" \
    --name "$VM_NAME" \
    --command-id RunShellScript \
    --scripts "cd /home/azureuser/smart-glasses-app && docker-compose ps" \
    --output table
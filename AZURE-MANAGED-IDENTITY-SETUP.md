# Azure 托管身份配置指南

## 🎯 概述

使用 Azure 托管身份（Managed Identity）是访问 Azure Container Registry (ACR) 的最佳实践，它提供了安全、无密码的认证方式。

## 🔐 托管身份的优势

### ✅ 安全性
- **无密码存储** - 不需要在代码或配置中存储密码
- **自动轮换** - Azure 自动管理身份凭据
- **最小权限** - 只授予必要的访问权限

### ✅ 简化管理
- **无需手动管理** - Azure 自动处理身份验证
- **减少配置错误** - 消除密码相关的配置问题
- **统一身份管理** - 与 Azure RBAC 集成

### ✅ 成本效益
- **免费功能** - 托管身份不产生额外费用
- **减少运维成本** - 自动化身份管理

## 🚀 配置步骤

### 1. 自动配置（推荐）
新的 GitHub Actions 工作流会自动配置托管身份：

```yaml
# 创建 VM 时自动分配托管身份
az vm create --assign-identity

# 为现有 VM 分配托管身份
az vm identity assign --resource-group $RESOURCE_GROUP --name $VM_NAME

# 授予 ACR 访问权限
az role assignment create --assignee $VM_PRINCIPAL_ID --role AcrPull --scope $ACR_ID
```

### 2. 手动配置现有 VM
如果你有现有的 VM，可以运行配置脚本：

```bash
# 运行托管身份配置脚本
./scripts/setup-vm-managed-identity.sh
```

这个脚本会：
- 为 VM 分配系统托管身份
- 授予 VM 访问 ACR 的权限
- 在 VM 上安装 Azure CLI
- 测试托管身份登录和 ACR 访问

## 🔧 工作原理

### 1. 系统托管身份
```bash
# VM 获得一个由 Azure 管理的身份
VM_PRINCIPAL_ID=$(az vm identity show --query principalId --output tsv)
```

### 2. 角色分配
```bash
# 为 VM 身份分配 AcrPull 角色
az role assignment create \
  --assignee $VM_PRINCIPAL_ID \
  --role AcrPull \
  --scope $ACR_ID
```

### 3. 在 VM 上使用
```bash
# 使用托管身份登录 Azure
az login --identity

# 登录到 ACR
az acr login --name $CONTAINER_REGISTRY

# Docker 现在可以拉取镜像
docker pull $CONTAINER_REGISTRY.azurecr.io/image:tag
```

## 📋 部署脚本更新

### 旧方式（使用密码）
```bash
# 需要传递 ACR 密码
echo "$ACR_PASSWORD" | docker login $CONTAINER_REGISTRY.azurecr.io --username $CONTAINER_REGISTRY --password-stdin
```

### 新方式（使用托管身份）
```bash
# 使用托管身份登录 Azure
az login --identity

# 登录到 ACR（无需密码）
az acr login --name $CONTAINER_REGISTRY
```

## 🛠️ 故障排除

### 常见问题

#### 1. 托管身份未分配
**错误**: `ERROR: Please run 'az login' to setup account.`

**解决方案**:
```bash
# 检查 VM 是否有托管身份
az vm identity show --resource-group $RESOURCE_GROUP --name $VM_NAME

# 如果没有，分配托管身份
az vm identity assign --resource-group $RESOURCE_GROUP --name $VM_NAME
```

#### 2. 权限不足
**错误**: `unauthorized: authentication required`

**解决方案**:
```bash
# 检查角色分配
az role assignment list --assignee $VM_PRINCIPAL_ID --scope $ACR_ID

# 分配 AcrPull 角色
az role assignment create --assignee $VM_PRINCIPAL_ID --role AcrPull --scope $ACR_ID
```

#### 3. Azure CLI 未安装
**错误**: `az: command not found`

**解决方案**:
```bash
# 在 VM 上安装 Azure CLI
curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash
```

### 验证配置
```bash
# 在 VM 上验证托管身份
az login --identity
az account show

# 验证 ACR 访问
az acr login --name $CONTAINER_REGISTRY
docker pull $CONTAINER_REGISTRY.azurecr.io/hello-world:latest
```

## 🔍 监控和日志

### 查看托管身份状态
```bash
# 查看 VM 托管身份
az vm identity show --resource-group $RESOURCE_GROUP --name $VM_NAME

# 查看角色分配
az role assignment list --assignee $VM_PRINCIPAL_ID
```

### 查看 ACR 访问日志
```bash
# 查看 ACR 活动日志
az monitor activity-log list --resource-group $RESOURCE_GROUP --resource-type Microsoft.ContainerRegistry/registries
```

## 📚 最佳实践

### 1. 权限最小化
- 只授予必要的权限（AcrPull 而不是 Contributor）
- 使用资源级别的权限而不是订阅级别

### 2. 监控访问
- 启用 ACR 的诊断日志
- 监控异常访问模式

### 3. 定期审查
- 定期审查角色分配
- 清理不再需要的权限

## 🎉 总结

使用 Azure 托管身份的优势：
- ✅ **更安全** - 无密码认证
- ✅ **更简单** - 自动化身份管理
- ✅ **更可靠** - Azure 管理的凭据轮换
- ✅ **更经济** - 无额外费用

现在你的部署流程更加安全和简化！🚀
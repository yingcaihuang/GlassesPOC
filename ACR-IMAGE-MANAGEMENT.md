# Azure Container Registry 镜像管理

## 概述

为了避免 ACR 存储空间无限增长，我们添加了自动清理功能，只保留最新的 3 个版本，自动删除旧版本。

## 新增脚本

### 1. `scripts/cleanup-acr-images.sh`
自动清理 ACR 中的旧镜像，只保留最新的 3 个版本。

**使用方法：**
```bash
# 使用默认配置（保留 3 个版本）
./scripts/cleanup-acr-images.sh

# 自定义保留数量
KEEP_COUNT=5 ./scripts/cleanup-acr-images.sh

# 指定不同的 ACR 和镜像名
CONTAINER_REGISTRY=myacr IMAGE_NAME=myapp ./scripts/cleanup-acr-images.sh
```

### 2. `scripts/list-acr-images.sh`
查看 ACR 中当前的所有镜像和标签。

**使用方法：**
```bash
./scripts/list-acr-images.sh
```

### 3. 更新的 `scripts/build-and-push-images.sh`
构建并推送镜像后自动执行清理。

**使用方法：**
```bash
# 自动清理（默认）
./scripts/build-and-push-images.sh

# 禁用自动清理
AUTO_CLEANUP=false ./scripts/build-and-push-images.sh
```

## 自动清理策略

### 保留规则
- **保留数量**: 最新的 3 个版本（可配置）
- **排序方式**: 按创建时间降序（最新的在前）
- **清理范围**: 前端和后端镜像仓库

### 清理时机
1. **手动清理**: 运行 `cleanup-acr-images.sh`
2. **构建时自动清理**: `build-and-push-images.sh` 推送完成后
3. **CI/CD 自动清理**: GitHub Actions 部署流程中

## 配置选项

### 环境变量
```bash
# ACR 名称
CONTAINER_REGISTRY=smartglassesacr

# 镜像基础名称
IMAGE_NAME=smart-glasses-app

# 保留的版本数量
KEEP_COUNT=3

# 是否自动清理
AUTO_CLEANUP=true
```

### 镜像仓库
- **后端**: `smart-glasses-app-backend`
- **前端**: `smart-glasses-app-frontend`

## 使用示例

### 查看当前镜像状态
```bash
./scripts/list-acr-images.sh
```

输出示例：
```
📦 Listing images in Azure Container Registry: smartglassesacr

📋 All repositories in smartglassesacr:
NAME                           
smart-glasses-app-backend      
smart-glasses-app-frontend     

🔧 Backend repository (smart-glasses-app-backend):
TAG                                       CREATED_TIME         
5e688ad6d029e6acc6929aac006be1d4403dffca  2024-12-30T05:14:23Z
abc123def456789...                        2024-12-29T10:30:15Z
xyz789abc123456...                        2024-12-28T15:45:30Z
```

### 手动清理旧镜像
```bash
./scripts/cleanup-acr-images.sh
```

输出示例：
```
🧹 Starting ACR image cleanup...
📦 Container Registry: smartglassesacr
🏷️  Image Name: smart-glasses-app
📊 Keeping latest 3 versions

🔍 Cleaning up repository: smart-glasses-app-backend
📊 Found 5 tags in smart-glasses-app-backend
🔒 Keeping latest 3 tags:
   - 5e688ad6d029e6acc6929aac006be1d4403dffca
   - abc123def456789...
   - xyz789abc123456...
🗑️  Deleting older tags:
   - Deleting smart-glasses-app-backend:old-tag-1
     ✅ Deleted successfully
   - Deleting smart-glasses-app-backend:old-tag-2
     ✅ Deleted successfully
📊 Deleted 2 old tags from smart-glasses-app-backend
```

### 构建并推送（带自动清理）
```bash
# 设置服务器主机
export SERVER_HOST=your-server-ip

# 构建、推送并自动清理
./scripts/build-and-push-images.sh
```

### 禁用自动清理
```bash
AUTO_CLEANUP=false ./scripts/build-and-push-images.sh
```

## 安全注意事项

1. **权限要求**: 需要对 ACR 有删除权限
2. **备份建议**: 重要版本建议手动标记为 `stable` 或 `production`
3. **回滚考虑**: 确保保留的版本数量足够支持回滚需求

## 故障排除

### 权限错误
```bash
# 检查 Azure 登录状态
az account show

# 重新登录
az login

# 检查 ACR 访问权限
az acr repository list --name smartglassesacr
```

### 找不到镜像
```bash
# 列出所有仓库
az acr repository list --name smartglassesacr

# 检查特定仓库的标签
az acr repository show-tags --name smartglassesacr --repository smart-glasses-app-backend
```

## 成本优化

通过定期清理旧镜像：
- **减少存储成本**: ACR 按存储量计费
- **提高性能**: 减少仓库大小，提高拉取速度
- **简化管理**: 避免标签过多导致的混乱

## 自定义配置

如果需要不同的保留策略，可以修改 `KEEP_COUNT` 环境变量：

```bash
# 保留 5 个版本
KEEP_COUNT=5 ./scripts/cleanup-acr-images.sh

# 保留 10 个版本
KEEP_COUNT=10 ./scripts/cleanup-acr-images.sh
```
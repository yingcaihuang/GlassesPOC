# 部署问题排查指南

## 概述

本文档提供了 Azure VM 部署问题的排查和解决方案。基于之前遇到的问题，我们创建了多个工具来帮助诊断和修复部署问题。

## 主要改进

### 1. 增强的部署日志
- ✅ 在每个步骤显示当前用户、工作目录和执行上下文
- ✅ 详细的文件创建和位置信息
- ✅ 更全面的服务健康检查
- ✅ 扩展的错误日志输出

### 2. 数据库迁移修复
- ✅ 确保迁移脚本正确创建在 `/home/azureuser/smart-glasses-app/migrations/` 目录
- ✅ 修复了 `002_add_statistics.sql` 的内容匹配问题
- ✅ PostgreSQL 容器正确挂载迁移目录到 `/docker-entrypoint-initdb.d`

### 3. 新增诊断工具

#### 🔍 部署问题诊断脚本
```bash
./scripts/diagnose-deployment-issue.sh
```
**功能:**
- 检查 VM 状态和 Docker 配置
- 验证应用目录和文件结构
- 测试 Docker 访问权限
- 检查容器状态和镜像
- 验证网络连接

#### 🧪 部署测试脚本
```bash
./scripts/test-deployment.sh
```
**功能:**
- 测试所有服务的健康状态
- 验证 API 端点响应
- 检查数据库连接和表结构
- 提供完整的部署信息

#### 🔧 快速修复脚本
```bash
./scripts/quick-fix-deployment.sh
```
**功能:**
- 修复常见的 Docker 权限问题
- 重启 Docker 服务
- 清理容器和镜像
- 重新启动应用服务

#### 🗄️ 数据库修复脚本
```bash
./scripts/fix-database.sh
```
**功能:**
- 手动创建缺失的数据库表
- 验证数据库连接
- 执行必要的数据库迁移

## 常见问题和解决方案

### 问题 1: 容器无法启动
**症状:** GitHub Actions 显示容器启动但实际未运行
**原因:** Docker 权限问题或镜像拉取失败
**解决方案:**
```bash
# 运行快速修复脚本
./scripts/quick-fix-deployment.sh

# 然后运行诊断脚本检查状态
./scripts/diagnose-deployment-issue.sh
```

### 问题 2: 数据库表不存在
**症状:** 注册用户时报错 "relation 'users' does not exist"
**原因:** 数据库迁移脚本未正确执行
**解决方案:**
```bash
# 运行数据库修复脚本
./scripts/fix-database.sh
```

### 问题 3: 服务健康检查失败
**症状:** 健康检查端点无响应
**原因:** 服务启动时间过长或配置错误
**解决方案:**
1. 等待更长时间（已在工作流中增加等待时间）
2. 检查服务日志：
```bash
./scripts/diagnose-deployment-issue.sh
```

### 问题 4: Docker 权限错误
**症状:** "Cannot connect to the Docker daemon"
**原因:** azureuser 用户没有 Docker 访问权限
**解决方案:**
```bash
# 快速修复脚本会自动处理权限问题
./scripts/quick-fix-deployment.sh
```

## 部署流程改进

### 1. 更健壮的健康检查
- 增加重试次数和等待时间
- 详细的错误信息输出
- 多层次的服务验证

### 2. 更好的错误处理
- 在失败时自动获取服务状态
- 显示详细的容器日志
- 提供具体的修复建议

### 3. 环境变量管理
- 确保所有必要的环境变量正确传递
- 在部署脚本中验证环境变量

## 使用建议

### 部署前检查
1. 确保所有 GitHub Secrets 已正确配置
2. 验证 Azure 服务主体权限
3. 检查 ACR 访问权限

### 部署后验证
1. 运行测试脚本验证部署：
```bash
./scripts/test-deployment.sh
```

2. 如果有问题，运行诊断脚本：
```bash
./scripts/diagnose-deployment-issue.sh
```

3. 根据诊断结果运行相应的修复脚本

### 监控和维护
- 定期检查服务状态
- 监控容器资源使用情况
- 备份数据库数据

## GitHub Actions 工作流改进

### 新增功能
- ✅ 详细的执行日志
- ✅ 更长的服务启动等待时间
- ✅ 多重健康检查验证
- ✅ 失败时自动获取诊断信息
- ✅ 数据库连接验证

### 环境变量
确保以下 GitHub Secrets 已配置：
- `AZURE_CLIENT_ID`
- `AZURE_TENANT_ID`
- `AZURE_SUBSCRIPTION_ID`
- `AZURE_OPENAI_ENDPOINT`
- `AZURE_OPENAI_API_KEY`
- `AZURE_OPENAI_DEPLOYMENT_NAME`
- `AZURE_OPENAI_API_VERSION`
- `AZURE_OPENAI_REALTIME_ENDPOINT`
- `AZURE_OPENAI_REALTIME_API_KEY`
- `AZURE_OPENAI_REALTIME_DEPLOYMENT_NAME`
- `AZURE_OPENAI_REALTIME_API_VERSION`
- `POSTGRES_PASSWORD`
- `JWT_SECRET_KEY`

## 故障排除步骤

1. **检查 GitHub Actions 日志**
   - 查看详细的执行日志
   - 注意任何错误或警告信息

2. **运行诊断脚本**
   ```bash
   ./scripts/diagnose-deployment-issue.sh
   ```

3. **根据诊断结果采取行动**
   - Docker 问题 → 运行快速修复脚本
   - 数据库问题 → 运行数据库修复脚本
   - 服务问题 → 检查配置和日志

4. **验证修复结果**
   ```bash
   ./scripts/test-deployment.sh
   ```

5. **如果问题持续存在**
   - 检查 Azure 资源状态
   - 验证网络配置
   - 联系技术支持

## 总结

通过这些改进和工具，我们现在有了：
- 更详细的部署日志
- 自动化的问题诊断
- 快速的问题修复
- 全面的部署验证

这应该能够解决之前遇到的部署问题，并提供更好的可观测性和可维护性。
# 清洁部署方案

## 概述

为了解决 YAML 语法错误和复杂的内嵌脚本问题，我们重构了部署方案，将脚本逻辑分离出来，使 GitHub Actions 工作流更加简洁和易于维护。

## 新的部署架构

### 1. 分离的脚本文件
- `scripts/vm-deploy.sh` - 主要部署脚本（从 GitHub 下载）
- `scripts/vm-deploy-local.sh` - 本地备用部署脚本
- `.github/workflows/deploy-azure-vm-clean.yml` - 简化的 GitHub Actions 工作流

### 2. 工作流程
1. **构建和推送镜像** - 在 GitHub Actions 中完成
2. **VM 准备** - 检查/创建 VM，安装 Docker
3. **脚本部署** - 创建部署脚本并在 VM 上执行
4. **健康检查** - 验证服务状态

## 主要改进

### ✅ 解决的问题
- **YAML 语法错误** - 不再有复杂的内嵌脚本
- **调试困难** - 脚本逻辑清晰分离
- **维护复杂** - 每个组件职责明确
- **错误排查** - 更容易定位问题

### ✅ 新的优势
- **模块化设计** - 脚本可以独立测试和维护
- **更好的日志** - 每个步骤都有清晰的输出
- **容错机制** - 网络下载失败时有本地备用方案
- **简洁的 YAML** - GitHub Actions 工作流更易读

## 文件结构

```
.github/workflows/
├── deploy-azure-vm-clean.yml    # 新的简化工作流
└── deploy-azure-vm.yml          # 原始工作流（保留作为参考）

scripts/
├── vm-deploy.sh                 # 主要部署脚本
├── vm-deploy-local.sh           # 本地备用脚本
├── diagnose-deployment-issue.sh # 诊断工具
├── test-deployment.sh           # 测试工具
└── quick-fix-deployment.sh      # 快速修复工具
```

## 使用方法

### 1. 正常部署
使用新的工作流文件：
```bash
# 推送到 main 分支会自动触发部署
git push origin main

# 或者手动触发
# 在 GitHub Actions 页面点击 "Run workflow"
```

### 2. 本地测试脚本
```bash
# 测试部署脚本（在有 Docker 的环境中）
./scripts/vm-deploy-local.sh

# 诊断问题
./scripts/diagnose-deployment-issue.sh

# 测试部署结果
./scripts/test-deployment.sh
```

### 3. 故障排除
如果部署失败：
1. 查看 GitHub Actions 日志
2. 运行诊断脚本
3. 根据需要运行修复脚本

## 环境变量

确保以下 GitHub Secrets 已配置：

### Azure 认证
- `AZURE_CLIENT_ID`
- `AZURE_TENANT_ID` 
- `AZURE_SUBSCRIPTION_ID`

### Azure OpenAI
- `AZURE_OPENAI_ENDPOINT`
- `AZURE_OPENAI_API_KEY`
- `AZURE_OPENAI_DEPLOYMENT_NAME`
- `AZURE_OPENAI_API_VERSION`
- `AZURE_OPENAI_REALTIME_ENDPOINT`
- `AZURE_OPENAI_REALTIME_API_KEY`
- `AZURE_OPENAI_REALTIME_DEPLOYMENT_NAME`
- `AZURE_OPENAI_REALTIME_API_VERSION`

### 应用配置
- `POSTGRES_PASSWORD`
- `JWT_SECRET_KEY`

## 部署流程详解

### 1. 镜像构建阶段
```yaml
- 登录 Azure
- 检查/创建 ACR
- 构建并推送 Docker 镜像
```

### 2. VM 准备阶段
```yaml
- 检查/创建 VM
- 安装 Docker（如果是新 VM）
- 配置网络端口
```

### 3. 部署执行阶段
```yaml
- 创建部署脚本
- 传递环境变量
- 在 VM 上执行部署
```

### 4. 健康检查阶段
```yaml
- 等待服务启动
- 检查后端 API
- 检查前端访问
- 测试数据库连接
```

## 监控和维护

### 日志查看
- GitHub Actions 日志：详细的部署过程
- VM 日志：通过诊断脚本获取
- 容器日志：通过 docker-compose logs

### 定期维护
- 检查服务状态
- 更新 Docker 镜像
- 备份数据库数据
- 监控资源使用

## 故障排除指南

### 常见问题
1. **Docker 权限问题** → 运行 `quick-fix-deployment.sh`
2. **数据库表缺失** → 运行 `fix-database.sh`
3. **服务无法启动** → 运行 `diagnose-deployment-issue.sh`
4. **网络连接问题** → 检查 Azure 网络安全组配置

### 调试步骤
1. 查看 GitHub Actions 详细日志
2. 运行诊断脚本获取 VM 状态
3. 检查容器日志和状态
4. 验证环境变量配置
5. 测试网络连接

## 总结

新的清洁部署方案提供了：
- ✅ 更简洁的 GitHub Actions 工作流
- ✅ 更好的错误处理和日志记录
- ✅ 更容易的调试和维护
- ✅ 模块化的脚本设计
- ✅ 完整的故障排除工具

这个方案解决了之前的 YAML 语法问题，并提供了更好的可维护性和可观测性。
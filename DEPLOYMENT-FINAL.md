# 最终部署方案

## 🎯 概述

经过重构，我们现在有了一个简洁、可靠的 Azure VM 部署方案，完全解决了之前的 YAML 语法错误和复杂性问题。

## 📁 文件结构

### GitHub Actions 工作流
```
.github/workflows/
└── deploy-azure-vm.yml          # 唯一的部署工作流
```

### 部署脚本
```
scripts/
├── vm-deploy.sh                 # 主要部署脚本
├── diagnose-deployment-issue.sh # 诊断工具
├── test-deployment.sh           # 测试工具
├── quick-fix-deployment.sh      # 快速修复工具
├── fix-database.sh              # 数据库修复工具
└── setup-azure-auth.sh          # Azure 认证设置
```

### 配置文件
```
migrations/
├── 001_init.sql                 # 数据库初始化
└── 002_add_statistics.sql       # 统计表

docker-compose.production.yml    # 生产环境配置
```

## 🚀 部署流程

### 1. 自动部署
推送到 main 分支会自动触发部署：
```bash
git push origin main
```

### 2. 手动部署
在 GitHub Actions 页面点击 "Run workflow"

### 3. 部署步骤
1. **构建镜像** - 构建并推送 Docker 镜像到 ACR
2. **准备 VM** - 检查/创建 VM，安装 Docker
3. **上传脚本** - 从 GitHub 下载部署脚本到 VM
4. **执行部署** - 在 VM 上运行部署脚本
5. **健康检查** - 验证所有服务正常运行

## 🔧 主要改进

### ✅ 解决的问题
- **YAML 语法错误** - 完全消除复杂的内嵌脚本
- **调试困难** - 脚本逻辑清晰分离
- **维护复杂** - 模块化设计，职责明确
- **错误排查** - 详细的日志和诊断工具

### ✅ 新的优势
- **简洁的工作流** - 无复杂的 heredoc 语法
- **模块化脚本** - 可独立测试和维护
- **完整的工具链** - 诊断、测试、修复工具
- **详细的日志** - 每个步骤都有清晰输出

## 🛠️ 故障排除

### 如果部署失败：

1. **查看 GitHub Actions 日志**
   ```bash
   # 在 GitHub 仓库的 Actions 页面查看详细日志
   ```

2. **运行诊断脚本**
   ```bash
   ./scripts/diagnose-deployment-issue.sh
   ```

3. **快速修复常见问题**
   ```bash
   ./scripts/quick-fix-deployment.sh
   ```

4. **修复数据库问题**
   ```bash
   ./scripts/fix-database.sh
   ```

5. **测试部署结果**
   ```bash
   ./scripts/test-deployment.sh
   ```

## 🔐 环境变量配置

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

## 📊 监控和维护

### 访问地址
部署成功后，可以通过以下地址访问：
- **前端应用**: `http://VM_IP:3000`
- **后端 API**: `http://VM_IP:8080`
- **健康检查**: `http://VM_IP:8080/health`

### 日志查看
- **GitHub Actions**: 详细的部署过程日志
- **VM 日志**: 通过诊断脚本获取
- **容器日志**: `docker-compose logs`

### 定期维护
- 检查服务状态
- 更新 Docker 镜像
- 备份数据库
- 监控资源使用

## 🎉 总结

新的部署方案提供了：
- ✅ **零 YAML 语法错误** - 简洁的工作流设计
- ✅ **模块化架构** - 脚本分离，易于维护
- ✅ **完整的工具链** - 诊断、测试、修复工具
- ✅ **详细的日志** - 每个步骤都有清晰输出
- ✅ **可靠的部署** - 经过优化的部署流程

现在你可以安全地使用这个部署方案，不会再遇到 YAML 语法错误或复杂的调试问题！🚀
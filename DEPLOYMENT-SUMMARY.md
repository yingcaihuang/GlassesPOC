# Azure VM 自动化部署总结

## 🎯 已完成的工作

### 1. GitHub Actions 工作流（完全自动化）
- ✅ 创建了 `.github/workflows/deploy-azure-vm.yml`
- ✅ 使用 Azure 官方 Actions 和 OIDC 认证
- ✅ 自动创建和管理 Azure 资源
- ✅ 自动构建和推送 Docker 镜像到 ACR
- ✅ 使用 `az vm run-command` 在 VM 上部署应用
- ✅ 支持手动触发和自动触发部署

### 2. Azure 资源自动化管理
- ✅ 自动创建资源组 (`smart-glasses-rg`)
- ✅ 自动创建 Azure Container Registry (`smartglassesacr`)
- ✅ 自动创建和配置 VM (`smart-glasses-vm`)
- ✅ 自动配置网络安全组和端口
- ✅ 自动安装 Docker 扩展

### 3. 容器化部署
- ✅ 构建后端和前端 Docker 镜像
- ✅ 推送镜像到 Azure Container Registry
- ✅ 在 VM 上使用 Docker Compose 部署
- ✅ 自动配置生产环境变量

### 4. 文档和指南
- ✅ 更新了 `AZURE-VM-SETUP.md` - Azure 服务主体和 OIDC 配置指南
- ✅ 创建了完整的自动化部署文档
- ✅ 包含成本优化和安全最佳实践

## 🚀 部署方式

### 方式一：自动化脚本（推荐）

#### 1. 运行自动化设置脚本

```bash
./scripts/setup-azure-auth.sh
```

脚本自动完成：
- Azure 登录验证
- 创建服务主体
- 配置 OIDC 联合身份验证
- 生成 GitHub Secrets 配置文件

#### 2. 配置 GitHub Secrets

```bash
# 编辑生成的配置文件
vim github-secrets.txt

# 在 GitHub 仓库中添加 Secrets
# Settings → Secrets and variables → Actions
```

#### 3. 推送代码自动部署

```bash
git add .
git commit -m "Deploy to Azure VM"
git push origin main
```

### 方式二：手动触发部署

在 GitHub Actions 页面点击 "Run workflow" 按钮手动触发部署。

## 🏗️ 自动化流程

GitHub Actions 工作流自动执行以下步骤：

1. **Azure 认证**: 使用 OIDC 无密码认证到 Azure
2. **资源管理**: 
   - 创建资源组（如果不存在）
   - 创建 Azure Container Registry（如果不存在）
   - 创建和配置 VM（如果不存在）
3. **镜像构建**: 
   - 构建后端 Docker 镜像
   - 构建前端 Docker 镜像
   - 推送镜像到 ACR
4. **应用部署**: 
   - 使用 `az vm run-command` 在 VM 上执行部署脚本
   - 创建 Docker Compose 配置
   - 启动应用服务
5. **健康检查**: 验证前端和后端服务是否正常运行

## 📁 创建的 Azure 资源

```
smart-glasses-rg/
├── smart-glasses-vm                    # Ubuntu 22.04 VM (Standard_B2s)
├── smartglassesacr                     # Azure Container Registry
├── smart-glasses-vm-nsg                # 网络安全组
├── smart-glasses-vm-ip                 # 公共 IP 地址
├── smart-glasses-vm-vnet               # 虚拟网络
└── smart-glasses-vm-disk               # OS 磁盘
```

## 🔧 关键特性

### 完全自动化
- 无需手动创建 Azure 资源
- 无需 SSH 密钥管理
- 无需手动配置 VM

### 安全性
- 使用 OIDC 无密码认证
- 服务主体最小权限原则
- 敏感信息通过 GitHub Secrets 管理

### 可扩展性
- 支持多环境部署
- 容器化应用易于扩展
- 使用 Azure Container Registry 管理镜像

### 成本优化
- 按需创建资源
- 支持 VM 自动关机
- 可选择不同 VM 规格

## 🌐 访问地址

部署完成后，GitHub Actions 会输出访问地址：

```
🎉 Deployment completed successfully!
🌐 Frontend: http://VM_IP:3000
🔧 Backend API: http://VM_IP:8080
💚 Health Check: http://VM_IP:8080/health
```

## 💰 成本估算

| VM 规格 | vCPU | RAM | 月费用（美元） | 适用场景 |
|---------|------|-----|---------------|----------|
| Standard_B1s | 1 | 1GB | ~$7.59 | 开发测试 |
| Standard_B2s | 2 | 4GB | ~$30.37 | 小型生产 |
| Standard_D2s_v3 | 2 | 8GB | ~$70.08 | 高性能生产 |

*价格可能因地区而异，不包括存储和网络费用*

## 🔒 安全最佳实践

1. **身份验证**: 使用 OIDC 而不是长期密钥
2. **网络安全**: 配置网络安全组限制访问
3. **密钥管理**: 定期轮换 API 密钥
4. **监控**: 启用 Azure Security Center
5. **备份**: 定期备份应用数据

## 📋 管理命令

```bash
# 查看部署状态
az resource list --resource-group smart-glasses-rg --output table

# 获取 VM 公网 IP
az vm show --resource-group smart-glasses-rg --name smart-glasses-vm --show-details --query publicIps --output tsv

# 查看应用日志
az vm run-command invoke \
  --resource-group smart-glasses-rg \
  --name smart-glasses-vm \
  --command-id RunShellScript \
  --scripts "cd /home/azureuser/smart-glasses-app && docker-compose logs -f"

# 重启应用
az vm run-command invoke \
  --resource-group smart-glasses-rg \
  --name smart-glasses-vm \
  --command-id RunShellScript \
  --scripts "cd /home/azureuser/smart-glasses-app && docker-compose restart"
```

## 🎯 优势总结

### 相比传统部署方式的优势：

1. **零配置**: 无需手动创建和配置 Azure 资源
2. **安全**: 使用 OIDC 认证，无需管理 SSH 密钥
3. **自动化**: 推送代码即可完成整个部署流程
4. **可重复**: 每次部署都是一致的环境
5. **可追溯**: 所有部署操作都有日志记录
6. **成本控制**: 按需创建资源，支持自动关机

---

🎉 **现在你只需要配置 GitHub Secrets，然后 git push 就能自动部署到 Azure VM 了！**
# 智能眼镜应用 - 生产环境部署

智能眼镜后端应用，提供用户认证和 GPT 实时语音交互功能。

## 🚀 快速部署到 Azure VM

## 🚀 快速部署到 Azure VM

### 方式一：自动化脚本（推荐）

```bash
# 1. 运行自动化设置脚本
./scripts/setup-azure-auth.sh

# 2. 编辑生成的 github-secrets.txt 文件，填入 Azure OpenAI 配置

# 3. 在 GitHub 仓库中添加 Secrets（参考 github-secrets.txt）

# 4. 推送代码自动部署
git add .
git commit -m "Deploy to production"
git push origin main
```

### 方式二：手动配置

```bash
# 克隆项目
git clone https://github.com/your-username/your-repo-name.git
cd your-repo-name

# 配置环境变量
cp .env.example .env
# 编辑 .env 文件，配置 Azure OpenAI 相关参数

# 运行部署脚本
./scripts/deploy.sh
```

### 3. 访问应用

- 前端应用: http://your-vm-ip:3000
- 后端 API: http://your-vm-ip:8080
- 健康检查: http://your-vm-ip:8080/health

## 🔧 配置说明

### 必需的环境变量

```bash
# Azure OpenAI 配置
AZURE_OPENAI_ENDPOINT=https://your-resource.openai.azure.com
AZURE_OPENAI_API_KEY=your-api-key
AZURE_OPENAI_DEPLOYMENT_NAME=gpt-4o
AZURE_OPENAI_API_VERSION=2024-08-01-preview

# Azure OpenAI Realtime API 配置
AZURE_OPENAI_REALTIME_ENDPOINT=https://your-resource.cognitiveservices.azure.com
AZURE_OPENAI_REALTIME_API_KEY=your-realtime-api-key
AZURE_OPENAI_REALTIME_DEPLOYMENT_NAME=gpt-realtime
AZURE_OPENAI_REALTIME_API_VERSION=2024-10-01-preview
```

### 可选的环境变量

```bash
# 数据库密码（生产环境请修改）
POSTGRES_PASSWORD=your-secure-password

# JWT 密钥（生产环境请修改）
JWT_SECRET_KEY=your-jwt-secret-key
```

## 🔄 CI/CD 部署

项目配置了 GitHub Actions 自动部署：

1. 推送代码到 `main` 分支
2. GitHub Actions 自动部署到 Azure VM
3. 支持手动触发部署

### 配置 GitHub Secrets

在 GitHub 仓库设置中添加以下 Secrets：

```
AZURE_VM_IP=your-vm-public-ip
AZURE_VM_SSH_PRIVATE_KEY=your-ssh-private-key
AZURE_OPENAI_ENDPOINT=your-openai-endpoint
AZURE_OPENAI_API_KEY=your-openai-api-key
AZURE_OPENAI_REALTIME_ENDPOINT=your-realtime-endpoint
AZURE_OPENAI_REALTIME_API_KEY=your-realtime-api-key
```

## 📋 管理命令

```bash
# 查看服务状态
docker-compose -f docker-compose.production.yml ps

# 查看日志
docker-compose -f docker-compose.production.yml logs -f

# 重启服务
docker-compose -f docker-compose.production.yml restart

# 停止服务
docker-compose -f docker-compose.production.yml down

# 更新应用
git pull origin main
./scripts/deploy.sh
```

## 🛠️ 故障排查

### 常见问题

1. **端口访问问题**
   ```bash
   sudo ufw allow 3000
   sudo ufw allow 8080
   ```

2. **服务启动失败**
   ```bash
   docker-compose -f docker-compose.production.yml logs app
   ```

3. **数据库连接问题**
   ```bash
   docker-compose -f docker-compose.production.yml logs postgres
   ```

### 健康检查

```bash
# 检查后端服务
curl http://localhost:8080/health

# 检查前端服务
curl http://localhost:3000

# 检查数据库
docker exec smart-glasses-postgres pg_isready -U smartglasses
```

## 📚 详细文档

- [Azure VM 部署指南](AZURE-VM-SETUP.md) - 详细的 Azure VM 配置步骤
- [API 文档](README.md) - 完整的 API 接口文档

## 🔒 安全建议

1. 定期更新系统和 Docker 镜像
2. 使用强密码和密钥
3. 配置防火墙规则
4. 启用 HTTPS（生产环境）
5. 定期备份数据

## 📞 支持

如有问题，请查看：
1. [故障排查指南](AZURE-VM-SETUP.md#7-故障排查)
2. 项目 Issues
3. 应用日志

---

🎉 享受你的智能眼镜应用吧！
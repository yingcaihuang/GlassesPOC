# Azure VM 自动化部署指南

本指南将帮助你使用 GitHub Actions 和 Azure 服务主体自动化部署智能眼镜应用到 Azure VM。

## 1. 创建 Azure 服务主体和 OIDC 配置

### 1.1 通过 Azure CLI 创建服务主体

```bash
# 登录 Azure
az login

# 设置变量
SUBSCRIPTION_ID=$(az account show --query id --output tsv)
RESOURCE_GROUP="smart-glasses-rg"
APP_NAME="smart-glasses-github-actions"

# 创建服务主体
az ad sp create-for-rbac \
  --name $APP_NAME \
  --role contributor \
  --scopes /subscriptions/$SUBSCRIPTION_ID \
  --sdk-auth

# 记录输出的 JSON，包含 clientId, clientSecret, subscriptionId, tenantId
```

### 1.2 配置 OIDC 联合身份验证（推荐）

```bash
# 获取应用程序 ID
APP_ID=$(az ad app list --display-name $APP_NAME --query [0].appId --output tsv)

# 创建联合身份凭据
az ad app federated-credential create \
  --id $APP_ID \
  --parameters '{
    "name": "github-actions-main",
    "issuer": "https://token.actions.githubusercontent.com",
    "subject": "repo:YOUR_GITHUB_USERNAME/YOUR_REPO_NAME:ref:refs/heads/main",
    "audiences": ["api://AzureADTokenExchange"]
  }'

# 为 workflow_dispatch 创建另一个凭据
az ad app federated-credential create \
  --id $APP_ID \
  --parameters '{
    "name": "github-actions-manual",
    "issuer": "https://token.actions.githubusercontent.com",
    "subject": "repo:YOUR_GITHUB_USERNAME/YOUR_REPO_NAME:ref:refs/heads/main",
    "audiences": ["api://AzureADTokenExchange"]
  }'
```

### 1.3 获取必要的 ID

```bash
# 获取租户 ID
TENANT_ID=$(az account show --query tenantId --output tsv)

# 获取订阅 ID
SUBSCRIPTION_ID=$(az account show --query id --output tsv)

# 获取客户端 ID（应用程序 ID）
CLIENT_ID=$(az ad app list --display-name $APP_NAME --query [0].appId --output tsv)

echo "Tenant ID: $TENANT_ID"
echo "Subscription ID: $SUBSCRIPTION_ID"
echo "Client ID: $CLIENT_ID"
```

## 2. 配置 GitHub Secrets

在 GitHub 仓库设置中添加以下 Secrets：

### 2.1 Azure 认证 Secrets

```
AZURE_CLIENT_ID=<your-client-id>
AZURE_TENANT_ID=<your-tenant-id>
AZURE_SUBSCRIPTION_ID=<your-subscription-id>
```

### 2.2 应用配置 Secrets

```
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

# 可选的安全配置
POSTGRES_PASSWORD=your-secure-database-password
JWT_SECRET_KEY=your-jwt-secret-key
```

## 3. GitHub Actions 工作流功能

### 3.1 自动化流程

GitHub Actions 工作流将自动执行以下步骤：

1. **Azure 认证**: 使用 OIDC 无密码认证
2. **资源创建**: 自动创建资源组、容器注册表、虚拟机
3. **镜像构建**: 构建并推送 Docker 镜像到 Azure Container Registry
4. **VM 配置**: 自动安装 Docker 和必要的扩展
5. **应用部署**: 使用 `az vm run-command` 在 VM 上部署应用
6. **健康检查**: 验证应用是否正常运行

### 3.2 创建的 Azure 资源

- **资源组**: `smart-glasses-rg`
- **虚拟机**: `smart-glasses-vm` (Ubuntu 22.04, Standard_B2s)
- **容器注册表**: `smartglassesacr`
- **网络安全组**: 自动配置端口 80, 443, 3000, 8080
- **公共 IP**: 动态分配

### 3.3 部署触发方式

- **自动触发**: 推送代码到 `main` 分支
- **手动触发**: 在 GitHub Actions 页面手动运行

## 4. 部署流程

### 4.1 首次部署

1. **配置 GitHub Secrets**（如上所述）
2. **推送代码到 main 分支**：
   ```bash
   git add .
   git commit -m "Initial deployment"
   git push origin main
   ```
3. **GitHub Actions 自动执行**：
   - 创建 Azure 资源
   - 构建和推送镜像
   - 部署到 VM
   - 执行健康检查

### 4.2 后续更新

只需推送代码到 main 分支，GitHub Actions 会自动：
- 构建新的镜像版本
- 更新 VM 上的应用
- 执行健康检查

## 5. 监控和管理

### 5.1 查看部署状态

```bash
# 查看资源组中的资源
az resource list --resource-group smart-glasses-rg --output table

# 查看 VM 状态
az vm show --resource-group smart-glasses-rg --name smart-glasses-vm --show-details

# 获取 VM 公网 IP
az vm show --resource-group smart-glasses-rg --name smart-glasses-vm --show-details --query publicIps --output tsv
```

### 5.2 查看应用日志

```bash
# 连接到 VM
VM_IP=$(az vm show --resource-group smart-glasses-rg --name smart-glasses-vm --show-details --query publicIps --output tsv)
ssh azureuser@$VM_IP

# 查看容器日志
cd /home/azureuser/smart-glasses-app
docker-compose logs -f
```

### 5.3 手动管理应用

```bash
# 在 VM 上执行命令
az vm run-command invoke \
  --resource-group smart-glasses-rg \
  --name smart-glasses-vm \
  --command-id RunShellScript \
  --scripts "cd /home/azureuser/smart-glasses-app && docker-compose ps"
```

## 6. 成本优化

### 6.1 VM 规格选择

- **开发环境**: Standard_B1s (1 vCPU, 1GB RAM) - 约 $7.59/月
- **生产环境**: Standard_B2s (2 vCPU, 4GB RAM) - 约 $30.37/月
- **高性能**: Standard_D2s_v3 (2 vCPU, 8GB RAM) - 约 $70.08/月

### 6.2 自动关机

```bash
# 配置 VM 自动关机（节省成本）
az vm auto-shutdown \
  --resource-group smart-glasses-rg \
  --name smart-glasses-vm \
  --time 2300 \
  --email your-email@example.com
```

### 6.3 清理资源

```bash
# 删除整个资源组（谨慎操作）
az group delete --name smart-glasses-rg --yes --no-wait
```

## 7. 安全最佳实践

### 7.1 网络安全

- 使用网络安全组限制访问
- 考虑使用 Azure Bastion 进行安全访问
- 启用 Azure Security Center

### 7.2 身份验证

- 使用 OIDC 而不是长期密钥
- 定期轮换 Azure OpenAI API 密钥
- 使用 Azure Key Vault 存储敏感信息

### 7.3 监控

```bash
# 启用 VM 诊断
az vm boot-diagnostics enable \
  --resource-group smart-glasses-rg \
  --name smart-glasses-vm
```

## 8. 故障排查

### 8.1 常见问题

1. **OIDC 认证失败**
   - 检查 GitHub Secrets 配置
   - 验证联合身份凭据设置
   - 确认仓库名称正确

2. **VM 创建失败**
   - 检查 Azure 配额限制
   - 验证区域可用性
   - 确认服务主体权限

3. **应用部署失败**
   - 查看 GitHub Actions 日志
   - 检查 VM 运行命令输出
   - 验证环境变量配置

### 8.2 调试命令

```bash
# 查看 GitHub Actions 运行历史
# 在 GitHub 仓库的 Actions 页面查看

# 查看 Azure 活动日志
az monitor activity-log list --resource-group smart-glasses-rg

# 测试服务主体权限
az role assignment list --assignee $CLIENT_ID
```

## 9. 访问应用

部署完成后，应用将在以下地址可用：

```bash
# 获取 VM 公网 IP
VM_IP=$(az vm show --resource-group smart-glasses-rg --name smart-glasses-vm --show-details --query publicIps --output tsv)

echo "前端应用: http://$VM_IP:3000"
echo "后端 API: http://$VM_IP:8080"
echo "健康检查: http://$VM_IP:8080/health"
```

---

🎉 **现在你可以通过简单的 git push 自动化部署到 Azure VM 了！**

## 5. 配置域名（可选）

### 5.1 配置 DNS

将你的域名指向 VM 的公网 IP。

### 5.2 配置 Nginx 反向代理

```bash
# 安装 Nginx
sudo apt install -y nginx

# 创建配置文件
sudo tee /etc/nginx/sites-available/smart-glasses << 'EOF'
server {
    listen 80;
    server_name your-domain.com;

    # 前端
    location / {
        proxy_pass http://localhost:3000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    # 后端 API
    location /api/ {
        proxy_pass http://localhost:8080;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    # WebSocket 支持
    location /ws/ {
        proxy_pass http://localhost:8080;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
EOF

# 启用站点
sudo ln -s /etc/nginx/sites-available/smart-glasses /etc/nginx/sites-enabled/
sudo nginx -t
sudo systemctl reload nginx
```

### 5.3 配置 SSL（推荐）

```bash
# 安装 Certbot
sudo apt install -y certbot python3-certbot-nginx

# 获取 SSL 证书
sudo certbot --nginx -d your-domain.com

# 设置自动续期
sudo crontab -e
# 添加以下行：
# 0 12 * * * /usr/bin/certbot renew --quiet
```

## 6. 监控和维护

### 6.1 查看应用状态

```bash
# 查看容器状态
docker-compose -f docker-compose.production.yml ps

# 查看日志
docker-compose -f docker-compose.production.yml logs -f

# 查看系统资源使用
htop
df -h
```

### 6.2 备份数据

```bash
# 备份数据库
docker exec smart-glasses-postgres pg_dump -U smartglasses smart_glasses > backup_$(date +%Y%m%d_%H%M%S).sql

# 备份 Redis 数据
docker exec smart-glasses-redis redis-cli BGSAVE
```

### 6.3 更新应用

通过 GitHub Actions 自动部署，或手动执行：

```bash
cd /home/azureuser/smart-glasses-app
git pull origin main
./scripts/deploy.sh
```

## 7. 故障排查

### 7.1 常见问题

1. **端口访问问题**
   ```bash
   # 检查端口是否开放
   sudo ufw status
   sudo ufw allow 3000
   sudo ufw allow 8080
   ```

2. **Docker 权限问题**
   ```bash
   # 确保用户在 docker 组中
   groups $USER
   sudo usermod -aG docker $USER
   ```

3. **内存不足**
   ```bash
   # 检查内存使用
   free -h
   # 考虑升级 VM 规格或添加交换空间
   ```

### 7.2 日志查看

```bash
# 应用日志
docker-compose -f docker-compose.production.yml logs app

# 系统日志
sudo journalctl -u docker
sudo journalctl -f
```

## 8. 安全建议

1. **定期更新系统**
   ```bash
   sudo apt update && sudo apt upgrade -y
   ```

2. **配置防火墙**
   ```bash
   sudo ufw enable
   sudo ufw allow ssh
   sudo ufw allow 80
   sudo ufw allow 443
   ```

3. **使用强密码和密钥**
   - 定期轮换 SSH 密钥
   - 使用强 JWT 密钥
   - 定期更新数据库密码

4. **监控访问日志**
   ```bash
   sudo tail -f /var/log/auth.log
   ```

## 9. 成本优化

1. **选择合适的 VM 规格**
   - 开发环境：Standard_B1s (1 vCPU, 1GB RAM)
   - 生产环境：Standard_B2s (2 vCPU, 4GB RAM) 或更高

2. **使用预留实例**
   - 长期使用可考虑购买预留实例节省成本

3. **定期清理资源**
   ```bash
   # 清理 Docker 镜像
   docker system prune -a
   ```

---

完成以上步骤后，你的智能眼镜应用就可以在 Azure VM 上稳定运行了！
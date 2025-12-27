# Azure VM 部署指南

本指南说明如何配置 GitHub Actions 通过 OIDC 方式部署到 Azure VM。

## 前置要求

1. Azure 订阅
2. Azure VM（已配置 SSH 访问）
3. GitHub 仓库

## 配置步骤

### 1. 在 Azure 中创建服务主体（Service Principal）用于 OIDC

#### 方法一：使用 Azure CLI

```bash
# 登录 Azure
az login

# 获取订阅 ID（如果不知道）
az account show --query id -o tsv

# 创建服务主体（替换 YOUR_SUBSCRIPTION_ID 和 YOUR_RESOURCE_GROUP）
az ad sp create-for-rbac \
  --name "github-actions-oidc" \
  --role "Contributor" \
  --scopes /subscriptions/YOUR_SUBSCRIPTION_ID/resourceGroups/YOUR_RESOURCE_GROUP \
  --sdk-auth
```

**重要**：上述命令的输出会直接包含以下信息（JSON 格式）：
- `clientId` - 这就是 **Application (client) ID**
- `tenantId` - 这就是 **Directory (tenant) ID**
- `subscriptionId` - 订阅 ID
- `clientSecret` - 客户端密钥（如果使用密码认证，但 OIDC 不需要）

**示例输出**：
```json
{
  "clientId": "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx",
  "clientSecret": "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx",
  "subscriptionId": "yyyyyyyy-yyyy-yyyy-yyyy-yyyyyyyyyyyy",
  "tenantId": "zzzzzzzz-zzzz-zzzz-zzzz-zzzzzzzzzzzz",
  ...
}
```

**提取信息的方法**：

方法 A：直接从输出中复制（推荐）
- 运行命令后，从输出中直接复制 `clientId` 和 `tenantId` 的值

方法 B：使用查询命令提取
```bash
# 创建服务主体并保存输出
SP_OUTPUT=$(az ad sp create-for-rbac \
  --name "github-actions-oidc" \
  --role "Contributor" \
  --scopes /subscriptions/YOUR_SUBSCRIPTION_ID/resourceGroups/YOUR_RESOURCE_GROUP \
  --sdk-auth)

# 提取 Client ID
echo "Client ID: $(echo $SP_OUTPUT | jq -r '.clientId')"

# 提取 Tenant ID
echo "Tenant ID: $(echo $SP_OUTPUT | jq -r '.tenantId')"

# 提取 Subscription ID
echo "Subscription ID: $(echo $SP_OUTPUT | jq -r '.subscriptionId')"
```

方法 C：如果服务主体已存在，查询现有信息
```bash
# 查询服务主体的 Client ID
az ad sp list --display-name "github-actions-oidc" --query "[0].appId" -o tsv

# 查询 Tenant ID（当前登录的租户）
az account show --query tenantId -o tsv
```

#### 方法二：使用 Azure Portal

1. 进入 Azure Portal
2. 打开 **Azure Active Directory** > **App registrations**
3. 点击 **New registration**
4. 填写名称（如：github-actions-oidc）
5. 点击 **Register**
6. 记录 **Application (client) ID** 和 **Directory (tenant) ID**

### 2. 配置 OIDC 联合身份验证

在 Azure AD 中配置 GitHub Actions 的 OIDC：

```bash
# 获取你的订阅 ID
az account show --query id -o tsv

# 获取服务主体的 App ID（如果使用方法一创建，App ID 就是 Client ID）
APP_ID=$(az ad sp list --display-name "github-actions-oidc" --query "[0].appId" -o tsv)
echo "App ID (Client ID): $APP_ID"

# 创建联合身份凭据（Federated Identity Credential）
az ad app federated-credential create \
  --id $APP_ID \
  --parameters '{
    "name": "github-actions",
    "issuer": "https://token.actions.githubusercontent.com",
    "subject": "repo:YOUR_GITHUB_USERNAME/YOUR_REPO_NAME:ref:refs/heads/main",
    "audiences": ["api://AzureADTokenExchange"]
  }'
```

**注意**：将以下内容替换为实际值：
- `YOUR_GITHUB_USERNAME`: 你的 GitHub 用户名或组织名
- `YOUR_REPO_NAME`: 你的仓库名称
- `main`: 你的分支名称（如果需要部署其他分支，可以添加多个 subject）

**重要提示**：
- 如果使用方法一创建服务主体，`App ID` 就是步骤1中输出的 `clientId`
- 如果使用方法二（Azure Portal）创建，`App ID` 就是注册时显示的 **Application (client) ID**
- 对于 OIDC 认证，**不需要** `clientSecret`，只需要 `clientId`、`tenantId` 和 `subscriptionId`

### 3. 配置 GitHub Secrets

在 GitHub 仓库中设置以下 Secrets：

1. 进入仓库 **Settings** > **Secrets and variables** > **Actions**
2. 点击 **New repository secret**
3. 添加以下 secrets：

- `AZURE_CLIENT_ID`: 应用程序（客户端）ID（步骤1中的 `clientId`）
- `AZURE_TENANT_ID`: 目录（租户）ID（步骤1中的 `tenantId`）
- `AZURE_SUBSCRIPTION_ID`: Azure 订阅 ID（步骤1中的 `subscriptionId` 或使用 `az account show --query id -o tsv` 获取）
- `AZURE_VM_SSH_PRIVATE_KEY`: SSH 私钥（用于连接 VM，见步骤4）

**重要**：
- 使用 OIDC 认证时，**不需要** `AZURE_CLIENT_SECRET`（客户端密钥）
- OIDC 通过联合身份验证，无需存储密码或密钥，更加安全

### 4. 生成 SSH 密钥对（如果还没有）

```bash
# 生成 SSH 密钥对
ssh-keygen -t rsa -b 4096 -C "github-actions@azure-vm"

# 将公钥添加到 Azure VM
ssh-copy-id -i ~/.ssh/id_rsa.pub azureuser@YOUR_VM_IP

# 将私钥内容复制到 GitHub Secret AZURE_VM_SSH_PRIVATE_KEY
cat ~/.ssh/id_rsa
```

### 5. 修改 Workflow 文件

编辑 `.github/workflows/deploy-to-azure-vm.yml`，更新以下环境变量：

- `AZURE_WEBAPP_NAME`: 你的 VM 名称
- `AZURE_RESOURCE_GROUP`: 你的资源组名称
- `VM_IP`: 你的 VM IP 地址
- `VM_USER`: VM 用户名（通常是 `azureuser`）
- `DEPLOY_PATH`: 部署路径

### 6. 配置 VM 上的部署脚本

根据你的项目类型，在 workflow 文件的部署步骤中添加相应的命令：

#### Node.js 项目
```bash
npm install --production
pm2 restart app
```

#### Python 项目
```bash
pip install -r requirements.txt
systemctl restart your-app
```

#### Docker 项目
```bash
docker-compose down
docker-compose up -d --build
```

## 安全最佳实践

1. **最小权限原则**：只授予服务主体必要的权限
2. **使用 OIDC**：避免使用长期凭证，使用 OIDC 进行身份验证
3. **保护 SSH 密钥**：确保 SSH 私钥安全存储在 GitHub Secrets 中
4. **限制访问**：在 Azure 中配置网络安全组（NSG）限制 SSH 访问
5. **定期轮换**：定期更新 SSH 密钥和证书

## 故障排查

### OIDC 认证失败
- 检查联合身份凭据配置是否正确
- 确认 subject 中的仓库名称和分支名称正确
- 验证 Azure AD 应用程序权限

### SSH 连接失败
- 检查 VM 的网络安全组是否允许 SSH 访问
- 验证 SSH 密钥是否正确
- 确认 VM IP 地址和用户名正确

### 部署失败
- 检查部署路径是否存在且有写权限
- 验证部署脚本中的命令是否正确
- 查看 GitHub Actions 日志获取详细错误信息

## 参考资源

- [GitHub Actions OIDC with Azure](https://docs.github.com/en/actions/deployment/security-hardening-your-deployments/configuring-openid-connect-in-azure)
- [Azure AD App Registration](https://docs.microsoft.com/en-us/azure/active-directory/develop/quickstart-register-app)
- [Azure VM SSH Access](https://docs.microsoft.com/en-us/azure/virtual-machines/linux/ssh-from-windows)


#!/bin/bash

# Azure 服务主体和 OIDC 自动化设置脚本
# 用于配置 GitHub Actions 的 Azure 认证

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 打印带颜色的消息
print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

print_header() {
    echo -e "${BLUE}🚀 $1${NC}"
    echo "=================================================="
}

# 检查必要的工具
check_prerequisites() {
    print_header "检查前置条件"
    
    if ! command -v az &> /dev/null; then
        print_error "Azure CLI 未安装，请先安装 Azure CLI"
        echo "安装指南: https://docs.microsoft.com/en-us/cli/azure/install-azure-cli"
        exit 1
    fi
    
    if ! command -v jq &> /dev/null; then
        print_error "jq 未安装，请先安装 jq"
        echo "macOS: brew install jq"
        echo "Ubuntu: sudo apt-get install jq"
        exit 1
    fi
    
    print_success "前置条件检查通过"
}

# 获取用户输入
get_user_input() {
    print_header "获取配置信息"
    
    # 获取 GitHub 仓库信息
    if [ -d ".git" ]; then
        # 尝试从 git remote 获取仓库信息
        REMOTE_URL=$(git remote get-url origin 2>/dev/null || echo "")
        if [[ $REMOTE_URL =~ github\.com[:/]([^/]+)/([^/]+)(\.git)?$ ]]; then
            DEFAULT_GITHUB_USERNAME="${BASH_REMATCH[1]}"
            DEFAULT_REPO_NAME="${BASH_REMATCH[2]}"
            DEFAULT_REPO_NAME="${DEFAULT_REPO_NAME%.git}"
        fi
    fi
    
    echo -n "GitHub 用户名 [${DEFAULT_GITHUB_USERNAME:-}]: "
    read GITHUB_USERNAME
    GITHUB_USERNAME=${GITHUB_USERNAME:-$DEFAULT_GITHUB_USERNAME}
    
    echo -n "GitHub 仓库名 [${DEFAULT_REPO_NAME:-}]: "
    read REPO_NAME
    REPO_NAME=${REPO_NAME:-$DEFAULT_REPO_NAME}
    
    if [ -z "$GITHUB_USERNAME" ] || [ -z "$REPO_NAME" ]; then
        print_error "GitHub 用户名和仓库名不能为空"
        exit 1
    fi
    
    # 应用名称
    DEFAULT_APP_NAME="smart-glasses-github-actions"
    echo -n "Azure 应用名称 [${DEFAULT_APP_NAME}]: "
    read APP_NAME
    APP_NAME=${APP_NAME:-$DEFAULT_APP_NAME}
    
    print_info "配置信息:"
    print_info "  GitHub: ${GITHUB_USERNAME}/${REPO_NAME}"
    print_info "  Azure 应用: ${APP_NAME}"
    
    echo -n "确认配置信息正确? (y/N): "
    read CONFIRM
    if [[ ! $CONFIRM =~ ^[Yy]$ ]]; then
        print_warning "用户取消操作"
        exit 0
    fi
}

# Azure 登录检查
check_azure_login() {
    print_header "检查 Azure 登录状态"
    
    if ! az account show &>/dev/null; then
        print_warning "未登录 Azure，正在启动登录流程..."
        az login
    fi
    
    # 获取当前订阅信息
    SUBSCRIPTION_ID=$(az account show --query id --output tsv)
    TENANT_ID=$(az account show --query tenantId --output tsv)
    SUBSCRIPTION_NAME=$(az account show --query name --output tsv)
    
    print_success "已登录 Azure"
    print_info "  订阅: ${SUBSCRIPTION_NAME}"
    print_info "  订阅 ID: ${SUBSCRIPTION_ID}"
    print_info "  租户 ID: ${TENANT_ID}"
    
    echo -n "使用当前订阅? (Y/n): "
    read USE_CURRENT
    if [[ $USE_CURRENT =~ ^[Nn]$ ]]; then
        print_info "可用订阅列表:"
        az account list --output table
        echo -n "请输入要使用的订阅 ID: "
        read NEW_SUBSCRIPTION_ID
        az account set --subscription "$NEW_SUBSCRIPTION_ID"
        SUBSCRIPTION_ID=$(az account show --query id --output tsv)
        TENANT_ID=$(az account show --query tenantId --output tsv)
        print_success "已切换到订阅: $SUBSCRIPTION_ID"
    fi
}

# 创建服务主体
create_service_principal() {
    print_header "创建 Azure 服务主体"
    
    # 检查应用是否已存在
    EXISTING_APP=$(az ad app list --display-name "$APP_NAME" --query "[0].appId" --output tsv 2>/dev/null || echo "")
    
    if [ -n "$EXISTING_APP" ] && [ "$EXISTING_APP" != "null" ]; then
        print_warning "应用 '$APP_NAME' 已存在"
        echo -n "是否删除现有应用并重新创建? (y/N): "
        read RECREATE
        if [[ $RECREATE =~ ^[Yy]$ ]]; then
            print_info "删除现有应用..."
            az ad app delete --id "$EXISTING_APP"
            print_success "已删除现有应用"
        else
            CLIENT_ID="$EXISTING_APP"
            print_info "使用现有应用: $CLIENT_ID"
        fi
    fi
    
    if [ -z "$CLIENT_ID" ]; then
        print_info "创建新的服务主体..."
        
        # 创建服务主体
        SP_OUTPUT=$(az ad sp create-for-rbac \
            --name "$APP_NAME" \
            --role contributor \
            --scopes "/subscriptions/$SUBSCRIPTION_ID" \
            --output json)
        
        CLIENT_ID=$(echo "$SP_OUTPUT" | jq -r '.appId')
        CLIENT_SECRET=$(echo "$SP_OUTPUT" | jq -r '.password')
        
        print_success "服务主体创建成功"
        print_info "  客户端 ID: $CLIENT_ID"
        print_warning "  客户端密钥: $CLIENT_SECRET (请妥善保管)"
    fi
}

# 配置 OIDC 联合身份验证
configure_oidc() {
    print_header "配置 OIDC 联合身份验证"
    
    # 删除现有的联合身份凭据
    print_info "清理现有的联合身份凭据..."
    EXISTING_CREDS=$(az ad app federated-credential list --id "$CLIENT_ID" --query "[?contains(name, 'github-actions')].name" --output tsv 2>/dev/null || echo "")
    
    if [ -n "$EXISTING_CREDS" ]; then
        while IFS= read -r cred; do
            if [ -n "$cred" ]; then
                print_info "删除现有凭据: $cred"
                az ad app federated-credential delete --id "$CLIENT_ID" --federated-credential-id "$cred" --yes 2>/dev/null || true
                sleep 2  # 等待删除完成
            fi
        done <<< "$EXISTING_CREDS"
    fi
    
    # 等待一下确保删除完成
    sleep 3
    
    # 为 main 分支创建联合身份凭据
    print_info "为 main 分支创建联合身份凭据..."
    if az ad app federated-credential create \
        --id "$CLIENT_ID" \
        --parameters "{
            \"name\": \"github-actions-main-$(date +%s)\",
            \"issuer\": \"https://token.actions.githubusercontent.com\",
            \"subject\": \"repo:$GITHUB_USERNAME/$REPO_NAME:ref:refs/heads/main\",
            \"audiences\": [\"api://AzureADTokenExchange\"]
        }" >/dev/null 2>&1; then
        print_success "main 分支联合身份凭据创建成功"
    else
        print_warning "main 分支联合身份凭据创建失败，可能已存在"
    fi
    
    # 为手动触发创建联合身份凭据（使用不同的 subject）
    print_info "为手动触发创建联合身份凭据..."
    if az ad app federated-credential create \
        --id "$CLIENT_ID" \
        --parameters "{
            \"name\": \"github-actions-dispatch-$(date +%s)\",
            \"issuer\": \"https://token.actions.githubusercontent.com\",
            \"subject\": \"repo:$GITHUB_USERNAME/$REPO_NAME:environment:Production\",
            \"audiences\": [\"api://AzureADTokenExchange\"]
        }" >/dev/null 2>&1; then
        print_success "手动触发联合身份凭据创建成功"
    else
        print_warning "手动触发联合身份凭据创建失败，将使用 main 分支凭据"
    fi
    
    print_success "OIDC 联合身份验证配置完成"
}

# 验证配置
verify_configuration() {
    print_header "验证配置"
    
    # 检查服务主体权限
    print_info "检查服务主体权限..."
    ROLE_ASSIGNMENTS=$(az role assignment list --assignee "$CLIENT_ID" --query "[?roleDefinitionName=='Contributor'].scope" --output tsv)
    
    if echo "$ROLE_ASSIGNMENTS" | grep -q "/subscriptions/$SUBSCRIPTION_ID"; then
        print_success "服务主体具有订阅级别的 Contributor 权限"
    else
        print_warning "服务主体权限可能不足"
    fi
    
    # 检查联合身份凭据
    print_info "检查联合身份凭据..."
    FEDERATED_CREDS=$(az ad app federated-credential list --id "$CLIENT_ID" --query "length([?contains(name, 'github-actions')])" --output tsv)
    
    if [ "$FEDERATED_CREDS" -ge 2 ]; then
        print_success "联合身份凭据配置正确"
    else
        print_warning "联合身份凭据可能配置不完整"
    fi
}

# 生成 GitHub Secrets 配置
generate_github_secrets() {
    print_header "生成 GitHub Secrets 配置"
    
    cat > github-secrets.txt << EOF
# 请在 GitHub 仓库设置中添加以下 Secrets
# 路径: Settings → Secrets and variables → Actions → New repository secret

# Azure 认证 (必需)
AZURE_CLIENT_ID=$CLIENT_ID
AZURE_TENANT_ID=$TENANT_ID
AZURE_SUBSCRIPTION_ID=$SUBSCRIPTION_ID

# Azure OpenAI 配置 (必需 - 请替换为实际值)
AZURE_OPENAI_ENDPOINT=https://your-resource.openai.azure.com
AZURE_OPENAI_API_KEY=your-api-key
AZURE_OPENAI_DEPLOYMENT_NAME=gpt-4o
AZURE_OPENAI_API_VERSION=2024-08-01-preview

# Azure OpenAI Realtime API 配置 (必需 - 请替换为实际值)
AZURE_OPENAI_REALTIME_ENDPOINT=https://your-resource.cognitiveservices.azure.com
AZURE_OPENAI_REALTIME_API_KEY=your-realtime-api-key
AZURE_OPENAI_REALTIME_DEPLOYMENT_NAME=gpt-realtime
AZURE_OPENAI_REALTIME_API_VERSION=2024-10-01-preview

# 可选的安全配置
POSTGRES_PASSWORD=your-secure-database-password
JWT_SECRET_KEY=your-jwt-secret-key
EOF
    
    print_success "GitHub Secrets 配置已生成到 github-secrets.txt"
    print_warning "请编辑 github-secrets.txt 文件，填入实际的 Azure OpenAI 配置"
}

# 生成测试脚本
generate_test_script() {
    print_header "生成测试脚本"
    
    cat > test-azure-auth.sh << 'EOF'
#!/bin/bash

# 测试 Azure 认证配置
# 此脚本模拟 GitHub Actions 的认证流程

set -e

echo "🧪 测试 Azure 认证配置..."

# 检查环境变量
if [ -z "$AZURE_CLIENT_ID" ] || [ -z "$AZURE_TENANT_ID" ] || [ -z "$AZURE_SUBSCRIPTION_ID" ]; then
    echo "❌ 请设置环境变量: AZURE_CLIENT_ID, AZURE_TENANT_ID, AZURE_SUBSCRIPTION_ID"
    exit 1
fi

# 使用服务主体登录 (模拟 GitHub Actions)
echo "🔐 使用服务主体登录..."
az login --service-principal \
    --username "$AZURE_CLIENT_ID" \
    --tenant "$AZURE_TENANT_ID" \
    --federated-token "$(curl -s -H "Authorization: bearer $ACTIONS_ID_TOKEN_REQUEST_TOKEN" "$ACTIONS_ID_TOKEN_REQUEST_URL&audience=api://AzureADTokenExchange" | jq -r .value)"

# 设置订阅
az account set --subscription "$AZURE_SUBSCRIPTION_ID"

# 测试权限
echo "✅ 认证成功！"
echo "📋 当前账户信息:"
az account show --output table

echo "🎉 Azure 认证配置测试通过！"
EOF
    
    chmod +x test-azure-auth.sh
    print_success "测试脚本已生成到 test-azure-auth.sh"
}

# 显示完成信息
show_completion_info() {
    print_header "设置完成"
    
    print_success "Azure 服务主体和 OIDC 配置已完成！"
    echo ""
    print_info "📋 配置摘要:"
    print_info "  应用名称: $APP_NAME"
    print_info "  客户端 ID: $CLIENT_ID"
    print_info "  租户 ID: $TENANT_ID"
    print_info "  订阅 ID: $SUBSCRIPTION_ID"
    print_info "  GitHub 仓库: $GITHUB_USERNAME/$REPO_NAME"
    echo ""
    print_warning "📝 下一步操作:"
    echo "1. 编辑 github-secrets.txt 文件，填入 Azure OpenAI 配置"
    echo "2. 在 GitHub 仓库中添加 Secrets (参考 github-secrets.txt)"
    echo "3. 推送代码到 main 分支测试自动部署"
    echo ""
    print_info "📁 生成的文件:"
    print_info "  github-secrets.txt - GitHub Secrets 配置"
    print_info "  test-azure-auth.sh - 认证测试脚本"
    echo ""
    print_success "🎉 现在可以使用 GitHub Actions 自动部署到 Azure VM 了！"
}

# 主函数
main() {
    print_header "Azure 服务主体和 OIDC 自动化设置"
    
    check_prerequisites
    get_user_input
    check_azure_login
    create_service_principal
    configure_oidc
    verify_configuration
    generate_github_secrets
    generate_test_script
    show_completion_info
}

# 错误处理
trap 'print_error "脚本执行失败，请检查错误信息"; exit 1' ERR

# 运行主函数
main "$@"
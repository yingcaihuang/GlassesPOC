#!/bin/bash

# Azure 认证清理脚本
# 用于清理已存在的服务主体和联合身份凭据

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
    echo -e "${BLUE}🧹 $1${NC}"
    echo "=================================================="
}

# 检查 Azure 登录
check_azure_login() {
    if ! az account show &>/dev/null; then
        print_error "未登录 Azure，请先运行 'az login'"
        exit 1
    fi
    print_success "Azure 登录状态正常"
}

# 获取应用名称
get_app_name() {
    DEFAULT_APP_NAME="smart-glasses-github-actions"
    echo -n "要清理的 Azure 应用名称 [${DEFAULT_APP_NAME}]: "
    read APP_NAME
    APP_NAME=${APP_NAME:-$DEFAULT_APP_NAME}
}

# 清理联合身份凭据
cleanup_federated_credentials() {
    print_header "清理联合身份凭据"
    
    # 获取应用 ID
    CLIENT_ID=$(az ad app list --display-name "$APP_NAME" --query "[0].appId" --output tsv 2>/dev/null || echo "")
    
    if [ -z "$CLIENT_ID" ] || [ "$CLIENT_ID" = "null" ]; then
        print_warning "未找到应用 '$APP_NAME'"
        return
    fi
    
    print_info "找到应用: $APP_NAME (ID: $CLIENT_ID)"
    
    # 列出所有联合身份凭据
    EXISTING_CREDS=$(az ad app federated-credential list --id "$CLIENT_ID" --query "[].name" --output tsv 2>/dev/null || echo "")
    
    if [ -z "$EXISTING_CREDS" ]; then
        print_info "没有找到联合身份凭据"
        return
    fi
    
    print_info "找到以下联合身份凭据:"
    echo "$EXISTING_CREDS" | while IFS= read -r cred; do
        if [ -n "$cred" ]; then
            echo "  - $cred"
        fi
    done
    
    echo -n "是否删除所有联合身份凭据? (y/N): "
    read CONFIRM_DELETE
    
    if [[ $CONFIRM_DELETE =~ ^[Yy]$ ]]; then
        echo "$EXISTING_CREDS" | while IFS= read -r cred; do
            if [ -n "$cred" ]; then
                print_info "删除凭据: $cred"
                az ad app federated-credential delete --id "$CLIENT_ID" --federated-credential-id "$cred" --yes 2>/dev/null || true
                sleep 1
            fi
        done
        print_success "所有联合身份凭据已删除"
    else
        print_info "跳过删除联合身份凭据"
    fi
}

# 清理服务主体
cleanup_service_principal() {
    print_header "清理服务主体"
    
    # 获取应用 ID
    CLIENT_ID=$(az ad app list --display-name "$APP_NAME" --query "[0].appId" --output tsv 2>/dev/null || echo "")
    
    if [ -z "$CLIENT_ID" ] || [ "$CLIENT_ID" = "null" ]; then
        print_warning "未找到应用 '$APP_NAME'"
        return
    fi
    
    print_info "找到应用: $APP_NAME (ID: $CLIENT_ID)"
    
    # 显示角色分配
    ROLE_ASSIGNMENTS=$(az role assignment list --assignee "$CLIENT_ID" --query "[].{Role:roleDefinitionName,Scope:scope}" --output table 2>/dev/null || echo "")
    
    if [ -n "$ROLE_ASSIGNMENTS" ]; then
        print_info "当前角色分配:"
        echo "$ROLE_ASSIGNMENTS"
    fi
    
    echo -n "是否删除整个服务主体应用? (y/N): "
    read CONFIRM_DELETE_APP
    
    if [[ $CONFIRM_DELETE_APP =~ ^[Yy]$ ]]; then
        print_info "删除服务主体应用..."
        az ad app delete --id "$CLIENT_ID"
        print_success "服务主体应用已删除"
    else
        print_info "保留服务主体应用"
    fi
}

# 主函数
main() {
    print_header "Azure 认证清理工具"
    
    check_azure_login
    get_app_name
    cleanup_federated_credentials
    cleanup_service_principal
    
    print_success "清理完成！"
    print_info "现在可以重新运行 ./scripts/setup-azure-auth.sh"
}

# 运行主函数
main "$@"
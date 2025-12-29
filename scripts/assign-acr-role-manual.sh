#!/bin/bash

# 手动为 VM 托管身份分配 ACR 访问权限
# 当 GitHub Actions 权限不足时使用

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

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
    echo -e "${BLUE}🔧 $1${NC}"
    echo "=================================================="
}

# 配置变量
RESOURCE_GROUP="smart-glasses-rg"
VM_NAME="smart-glasses-vm"
CONTAINER_REGISTRY="smartglassesacr"

# 检查 Azure CLI
check_azure_cli() {
    if ! command -v az &> /dev/null; then
        print_error "Azure CLI 未安装"
        exit 1
    fi
    
    if ! az account show &>/dev/null; then
        print_error "未登录 Azure，请先运行 'az login'"
        exit 1
    fi
    
    print_success "Azure CLI 检查通过"
}

# 获取当前用户权限
check_permissions() {
    print_header "检查当前用户权限"
    
    CURRENT_USER=$(az account show --query user.name --output tsv)
    print_info "当前用户: $CURRENT_USER"
    
    # 检查是否有足够权限
    SUBSCRIPTION_ID=$(az account show --query id --output tsv)
    print_info "订阅 ID: $SUBSCRIPTION_ID"
    
    # 检查用户角色
    USER_ROLES=$(az role assignment list --assignee $CURRENT_USER --scope "/subscriptions/$SUBSCRIPTION_ID" --query "[].roleDefinitionName" --output tsv)
    print_info "用户角色: $USER_ROLES"
    
    if echo "$USER_ROLES" | grep -q -E "(Owner|Contributor|User Access Administrator)"; then
        print_success "用户有足够权限分配角色"
    else
        print_warning "用户可能没有足够权限分配角色"
        print_info "需要 Owner、Contributor 或 User Access Administrator 角色"
    fi
}

# 手动分配角色
assign_role_manual() {
    print_header "手动分配 ACR 访问角色"
    
    # 获取 VM 托管身份
    print_info "获取 VM 托管身份..."
    VM_PRINCIPAL_ID=$(az vm identity show --resource-group "$RESOURCE_GROUP" --name "$VM_NAME" --query principalId --output tsv)
    
    if [ -z "$VM_PRINCIPAL_ID" ]; then
        print_error "VM 没有托管身份，请先运行: az vm identity assign --resource-group $RESOURCE_GROUP --name $VM_NAME"
        exit 1
    fi
    
    print_success "VM 托管身份 ID: $VM_PRINCIPAL_ID"
    
    # 获取 ACR 资源 ID
    print_info "获取 ACR 资源 ID..."
    ACR_ID=$(az acr show --name "$CONTAINER_REGISTRY" --resource-group "$RESOURCE_GROUP" --query id --output tsv)
    
    if [ -z "$ACR_ID" ]; then
        print_error "无法找到 ACR: $CONTAINER_REGISTRY"
        exit 1
    fi
    
    print_success "ACR 资源 ID: $ACR_ID"
    
    # 检查是否已有角色分配
    print_info "检查现有角色分配..."
    EXISTING_ASSIGNMENT=$(az role assignment list --assignee "$VM_PRINCIPAL_ID" --scope "$ACR_ID" --role AcrPull --query "[0].id" --output tsv 2>/dev/null || echo "")
    
    if [ -n "$EXISTING_ASSIGNMENT" ]; then
        print_success "AcrPull 角色已经分配给 VM 托管身份"
        print_info "角色分配 ID: $EXISTING_ASSIGNMENT"
        return 0
    fi
    
    # 分配角色
    print_info "分配 AcrPull 角色给 VM 托管身份..."
    az role assignment create \
        --assignee "$VM_PRINCIPAL_ID" \
        --role AcrPull \
        --scope "$ACR_ID"
    
    print_success "角色分配成功！"
}

# 验证角色分配
verify_assignment() {
    print_header "验证角色分配"
    
    print_info "检查角色分配..."
    ASSIGNMENTS=$(az role assignment list --assignee "$VM_PRINCIPAL_ID" --scope "$ACR_ID" --query "[?roleDefinitionName=='AcrPull'].[id,roleDefinitionName,scope]" --output table)
    
    if [ -n "$ASSIGNMENTS" ]; then
        print_success "角色分配验证成功："
        echo "$ASSIGNMENTS"
    else
        print_error "角色分配验证失败"
        exit 1
    fi
}

# 测试 ACR 访问
test_acr_access() {
    print_header "测试 VM 上的 ACR 访问"
    
    print_info "在 VM 上测试 ACR 访问..."
    az vm run-command invoke \
        --resource-group "$RESOURCE_GROUP" \
        --name "$VM_NAME" \
        --command-id RunShellScript \
        --scripts "
            echo '🔍 测试托管身份和 ACR 访问...'
            
            # 检查 Azure CLI
            if ! command -v az &> /dev/null; then
                echo '安装 Azure CLI...'
                curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash
            fi
            
            # 使用托管身份登录
            echo '使用托管身份登录 Azure...'
            az login --identity
            
            # 测试 ACR 登录
            echo '测试 ACR 登录...'
            az acr login --name $CONTAINER_REGISTRY
            
            echo '✅ ACR 访问测试成功！'
        " \
        --parameters CONTAINER_REGISTRY="$CONTAINER_REGISTRY"
    
    print_success "VM ACR 访问测试完成"
}

# 主函数
main() {
    print_header "手动分配 VM ACR 访问权限"
    
    check_azure_cli
    check_permissions
    assign_role_manual
    verify_assignment
    test_acr_access
    
    print_success "手动角色分配完成！"
    print_info "现在 VM 可以使用托管身份访问 ACR"
    print_info "可以重新运行部署: git push origin main"
}

# 运行主函数
main "$@"
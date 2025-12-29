#!/bin/bash

# 为现有 VM 设置托管身份和 ACR 访问权限

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

# 配置托管身份
setup_managed_identity() {
    print_header "配置 VM 托管身份"
    
    # 检查 VM 是否存在
    if ! az vm show --name "$VM_NAME" --resource-group "$RESOURCE_GROUP" &>/dev/null; then
        print_error "VM '$VM_NAME' 不存在"
        exit 1
    fi
    
    print_info "为 VM 分配系统托管身份..."
    az vm identity assign --resource-group "$RESOURCE_GROUP" --name "$VM_NAME" || {
        print_warning "托管身份可能已经存在"
    }
    
    # 获取 VM 的托管身份主体 ID
    print_info "获取 VM 托管身份主体 ID..."
    VM_PRINCIPAL_ID=$(az vm identity show --resource-group "$RESOURCE_GROUP" --name "$VM_NAME" --query principalId --output tsv)
    
    if [ -z "$VM_PRINCIPAL_ID" ]; then
        print_error "无法获取 VM 托管身份主体 ID"
        exit 1
    fi
    
    print_success "VM 托管身份主体 ID: $VM_PRINCIPAL_ID"
}

# 配置 ACR 访问权限
setup_acr_access() {
    print_header "配置 ACR 访问权限"
    
    # 检查 ACR 是否存在
    if ! az acr show --name "$CONTAINER_REGISTRY" --resource-group "$RESOURCE_GROUP" &>/dev/null; then
        print_error "ACR '$CONTAINER_REGISTRY' 不存在"
        exit 1
    fi
    
    # 获取 ACR 资源 ID
    print_info "获取 ACR 资源 ID..."
    ACR_ID=$(az acr show --name "$CONTAINER_REGISTRY" --resource-group "$RESOURCE_GROUP" --query id --output tsv)
    
    if [ -z "$ACR_ID" ]; then
        print_error "无法获取 ACR 资源 ID"
        exit 1
    fi
    
    print_info "ACR 资源 ID: $ACR_ID"
    
    # 为 VM 的托管身份分配 AcrPull 角色
    print_info "为 VM 托管身份分配 AcrPull 角色..."
    az role assignment create \
        --assignee "$VM_PRINCIPAL_ID" \
        --role AcrPull \
        --scope "$ACR_ID" || {
        print_warning "角色分配可能已经存在"
    }
    
    print_success "ACR 访问权限配置完成"
}

# 验证配置
verify_setup() {
    print_header "验证配置"
    
    print_info "检查角色分配..."
    ROLE_ASSIGNMENTS=$(az role assignment list --assignee "$VM_PRINCIPAL_ID" --scope "$ACR_ID" --query "[?roleDefinitionName=='AcrPull']" --output tsv)
    
    if [ -n "$ROLE_ASSIGNMENTS" ]; then
        print_success "VM 托管身份已成功分配 AcrPull 角色"
    else
        print_error "角色分配验证失败"
        exit 1
    fi
}

# 在 VM 上安装 Azure CLI
install_azure_cli_on_vm() {
    print_header "在 VM 上安装 Azure CLI"
    
    print_info "在 VM 上安装 Azure CLI..."
    az vm run-command invoke \
        --resource-group "$RESOURCE_GROUP" \
        --name "$VM_NAME" \
        --command-id RunShellScript \
        --scripts "
            # 检查是否已安装 Azure CLI
            if command -v az &> /dev/null; then
                echo 'Azure CLI 已安装'
                az --version
            else
                echo '安装 Azure CLI...'
                curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash
                echo 'Azure CLI 安装完成'
                az --version
            fi
            
            # 测试托管身份登录
            echo '测试托管身份登录...'
            az login --identity
            echo '托管身份登录成功'
            
            # 测试 ACR 访问
            echo '测试 ACR 访问...'
            az acr login --name $CONTAINER_REGISTRY
            echo 'ACR 访问测试成功'
        " \
        --parameters CONTAINER_REGISTRY="$CONTAINER_REGISTRY"
    
    print_success "VM 上的 Azure CLI 配置完成"
}

# 主函数
main() {
    print_header "VM 托管身份和 ACR 访问配置"
    
    check_azure_cli
    setup_managed_identity
    setup_acr_access
    verify_setup
    install_azure_cli_on_vm
    
    print_success "配置完成！"
    print_info "现在 VM 可以使用托管身份访问 ACR，无需密码认证"
    print_info "可以运行部署脚本测试: ./scripts/vm-deploy.sh"
}

# 运行主函数
main "$@"
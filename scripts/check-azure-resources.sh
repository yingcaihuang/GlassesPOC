#!/bin/bash

# Azure 资源检查脚本
# 检查现有的 Azure 资源状态

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
    echo -e "${BLUE}🔍 $1${NC}"
    echo "=================================================="
}

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

# 检查资源组
check_resource_group() {
    print_header "检查资源组"
    
    RESOURCE_GROUP="smart-glasses-rg"
    
    if az group show --name "$RESOURCE_GROUP" &>/dev/null; then
        print_success "资源组 '$RESOURCE_GROUP' 存在"
        
        # 列出资源组中的资源
        print_info "资源组中的资源:"
        az resource list --resource-group "$RESOURCE_GROUP" --output table
    else
        print_warning "资源组 '$RESOURCE_GROUP' 不存在"
    fi
}

# 检查容器注册表
check_container_registry() {
    print_header "检查 Azure Container Registry"
    
    RESOURCE_GROUP="smart-glasses-rg"
    CONTAINER_REGISTRY="smartglassesacr"
    
    if az acr show --name "$CONTAINER_REGISTRY" --resource-group "$RESOURCE_GROUP" &>/dev/null; then
        print_success "容器注册表 '$CONTAINER_REGISTRY' 存在"
        
        # 显示 ACR 信息
        print_info "ACR 详细信息:"
        az acr show --name "$CONTAINER_REGISTRY" --resource-group "$RESOURCE_GROUP" --query "{name:name,loginServer:loginServer,sku:sku.name,adminUserEnabled:adminUserEnabled}" --output table
        
        # 列出镜像仓库
        print_info "镜像仓库:"
        az acr repository list --name "$CONTAINER_REGISTRY" --output table || print_warning "没有镜像仓库或权限不足"
    else
        print_warning "容器注册表 '$CONTAINER_REGISTRY' 不存在"
    fi
}

# 检查虚拟机
check_virtual_machine() {
    print_header "检查虚拟机"
    
    RESOURCE_GROUP="smart-glasses-rg"
    VM_NAME="smart-glasses-vm"
    
    if az vm show --name "$VM_NAME" --resource-group "$RESOURCE_GROUP" &>/dev/null; then
        print_success "虚拟机 '$VM_NAME' 存在"
        
        # 显示 VM 详细信息
        print_info "VM 详细信息:"
        az vm show --name "$VM_NAME" --resource-group "$RESOURCE_GROUP" --show-details --query "{name:name,powerState:powerState,publicIps:publicIps,privateIps:privateIps,vmSize:hardwareProfile.vmSize}" --output table
        
        # 检查网络安全组规则
        print_info "网络安全组规则:"
        NSG_NAME=$(az vm show --name "$VM_NAME" --resource-group "$RESOURCE_GROUP" --query "networkProfile.networkInterfaces[0].id" --output tsv | xargs az network nic show --ids | jq -r '.networkSecurityGroup.id' | xargs basename)
        if [ "$NSG_NAME" != "null" ] && [ -n "$NSG_NAME" ]; then
            az network nsg rule list --resource-group "$RESOURCE_GROUP" --nsg-name "$NSG_NAME" --query "[?direction=='Inbound'].{Name:name,Priority:priority,Port:destinationPortRange,Access:access}" --output table
        else
            print_warning "未找到网络安全组"
        fi
        
    else
        print_warning "虚拟机 '$VM_NAME' 不存在"
    fi
}

# 检查部署状态
check_deployment_status() {
    print_header "检查应用部署状态"
    
    RESOURCE_GROUP="smart-glasses-rg"
    VM_NAME="smart-glasses-vm"
    
    if az vm show --name "$VM_NAME" --resource-group "$RESOURCE_GROUP" &>/dev/null; then
        VM_IP=$(az vm show --name "$VM_NAME" --resource-group "$RESOURCE_GROUP" --show-details --query "publicIps" --output tsv)
        
        if [ -n "$VM_IP" ]; then
            print_info "VM 公网 IP: $VM_IP"
            
            # 检查服务端口
            print_info "检查服务端口:"
            
            # 检查前端 (端口 3000)
            if curl -s --connect-timeout 5 "http://$VM_IP:3000" >/dev/null; then
                print_success "前端服务 (端口 3000) 可访问"
            else
                print_warning "前端服务 (端口 3000) 不可访问"
            fi
            
            # 检查后端 (端口 8080)
            if curl -s --connect-timeout 5 "http://$VM_IP:8080/health" >/dev/null; then
                print_success "后端服务 (端口 8080) 可访问"
            else
                print_warning "后端服务 (端口 8080) 不可访问"
            fi
            
            print_info "应用访问地址:"
            echo "  前端: http://$VM_IP:3000"
            echo "  后端: http://$VM_IP:8080"
            echo "  健康检查: http://$VM_IP:8080/health"
        else
            print_warning "无法获取 VM 公网 IP"
        fi
    else
        print_warning "VM 不存在，无法检查部署状态"
    fi
}

# 主函数
main() {
    print_header "Azure 资源状态检查"
    
    check_azure_cli
    check_resource_group
    check_container_registry
    check_virtual_machine
    check_deployment_status
    
    print_success "资源检查完成！"
}

# 运行主函数
main "$@"
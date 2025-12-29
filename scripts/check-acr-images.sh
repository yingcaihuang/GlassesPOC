#!/bin/bash

# 检查 ACR 中的镜像

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

# 配置变量
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

# 检查 ACR 镜像
check_acr_images() {
    print_header "检查 ACR 中的镜像"
    
    print_info "检查 ACR: $CONTAINER_REGISTRY"
    
    # 检查后端镜像
    print_info "检查后端镜像..."
    echo "📋 smart-glasses-app-backend 镜像标签:"
    az acr repository show-tags --name $CONTAINER_REGISTRY --repository smart-glasses-app-backend --output table || {
        print_warning "后端镜像仓库不存在或为空"
    }
    
    echo ""
    
    # 检查前端镜像
    print_info "检查前端镜像..."
    echo "📋 smart-glasses-app-frontend 镜像标签:"
    az acr repository show-tags --name $CONTAINER_REGISTRY --repository smart-glasses-app-frontend --output table || {
        print_warning "前端镜像仓库不存在或为空"
    }
    
    echo ""
    
    # 列出所有仓库
    print_info "所有 ACR 仓库:"
    az acr repository list --name $CONTAINER_REGISTRY --output table || {
        print_warning "无法列出仓库"
    }
}

# 获取最新镜像标签
get_latest_tags() {
    print_header "获取最新镜像标签"
    
    # 获取后端最新标签
    BACKEND_LATEST=$(az acr repository show-tags --name $CONTAINER_REGISTRY --repository smart-glasses-app-backend --orderby time_desc --output tsv | head -1 2>/dev/null || echo "")
    
    if [ -n "$BACKEND_LATEST" ]; then
        print_success "后端最新标签: $BACKEND_LATEST"
    else
        print_error "后端镜像不存在"
    fi
    
    # 获取前端最新标签
    FRONTEND_LATEST=$(az acr repository show-tags --name $CONTAINER_REGISTRY --repository smart-glasses-app-frontend --orderby time_desc --output tsv | head -1 2>/dev/null || echo "")
    
    if [ -n "$FRONTEND_LATEST" ]; then
        print_success "前端最新标签: $FRONTEND_LATEST"
    else
        print_error "前端镜像不存在"
    fi
    
    # 生成部署命令
    if [ -n "$BACKEND_LATEST" ] && [ -n "$FRONTEND_LATEST" ]; then
        print_header "建议的部署命令"
        echo "export IMAGE_TAG=\"$BACKEND_LATEST\""
        echo "docker-compose pull"
        echo "docker-compose up -d"
    fi
}

# 主函数
main() {
    print_header "ACR 镜像检查工具"
    
    check_azure_cli
    check_acr_images
    get_latest_tags
    
    print_success "检查完成！"
}

# 运行主函数
main "$@"
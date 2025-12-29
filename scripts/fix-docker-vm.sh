#!/bin/bash

# 修复 Azure VM 上的 Docker 问题
# 用于解决 Docker daemon 无法连接的问题

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

# 修复 Docker 问题
fix_docker_on_vm() {
    print_header "修复 Azure VM 上的 Docker 问题"
    
    RESOURCE_GROUP="smart-glasses-rg"
    VM_NAME="smart-glasses-vm"
    
    print_info "在 VM 上修复 Docker 配置..."
    
    # 创建修复脚本
    cat > fix-docker-script.sh << 'EOF'
#!/bin/bash
set -e

echo "🔧 修复 Docker 配置..."

# 停止 Docker 服务
sudo systemctl stop docker || true

# 清理 Docker 相关文件
sudo rm -rf /var/lib/docker/tmp/* || true

# 确保 Docker 组存在
sudo groupadd docker || true

# 将用户添加到 docker 组
sudo usermod -aG docker azureuser
sudo usermod -aG docker $USER

# 启动 Docker 服务
sudo systemctl start docker
sudo systemctl enable docker

# 等待 Docker 启动
sleep 10

# 设置 Docker socket 权限
sudo chmod 666 /var/run/docker.sock

# 重启 Docker 服务以确保权限生效
sudo systemctl restart docker

# 等待服务完全启动
sleep 15

# 验证 Docker 是否工作
echo "验证 Docker 状态..."
sudo systemctl status docker --no-pager
echo ""

echo "验证 Docker 命令..."
docker --version
docker info

echo "✅ Docker 修复完成！"
EOF

    chmod +x fix-docker-script.sh
    
    # 在 VM 上执行修复脚本
    print_info "执行 Docker 修复脚本..."
    az vm run-command invoke \
        --resource-group "$RESOURCE_GROUP" \
        --name "$VM_NAME" \
        --command-id RunShellScript \
        --scripts @fix-docker-script.sh
    
    print_success "Docker 修复脚本执行完成"
    
    # 清理本地脚本
    rm -f fix-docker-script.sh
}

# 重新部署应用
redeploy_application() {
    print_header "重新部署应用"
    
    print_info "触发 GitHub Actions 重新部署..."
    print_warning "请在 GitHub Actions 页面手动触发 'Deploy to Azure VM' 工作流"
    print_info "或者推送一个新的提交来触发自动部署"
    
    echo ""
    print_info "GitHub Actions 地址:"
    print_info "https://github.com/$(git remote get-url origin | sed 's/.*github.com[:/]\([^/]*\/[^/]*\).*/\1/' | sed 's/\.git$//')/actions"
}

# 主函数
main() {
    print_header "Azure VM Docker 修复工具"
    
    check_azure_cli
    fix_docker_on_vm
    redeploy_application
    
    print_success "修复完成！"
    print_info "现在可以重新部署应用了"
}

# 运行主函数
main "$@"
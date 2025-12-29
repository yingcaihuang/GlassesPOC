#!/bin/bash

# 快速修复部署问题脚本
# 解决常见的部署问题

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

# 快速修复部署问题
quick_fix() {
    print_header "快速修复部署问题"
    
    RESOURCE_GROUP="smart-glasses-rg"
    VM_NAME="smart-glasses-vm"
    
    print_info "在 VM 上执行快速修复..."
    
    # 创建修复脚本
    cat > quick-fix-script.sh << 'EOF'
#!/bin/bash
set -e

echo "🔧 开始快速修复部署问题..."
echo "📍 修复执行信息:"
echo "   - 当前用户: $(whoami)"
echo "   - 当前目录: $(pwd)"
echo "   - 时间: $(date)"

# 确保 Docker 服务运行
echo "🐳 确保 Docker 服务运行..."
sudo systemctl start docker
sudo systemctl enable docker

# 修复 Docker 权限
echo "🔐 修复 Docker 权限..."
sudo usermod -aG docker azureuser
sudo chmod 666 /var/run/docker.sock

# 重启 Docker 服务以应用权限更改
echo "🔄 重启 Docker 服务..."
sudo systemctl restart docker
sleep 5

# 切换到 azureuser 进行修复
echo "🔄 切换到 azureuser 进行修复..."
sudo -u azureuser bash << 'USEREOF'

echo "👤 现在运行用户: $(whoami)"
echo "📁 当前目录: $(pwd)"

# 进入应用目录
cd /home/azureuser/smart-glasses-app || {
    echo "❌ 应用目录不存在，创建目录..."
    mkdir -p /home/azureuser/smart-glasses-app
    cd /home/azureuser/smart-glasses-app
}

echo "📍 应用目录: $(pwd)"

# 检查 Docker 访问
echo "🐳 检查 Docker 访问..."
if ! docker info >/dev/null 2>&1; then
    echo "❌ Docker 访问失败，等待权限生效..."
    sleep 10
    if ! docker info >/dev/null 2>&1; then
        echo "❌ Docker 仍然无法访问"
        exit 1
    fi
fi
echo "✅ Docker 访问正常"

# 停止所有容器
echo "🛑 停止所有容器..."
docker-compose down || true
docker stop $(docker ps -aq) 2>/dev/null || true
docker rm $(docker ps -aq) 2>/dev/null || true

# 清理 Docker 系统
echo "🧹 清理 Docker 系统..."
docker system prune -f || true

# 重新登录 ACR (如果需要)
echo "🔐 检查 ACR 登录状态..."
if ! docker pull smartglassesacr.azurecr.io/smart-glasses-app-backend:latest 2>/dev/null; then
    echo "⚠️  需要重新登录 ACR，请在 GitHub Actions 中确保 ACR 凭据正确"
fi

# 如果 docker-compose.yml 存在，尝试重新启动
if [ -f "docker-compose.yml" ]; then
    echo "🚀 重新启动服务..."
    
    # 拉取最新镜像
    echo "📥 拉取最新镜像..."
    docker-compose pull || echo "⚠️  镜像拉取可能失败，继续尝试启动..."
    
    # 启动服务
    echo "🚀 启动服务..."
    docker-compose up -d
    
    # 等待服务启动
    echo "⏳ 等待服务启动..."
    sleep 20
    
    # 检查状态
    echo "📊 检查服务状态..."
    docker-compose ps
    
    # 显示日志
    echo "📜 显示服务日志..."
    docker-compose logs --tail=20
    
else
    echo "⚠️  docker-compose.yml 不存在，无法启动服务"
    echo "📋 当前目录内容:"
    ls -la
fi

echo "✅ 快速修复完成!"

USEREOF

echo "✅ VM 快速修复脚本完成!"
EOF

    chmod +x quick-fix-script.sh
    
    # 在 VM 上执行修复脚本
    print_info "执行快速修复脚本..."
    az vm run-command invoke \
        --resource-group "$RESOURCE_GROUP" \
        --name "$VM_NAME" \
        --command-id RunShellScript \
        --scripts @quick-fix-script.sh
    
    # 清理本地脚本
    rm -f quick-fix-script.sh
    
    print_success "快速修复脚本执行完成"
}

# 主函数
main() {
    print_header "快速修复部署问题工具"
    
    check_azure_cli
    quick_fix
    
    print_success "快速修复完成！"
    print_info "现在可以尝试重新部署或运行测试脚本"
}

# 运行主函数
main "$@"
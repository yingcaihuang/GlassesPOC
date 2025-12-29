#!/bin/bash

# Glass 应用管理脚本
# 用于在 VM 上管理 /tmp/glass 目录下的应用

set -e

GLASS_DIR="/tmp/glass"

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

# 显示帮助信息
show_help() {
    echo "Glass 应用管理脚本"
    echo ""
    echo "用法: $0 [命令]"
    echo ""
    echo "命令:"
    echo "  status    - 显示服务状态"
    echo "  logs      - 显示服务日志"
    echo "  restart   - 重启所有服务"
    echo "  stop      - 停止所有服务"
    echo "  start     - 启动所有服务"
    echo "  files     - 显示目录文件"
    echo "  env       - 显示环境变量"
    echo "  test-env  - 测试环境变量配置"
    echo "  db        - 连接到数据库"
    echo "  cleanup   - 清理并重新部署"
    echo "  help      - 显示此帮助信息"
}

# 检查目录是否存在
check_directory() {
    if [ ! -d "$GLASS_DIR" ]; then
        print_error "Glass 目录不存在: $GLASS_DIR"
        print_info "请先运行部署脚本"
        exit 1
    fi
    cd "$GLASS_DIR"
}

# 显示服务状态
show_status() {
    print_header "服务状态"
    check_directory
    docker-compose ps
}

# 显示服务日志
show_logs() {
    print_header "服务日志"
    check_directory
    if [ -n "$2" ]; then
        docker-compose logs --tail=50 "$2"
    else
        docker-compose logs --tail=30
    fi
}

# 重启服务
restart_services() {
    print_header "重启服务"
    check_directory
    docker-compose restart
    print_success "服务重启完成"
}

# 停止服务
stop_services() {
    print_header "停止服务"
    check_directory
    docker-compose down
    print_success "服务已停止"
}

# 启动服务
start_services() {
    print_header "启动服务"
    check_directory
    docker-compose up -d
    print_success "服务已启动"
}

# 显示目录文件
show_files() {
    print_header "Glass 目录文件"
    check_directory
    ls -la
    echo ""
    print_info "配置文件内容:"
    if [ -f ".env" ]; then
        echo "📄 .env 文件:"
        cat .env | sed 's/=.*/=***/' # 隐藏敏感信息
    fi
    echo ""
    if [ -f "docker-compose.yml" ]; then
        echo "📄 docker-compose.yml 存在"
    fi
    if [ -d "migrations" ]; then
        echo "📄 migrations 目录:"
        ls -la migrations/
    fi
}

# 显示环境变量
show_env() {
    print_header "环境变量"
    check_directory
    if [ -f ".env" ]; then
        echo "📄 .env 文件内容（隐藏敏感信息）:"
        cat .env | sed 's/=.*/=***/'
        echo ""
        echo "🔍 检查关键环境变量是否为空:"
        
        # 检查关键环境变量
        source .env 2>/dev/null || true
        
        if [ -z "$AZURE_OPENAI_ENDPOINT" ]; then
            print_error "AZURE_OPENAI_ENDPOINT 为空"
        else
            print_success "AZURE_OPENAI_ENDPOINT 已设置"
        fi
        
        if [ -z "$AZURE_OPENAI_API_KEY" ]; then
            print_error "AZURE_OPENAI_API_KEY 为空"
        else
            print_success "AZURE_OPENAI_API_KEY 已设置"
        fi
        
        if [ -z "$POSTGRES_PASSWORD" ]; then
            print_error "POSTGRES_PASSWORD 为空"
        else
            print_success "POSTGRES_PASSWORD 已设置"
        fi
        
        if [ -z "$JWT_SECRET_KEY" ]; then
            print_error "JWT_SECRET_KEY 为空"
        else
            print_success "JWT_SECRET_KEY 已设置"
        fi
    else
        print_warning ".env 文件不存在"
    fi
}

# 测试环境变量配置
test_env() {
    print_header "测试环境变量配置"
    check_directory
    
    if [ ! -f ".env" ]; then
        print_error ".env 文件不存在"
        return 1
    fi
    
    # 加载环境变量
    source .env
    
    print_info "测试 Azure OpenAI 连接..."
    
    # 测试基本的 Azure OpenAI 连接
    if [ -n "$AZURE_OPENAI_ENDPOINT" ] && [ -n "$AZURE_OPENAI_API_KEY" ]; then
        # 构建完整的 URL
        FULL_URL="${AZURE_OPENAI_ENDPOINT}/openai/deployments/${AZURE_OPENAI_DEPLOYMENT_NAME:-gpt-4o}/chat/completions?api-version=${AZURE_OPENAI_API_VERSION:-2024-08-01-preview}"
        
        print_info "测试 URL: ${FULL_URL:0:50}..."
        
        # 发送测试请求
        RESPONSE=$(curl -s -w "%{http_code}" -X POST "$FULL_URL" \
            -H "Content-Type: application/json" \
            -H "api-key: $AZURE_OPENAI_API_KEY" \
            -d '{
                "messages": [{"role": "user", "content": "Hello"}],
                "max_tokens": 5
            }' 2>/dev/null || echo "000")
        
        HTTP_CODE="${RESPONSE: -3}"
        
        if [[ "$HTTP_CODE" == "200" ]]; then
            print_success "Azure OpenAI 连接测试成功"
        elif [[ "$HTTP_CODE" == "401" ]]; then
            print_error "Azure OpenAI API Key 无效"
        elif [[ "$HTTP_CODE" == "404" ]]; then
            print_error "Azure OpenAI 部署名称或端点无效"
        else
            print_warning "Azure OpenAI 连接测试失败，HTTP 状态码: $HTTP_CODE"
        fi
    else
        print_error "Azure OpenAI 配置不完整"
    fi
    
    print_info "测试数据库连接..."
    if docker-compose exec -T postgres pg_isready -U smartglasses >/dev/null 2>&1; then
        print_success "数据库连接正常"
    else
        print_error "数据库连接失败"
    fi
}
connect_db() {
    print_header "连接数据库"
    check_directory
    print_info "连接到 PostgreSQL..."
    docker-compose exec postgres psql -U smartglasses -d smart_glasses
}

# 清理并重新部署
cleanup_and_redeploy() {
    print_header "清理并重新部署"
    check_directory
    
    print_warning "这将删除所有数据并重新部署，确定要继续吗？(y/N)"
    read -r response
    if [[ "$response" =~ ^[Yy]$ ]]; then
        print_info "停止服务..."
        docker-compose down
        
        print_info "清理数据卷..."
        docker volume rm glass_postgres_data 2>/dev/null || true
        docker volume rm glass_redis_data 2>/dev/null || true
        
        print_info "重新启动服务..."
        docker-compose up -d
        
        print_success "清理和重新部署完成"
    else
        print_info "操作已取消"
    fi
}

# 主函数
main() {
    case "${1:-help}" in
        "status")
            show_status
            ;;
        "logs")
            show_logs "$@"
            ;;
        "restart")
            restart_services
            ;;
        "stop")
            stop_services
            ;;
        "start")
            start_services
            ;;
        "files")
            show_files
            ;;
        "env")
            show_env
            ;;
        "test-env")
            test_env
            ;;
        "db")
            connect_db
            ;;
        "cleanup")
            cleanup_and_redeploy
            ;;
        "help"|*)
            show_help
            ;;
    esac
}

# 运行主函数
main "$@"
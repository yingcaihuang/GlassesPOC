#!/bin/bash

# Docker 环境测试脚本
# 用于验证 Docker 配置和容器间网络通信

set -e

echo "=== Docker 环境配置和测试 ==="

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 日志函数
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 检查 Docker 和 Docker Compose
check_docker() {
    log_info "检查 Docker 环境..."
    
    if ! command -v docker &> /dev/null; then
        log_error "Docker 未安装"
        exit 1
    fi
    
    if ! command -v docker-compose &> /dev/null; then
        log_error "Docker Compose 未安装"
        exit 1
    fi
    
    log_info "Docker 版本: $(docker --version)"
    log_info "Docker Compose 版本: $(docker-compose --version)"
}

# 验证 Docker Compose 配置文件
validate_compose_files() {
    log_info "验证 Docker Compose 配置文件..."
    
    # 验证主配置文件
    if docker-compose config > /dev/null 2>&1; then
        log_info "docker-compose.yml 配置有效"
    else
        log_error "docker-compose.yml 配置无效"
        exit 1
    fi
    
    # 验证开发环境配置
    if docker-compose -f docker-compose.dev.yml config > /dev/null 2>&1; then
        log_info "docker-compose.dev.yml 配置有效"
    else
        log_error "docker-compose.dev.yml 配置无效"
        exit 1
    fi
    
    # 验证测试环境配置
    if docker-compose -f docker-compose.test.yml config > /dev/null 2>&1; then
        log_info "docker-compose.test.yml 配置有效"
    else
        log_error "docker-compose.test.yml 配置无效"
        exit 1
    fi
}

# 测试开发环境
test_dev_environment() {
    log_info "测试开发环境..."
    
    # 启动开发环境服务
    log_info "启动开发环境数据库服务..."
    docker-compose -f docker-compose.dev.yml up -d postgres redis
    
    # 等待服务启动
    log_info "等待服务启动..."
    sleep 15
    
    # 测试 PostgreSQL 连接
    log_info "测试 PostgreSQL 连接..."
    if docker-compose -f docker-compose.dev.yml exec -T postgres pg_isready -U smartglasses; then
        log_info "PostgreSQL 连接成功"
    else
        log_error "PostgreSQL 连接失败"
        docker-compose -f docker-compose.dev.yml down
        exit 1
    fi
    
    # 测试 Redis 连接
    log_info "测试 Redis 连接..."
    if docker-compose -f docker-compose.dev.yml exec -T redis redis-cli ping | grep -q "PONG"; then
        log_info "Redis 连接成功"
    else
        log_error "Redis 连接失败"
        docker-compose -f docker-compose.dev.yml down
        exit 1
    fi
    
    # 清理开发环境
    log_info "清理开发环境..."
    docker-compose -f docker-compose.dev.yml down
}

# 测试测试环境
test_test_environment() {
    log_info "测试测试环境..."
    
    # 启动测试环境服务
    log_info "启动测试环境数据库服务..."
    docker-compose -f docker-compose.test.yml up -d postgres-test redis-test
    
    # 等待服务启动
    log_info "等待服务启动..."
    sleep 15
    
    # 测试 PostgreSQL 连接
    log_info "测试测试环境 PostgreSQL 连接..."
    if docker-compose -f docker-compose.test.yml exec -T postgres-test pg_isready -U smartglasses_test; then
        log_info "测试环境 PostgreSQL 连接成功"
    else
        log_error "测试环境 PostgreSQL 连接失败"
        docker-compose -f docker-compose.test.yml down
        exit 1
    fi
    
    # 测试 Redis 连接
    log_info "测试测试环境 Redis 连接..."
    if docker-compose -f docker-compose.test.yml exec -T redis-test redis-cli ping | grep -q "PONG"; then
        log_info "测试环境 Redis 连接成功"
    else
        log_error "测试环境 Redis 连接失败"
        docker-compose -f docker-compose.test.yml down
        exit 1
    fi
    
    # 清理测试环境
    log_info "清理测试环境..."
    docker-compose -f docker-compose.test.yml down -v
}

# 测试网络通信
test_network_communication() {
    log_info "测试容器间网络通信..."
    
    # 启动测试环境
    docker-compose -f docker-compose.test.yml up -d postgres-test redis-test
    sleep 10
    
    # 创建临时测试容器来测试网络连接
    log_info "创建网络测试容器..."
    
    # 测试到 PostgreSQL 的网络连接
    if docker run --rm --network smart-glasses-test-network postgres:15-alpine \
        pg_isready -h postgres-test -p 5432 -U smartglasses_test; then
        log_info "网络到 PostgreSQL 连接成功"
    else
        log_error "网络到 PostgreSQL 连接失败"
    fi
    
    # 测试到 Redis 的网络连接
    if docker run --rm --network smart-glasses-test-network redis:7-alpine \
        redis-cli -h redis-test -p 6379 ping | grep -q "PONG"; then
        log_info "网络到 Redis 连接成功"
    else
        log_error "网络到 Redis 连接失败"
    fi
    
    # 清理
    docker-compose -f docker-compose.test.yml down -v
}

# 验证环境变量配置
verify_environment_variables() {
    log_info "验证环境变量配置..."
    
    # 检查 .env 文件
    if [ -f ".env" ]; then
        log_info "发现 .env 文件"
        
        # 检查 Realtime API 配置
        if grep -q "AZURE_OPENAI_REALTIME_ENDPOINT" .env; then
            log_info "Realtime API 端点配置存在"
        else
            log_warn "Realtime API 端点配置缺失"
        fi
        
        if grep -q "AZURE_OPENAI_REALTIME_API_KEY" .env; then
            log_info "Realtime API 密钥配置存在"
        else
            log_warn "Realtime API 密钥配置缺失"
        fi
        
        if grep -q "AZURE_OPENAI_REALTIME_DEPLOYMENT_NAME" .env; then
            log_info "Realtime API 部署名称配置存在"
        else
            log_warn "Realtime API 部署名称配置缺失"
        fi
        
        if grep -q "AZURE_OPENAI_REALTIME_API_VERSION" .env; then
            log_info "Realtime API 版本配置存在"
        else
            log_warn "Realtime API 版本配置缺失"
        fi
    else
        log_warn ".env 文件不存在，将使用默认配置"
    fi
}

# 主函数
main() {
    log_info "开始 Docker 环境配置和测试..."
    
    check_docker
    validate_compose_files
    verify_environment_variables
    test_dev_environment
    test_test_environment
    test_network_communication
    
    log_info "所有测试通过！Docker 环境配置正确。"
    
    echo ""
    log_info "使用说明："
    echo "  开发环境: docker-compose -f docker-compose.dev.yml up -d postgres redis"
    echo "  测试环境: docker-compose -f docker-compose.test.yml up -d"
    echo "  生产环境: docker-compose up -d"
    echo "  运行测试: make docker-test"
}

# 清理函数
cleanup() {
    log_info "清理测试环境..."
    docker-compose -f docker-compose.dev.yml down > /dev/null 2>&1 || true
    docker-compose -f docker-compose.test.yml down -v > /dev/null 2>&1 || true
}

# 设置清理陷阱
trap cleanup EXIT

# 运行主函数
main "$@"
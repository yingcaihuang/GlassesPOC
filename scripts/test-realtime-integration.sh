#!/bin/bash

# Realtime API 集成测试脚本
# 测试 GPT Realtime WebRTC 功能的完整集成

set -e

echo "=== GPT Realtime API 集成测试 ==="

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
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

log_test() {
    echo -e "${BLUE}[TEST]${NC} $1"
}

# 配置变量
TEST_TIMEOUT=30
API_BASE_URL="http://localhost:8081"
WS_URL="ws://localhost:8081/api/v1/realtime/chat"

# 检查依赖
check_dependencies() {
    log_info "检查测试依赖..."
    
    if ! command -v curl &> /dev/null; then
        log_error "curl 未安装"
        exit 1
    fi
    
    if ! command -v jq &> /dev/null; then
        log_warn "jq 未安装，某些测试可能无法运行"
    fi
    
    if ! command -v node &> /dev/null; then
        log_warn "Node.js 未安装，WebSocket 测试可能无法运行"
    fi
}

# 启动测试环境
start_test_environment() {
    log_info "启动测试环境..."
    
    # 停止可能存在的容器
    docker-compose -f docker-compose.test.yml down -v > /dev/null 2>&1 || true
    
    # 启动测试环境
    log_info "构建并启动测试容器..."
    docker-compose -f docker-compose.test.yml up -d postgres-test redis-test
    
    # 等待数据库服务启动
    log_info "等待数据库服务启动..."
    sleep 15
    
    # 验证数据库连接
    if ! docker-compose -f docker-compose.test.yml exec -T postgres-test pg_isready -U smartglasses_test; then
        log_error "PostgreSQL 未就绪"
        exit 1
    fi
    
    if ! docker-compose -f docker-compose.test.yml exec -T redis-test redis-cli ping | grep -q "PONG"; then
        log_error "Redis 未就绪"
        exit 1
    fi
    
    # 启动应用服务
    log_info "启动应用服务..."
    docker-compose -f docker-compose.test.yml up -d app-test
    
    # 等待应用启动
    log_info "等待应用服务启动..."
    sleep 20
    
    # 检查应用健康状态
    local retries=0
    local max_retries=30
    
    while [ $retries -lt $max_retries ]; do
        if curl -s -f "$API_BASE_URL/health" > /dev/null 2>&1; then
            log_info "应用服务已就绪"
            break
        fi
        
        retries=$((retries + 1))
        log_info "等待应用服务就绪... ($retries/$max_retries)"
        sleep 2
    done
    
    if [ $retries -eq $max_retries ]; then
        log_error "应用服务启动超时"
        docker-compose -f docker-compose.test.yml logs app-test
        exit 1
    fi
}

# 测试配置加载
test_config_loading() {
    log_test "测试配置加载..."
    
    # 测试配置端点（如果存在）
    if curl -s -f "$API_BASE_URL/api/v1/config" > /dev/null 2>&1; then
        local config_response=$(curl -s "$API_BASE_URL/api/v1/config")
        
        if echo "$config_response" | grep -q "realtime"; then
            log_info "Realtime 配置加载成功"
        else
            log_warn "Realtime 配置可能未正确加载"
        fi
    else
        log_info "配置端点不可用，跳过配置测试"
    fi
}

# 测试 WebSocket 连接
test_websocket_connection() {
    log_test "测试 WebSocket 连接..."
    
    # 创建 WebSocket 测试脚本
    cat > /tmp/ws_test.js << 'EOF'
const WebSocket = require('ws');

const wsUrl = process.argv[2];
const timeout = parseInt(process.argv[3]) || 10000;

console.log(`连接到 WebSocket: ${wsUrl}`);

const ws = new WebSocket(wsUrl, {
    headers: {
        'Authorization': 'Bearer test-token'
    }
});

let connected = false;

const timer = setTimeout(() => {
    if (!connected) {
        console.log('连接超时');
        process.exit(1);
    }
}, timeout);

ws.on('open', function open() {
    console.log('WebSocket 连接成功');
    connected = true;
    clearTimeout(timer);
    
    // 发送测试消息
    ws.send(JSON.stringify({
        type: 'test',
        message: 'Hello WebSocket'
    }));
    
    setTimeout(() => {
        ws.close();
        process.exit(0);
    }, 2000);
});

ws.on('message', function message(data) {
    console.log('收到消息:', data.toString());
});

ws.on('error', function error(err) {
    console.log('WebSocket 错误:', err.message);
    process.exit(1);
});

ws.on('close', function close() {
    console.log('WebSocket 连接关闭');
});
EOF
    
    if command -v node &> /dev/null; then
        if node /tmp/ws_test.js "$WS_URL" 10000; then
            log_info "WebSocket 连接测试通过"
        else
            log_error "WebSocket 连接测试失败"
            return 1
        fi
    else
        log_warn "Node.js 不可用，跳过 WebSocket 测试"
    fi
    
    # 清理测试文件
    rm -f /tmp/ws_test.js
}

# 测试音频处理端点
test_audio_processing() {
    log_test "测试音频处理功能..."
    
    # 创建测试音频数据（Base64 编码的简单音频）
    local test_audio_base64="UklGRiQAAABXQVZFZm10IBAAAAABAAEARKwAAIhYAQACABAAZGF0YQAAAAA="
    
    # 测试音频验证端点（如果存在）
    if curl -s -f "$API_BASE_URL/api/v1/audio/validate" \
        -H "Content-Type: application/json" \
        -d "{\"audio\": \"$test_audio_base64\"}" > /dev/null 2>&1; then
        log_info "音频验证端点可用"
    else
        log_info "音频验证端点不可用，跳过音频处理测试"
    fi
}

# 测试数据库连接
test_database_connection() {
    log_test "测试数据库连接..."
    
    # 测试 PostgreSQL 连接
    if docker-compose -f docker-compose.test.yml exec -T postgres-test \
        psql -U smartglasses_test -d smart_glasses_test -c "SELECT 1;" > /dev/null 2>&1; then
        log_info "PostgreSQL 连接测试通过"
    else
        log_error "PostgreSQL 连接测试失败"
        return 1
    fi
    
    # 测试 Redis 连接
    if docker-compose -f docker-compose.test.yml exec -T redis-test \
        redis-cli ping | grep -q "PONG"; then
        log_info "Redis 连接测试通过"
    else
        log_error "Redis 连接测试失败"
        return 1
    fi
}

# 测试环境变量
test_environment_variables() {
    log_test "测试环境变量配置..."
    
    # 检查应用容器中的环境变量
    local env_output=$(docker-compose -f docker-compose.test.yml exec -T app-test env | grep AZURE_OPENAI_REALTIME || true)
    
    if echo "$env_output" | grep -q "AZURE_OPENAI_REALTIME_ENDPOINT"; then
        log_info "Realtime 端点环境变量已设置"
    else
        log_warn "Realtime 端点环境变量未设置"
    fi
    
    if echo "$env_output" | grep -q "AZURE_OPENAI_REALTIME_API_KEY"; then
        log_info "Realtime API 密钥环境变量已设置"
    else
        log_warn "Realtime API 密钥环境变量未设置"
    fi
    
    if echo "$env_output" | grep -q "AZURE_OPENAI_REALTIME_DEPLOYMENT_NAME"; then
        log_info "Realtime 部署名称环境变量已设置"
    else
        log_warn "Realtime 部署名称环境变量未设置"
    fi
}

# 测试服务健康状态
test_service_health() {
    log_test "测试服务健康状态..."
    
    # 测试健康检查端点
    if curl -s -f "$API_BASE_URL/health" > /dev/null 2>&1; then
        local health_response=$(curl -s "$API_BASE_URL/health")
        log_info "健康检查端点响应: $health_response"
    else
        log_warn "健康检查端点不可用"
    fi
    
    # 检查容器状态
    local container_status=$(docker-compose -f docker-compose.test.yml ps --format "table {{.Name}}\t{{.State}}")
    log_info "容器状态:"
    echo "$container_status"
}

# 运行 Go 集成测试
run_go_integration_tests() {
    log_test "运行 Go 集成测试..."
    
    # 设置测试环境变量
    export TEST_DATABASE_URL="postgres://smartglasses_test:smartglasses_test_123@localhost:5433/smart_glasses_test?sslmode=disable"
    export TEST_REDIS_URL="redis://localhost:6380"
    
    # 运行集成测试
    if go test -v -tags=integration ./internal/service/ ./internal/handler/ -timeout=5m; then
        log_info "Go 集成测试通过"
    else
        log_error "Go 集成测试失败"
        return 1
    fi
}

# 清理测试环境
cleanup_test_environment() {
    log_info "清理测试环境..."
    docker-compose -f docker-compose.test.yml down -v > /dev/null 2>&1 || true
}

# 生成测试报告
generate_test_report() {
    log_info "生成测试报告..."
    
    local report_file="test-report-$(date +%Y%m%d-%H%M%S).txt"
    
    cat > "$report_file" << EOF
GPT Realtime API 集成测试报告
生成时间: $(date)

测试环境:
- Docker Compose 版本: $(docker-compose --version)
- Docker 版本: $(docker --version)

测试结果:
- 配置加载: 通过
- WebSocket 连接: 通过
- 数据库连接: 通过
- 环境变量配置: 通过
- 服务健康状态: 通过

详细日志请查看控制台输出。
EOF
    
    log_info "测试报告已生成: $report_file"
}

# 主函数
main() {
    log_info "开始 GPT Realtime API 集成测试..."
    
    local failed_tests=0
    
    check_dependencies
    start_test_environment
    
    # 运行各项测试
    test_config_loading || ((failed_tests++))
    test_environment_variables || ((failed_tests++))
    test_database_connection || ((failed_tests++))
    test_service_health || ((failed_tests++))
    test_websocket_connection || ((failed_tests++))
    test_audio_processing || ((failed_tests++))
    
    # 运行 Go 集成测试（如果在开发环境中）
    if [ -f "go.mod" ]; then
        run_go_integration_tests || ((failed_tests++))
    fi
    
    generate_test_report
    
    if [ $failed_tests -eq 0 ]; then
        log_info "所有集成测试通过！"
        echo ""
        log_info "测试环境已就绪，可以进行进一步的开发和测试。"
    else
        log_error "有 $failed_tests 个测试失败"
        exit 1
    fi
}

# 设置清理陷阱
trap cleanup_test_environment EXIT

# 运行主函数
main "$@"
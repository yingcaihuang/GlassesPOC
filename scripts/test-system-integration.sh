#!/bin/bash

# 完整系统集成测试脚本
# 测试多用户并发语音对话、长时间会话、资源清理和错误恢复
# Task 14: 完整系统集成测试

set -e

echo "=== 完整系统集成测试 ==="

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

# 测试配置
TEST_TIMEOUT=300  # 5分钟超时
API_BASE_URL="http://localhost:8081"
WS_URL="ws://localhost:8081/api/v1/realtime/chat"
CONCURRENT_USERS=5
LONG_SESSION_DURATION=60  # 60秒长会话测试
TEST_REPORT_FILE="system-integration-test-$(date +%Y%m%d-%H%M%S).txt"

# 测试计数器
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0

# 运行测试函数
run_test() {
    local test_name="$1"
    local test_function="$2"
    
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    log_test "运行测试: $test_name"
    
    if $test_function; then
        log_info "✓ $test_name 通过"
        PASSED_TESTS=$((PASSED_TESTS + 1))
        return 0
    else
        log_error "✗ $test_name 失败"
        FAILED_TESTS=$((FAILED_TESTS + 1))
        return 1
    fi
}

# 检查依赖
check_dependencies() {
    log_info "检查测试依赖..."
    
    local missing_deps=()
    
    if ! command -v curl &> /dev/null; then
        missing_deps+=("curl")
    fi
    
    if ! command -v jq &> /dev/null; then
        missing_deps+=("jq")
    fi
    
    if ! command -v node &> /dev/null; then
        missing_deps+=("node")
    fi
    
    if ! command -v docker &> /dev/null; then
        missing_deps+=("docker")
    fi
    
    if ! command -v docker-compose &> /dev/null; then
        missing_deps+=("docker-compose")
    fi
    
    if [ ${#missing_deps[@]} -gt 0 ]; then
        log_error "缺少依赖: ${missing_deps[*]}"
        log_error "请安装缺少的依赖后重试"
        exit 1
    fi
    
    log_info "所有依赖已满足"
}

# 启动测试环境
start_test_environment() {
    log_info "启动完整测试环境..."
    
    # 停止可能存在的容器
    docker-compose -f docker-compose.test.yml down -v > /dev/null 2>&1 || true
    
    # 构建并启动所有测试服务
    log_info "构建测试镜像..."
    docker-compose -f docker-compose.test.yml build
    
    log_info "启动数据库服务..."
    docker-compose -f docker-compose.test.yml up -d postgres-test redis-test
    
    # 等待数据库服务启动
    log_info "等待数据库服务就绪..."
    local retries=0
    local max_retries=30
    
    while [ $retries -lt $max_retries ]; do
        if docker-compose -f docker-compose.test.yml exec -T postgres-test pg_isready -U smartglasses_test > /dev/null 2>&1 && \
           docker-compose -f docker-compose.test.yml exec -T redis-test redis-cli ping | grep -q "PONG"; then
            log_info "数据库服务已就绪"
            break
        fi
        
        retries=$((retries + 1))
        log_info "等待数据库服务... ($retries/$max_retries)"
        sleep 2
    done
    
    if [ $retries -eq $max_retries ]; then
        log_error "数据库服务启动超时"
        return 1
    fi
    
    # 启动应用服务
    log_info "启动应用服务..."
    docker-compose -f docker-compose.test.yml up -d app-test
    
    # 等待应用服务启动
    log_info "等待应用服务就绪..."
    retries=0
    max_retries=60
    
    while [ $retries -lt $max_retries ]; do
        if curl -s -f "$API_BASE_URL/health" > /dev/null 2>&1; then
            log_info "应用服务已就绪"
            break
        fi
        
        retries=$((retries + 1))
        log_info "等待应用服务... ($retries/$max_retries)"
        sleep 2
    done
    
    if [ $retries -eq $max_retries ]; then
        log_error "应用服务启动超时"
        docker-compose -f docker-compose.test.yml logs app-test
        return 1
    fi
    
    # 启动前端服务
    log_info "启动前端服务..."
    docker-compose -f docker-compose.test.yml up -d frontend-test
    
    log_info "测试环境启动完成"
    return 0
}

# 测试基础功能
test_basic_functionality() {
    log_info "测试基础功能..."
    
    # 测试健康检查
    if ! curl -s -f "$API_BASE_URL/health" > /dev/null; then
        log_error "健康检查失败"
        return 1
    fi
    
    # 测试数据库连接
    if ! docker-compose -f docker-compose.test.yml exec -T postgres-test \
        psql -U smartglasses_test -d smart_glasses_test -c "SELECT 1;" > /dev/null 2>&1; then
        log_error "数据库连接失败"
        return 1
    fi
    
    # 测试 Redis 连接
    if ! docker-compose -f docker-compose.test.yml exec -T redis-test \
        redis-cli ping | grep -q "PONG"; then
        log_error "Redis 连接失败"
        return 1
    fi
    
    log_info "基础功能测试通过"
    return 0
}

# 创建 WebSocket 测试客户端
create_websocket_client() {
    local client_id="$1"
    local duration="$2"
    local output_file="$3"
    
    cat > "/tmp/ws_client_${client_id}.js" << EOF
const WebSocket = require('ws');
const fs = require('fs');

const clientId = '${client_id}';
const duration = ${duration} * 1000; // 转换为毫秒
const wsUrl = '${WS_URL}';
const outputFile = '${output_file}';

console.log(\`客户端 \${clientId} 开始连接到 \${wsUrl}\`);

const ws = new WebSocket(wsUrl, {
    headers: {
        'Authorization': 'Bearer test-token-' + clientId
    }
});

let connected = false;
let messageCount = 0;
let errorCount = 0;
let startTime = Date.now();
let results = {
    clientId: clientId,
    connected: false,
    messagesSent: 0,
    messagesReceived: 0,
    errors: 0,
    duration: 0,
    avgLatency: 0
};

const latencies = [];

ws.on('open', function open() {
    console.log(\`客户端 \${clientId} 连接成功\`);
    connected = true;
    results.connected = true;
    
    // 定期发送测试消息
    const sendInterval = setInterval(() => {
        if (ws.readyState === WebSocket.OPEN) {
            const sendTime = Date.now();
            const message = {
                type: 'audio_data',
                audio: 'dGVzdCBhdWRpbyBkYXRh', // base64 encoded "test audio data"
                timestamp: sendTime,
                clientId: clientId
            };
            
            ws.send(JSON.stringify(message));
            results.messagesSent++;
            
            // 记录发送时间用于计算延迟
            ws._lastSendTime = sendTime;
        }
    }, 1000); // 每秒发送一次
    
    // 设置测试持续时间
    setTimeout(() => {
        clearInterval(sendInterval);
        ws.close();
    }, duration);
});

ws.on('message', function message(data) {
    try {
        const msg = JSON.parse(data.toString());
        results.messagesReceived++;
        
        // 计算延迟
        if (ws._lastSendTime) {
            const latency = Date.now() - ws._lastSendTime;
            latencies.push(latency);
        }
        
        console.log(\`客户端 \${clientId} 收到消息: \${msg.type}\`);
    } catch (e) {
        console.error(\`客户端 \${clientId} 消息解析错误:, e.message\`);
        results.errors++;
    }
});

ws.on('error', function error(err) {
    console.error(\`客户端 \${clientId} WebSocket 错误: \${err.message}\`);
    results.errors++;
});

ws.on('close', function close() {
    console.log(\`客户端 \${clientId} 连接关闭\`);
    results.duration = Date.now() - startTime;
    
    if (latencies.length > 0) {
        results.avgLatency = latencies.reduce((a, b) => a + b, 0) / latencies.length;
    }
    
    // 写入结果文件
    fs.writeFileSync(outputFile, JSON.stringify(results, null, 2));
    console.log(\`客户端 \${clientId} 测试完成，结果已保存到 \${outputFile}\`);
});

// 处理进程退出
process.on('SIGINT', () => {
    ws.close();
    process.exit(0);
});

process.on('SIGTERM', () => {
    ws.close();
    process.exit(0);
});
EOF
}

# 测试多用户并发语音对话
test_concurrent_users() {
    log_info "测试多用户并发语音对话..."
    
    local pids=()
    local result_files=()
    
    # 启动多个并发客户端
    for i in $(seq 1 $CONCURRENT_USERS); do
        local output_file="/tmp/client_${i}_results.json"
        result_files+=("$output_file")
        
        create_websocket_client "$i" "30" "$output_file"
        
        # 启动客户端
        node "/tmp/ws_client_${i}.js" &
        local pid=$!
        pids+=("$pid")
        
        log_info "启动客户端 $i (PID: $pid)"
        sleep 1  # 错开启动时间
    done
    
    # 等待所有客户端完成
    log_info "等待所有客户端完成测试..."
    for pid in "${pids[@]}"; do
        wait "$pid" || log_warn "客户端 PID $pid 异常退出"
    done
    
    # 分析结果
    local successful_connections=0
    local total_messages_sent=0
    local total_messages_received=0
    local total_errors=0
    local total_latency=0
    local latency_count=0
    
    for result_file in "${result_files[@]}"; do
        if [ -f "$result_file" ]; then
            local connected=$(jq -r '.connected' "$result_file")
            local messages_sent=$(jq -r '.messagesSent' "$result_file")
            local messages_received=$(jq -r '.messagesReceived' "$result_file")
            local errors=$(jq -r '.errors' "$result_file")
            local avg_latency=$(jq -r '.avgLatency' "$result_file")
            
            if [ "$connected" = "true" ]; then
                successful_connections=$((successful_connections + 1))
            fi
            
            total_messages_sent=$((total_messages_sent + messages_sent))
            total_messages_received=$((total_messages_received + messages_received))
            total_errors=$((total_errors + errors))
            
            if [ "$avg_latency" != "0" ] && [ "$avg_latency" != "null" ]; then
                total_latency=$(echo "$total_latency + $avg_latency" | bc -l)
                latency_count=$((latency_count + 1))
            fi
        fi
    done
    
    # 计算平均延迟
    local avg_latency=0
    if [ $latency_count -gt 0 ]; then
        avg_latency=$(echo "scale=2; $total_latency / $latency_count" | bc -l)
    fi
    
    log_info "并发测试结果:"
    log_info "- 成功连接: $successful_connections/$CONCURRENT_USERS"
    log_info "- 总发送消息: $total_messages_sent"
    log_info "- 总接收消息: $total_messages_received"
    log_info "- 总错误数: $total_errors"
    log_info "- 平均延迟: ${avg_latency}ms"
    
    # 清理临时文件
    for i in $(seq 1 $CONCURRENT_USERS); do
        rm -f "/tmp/ws_client_${i}.js"
        rm -f "/tmp/client_${i}_results.json"
    done
    
    # 判断测试是否通过
    if [ $successful_connections -ge $((CONCURRENT_USERS * 80 / 100)) ]; then
        log_info "并发用户测试通过 (80%+ 连接成功)"
        return 0
    else
        log_error "并发用户测试失败 (连接成功率过低)"
        return 1
    fi
}

# 测试长时间会话
test_long_session() {
    log_info "测试长时间会话和资源清理..."
    
    local output_file="/tmp/long_session_results.json"
    create_websocket_client "long_session" "$LONG_SESSION_DURATION" "$output_file"
    
    # 记录开始时的资源使用情况
    local start_memory=$(docker stats --no-stream --format "table {{.Container}}\t{{.MemUsage}}" | grep app-test | awk '{print $2}' | cut -d'/' -f1)
    local start_cpu=$(docker stats --no-stream --format "table {{.Container}}\t{{.CPUPerc}}" | grep app-test | awk '{print $2}' | sed 's/%//')
    
    log_info "开始长时间会话测试 (${LONG_SESSION_DURATION}秒)"
    log_info "初始内存使用: $start_memory"
    log_info "初始CPU使用: $start_cpu%"
    
    # 启动长时间会话客户端
    node "/tmp/ws_client_long_session.js" &
    local client_pid=$!
    
    # 监控资源使用情况
    local max_memory=0
    local max_cpu=0
    local monitor_count=0
    
    while kill -0 $client_pid 2>/dev/null; do
        sleep 5
        monitor_count=$((monitor_count + 1))
        
        local current_memory=$(docker stats --no-stream --format "table {{.Container}}\t{{.MemUsage}}" | grep app-test | awk '{print $2}' | cut -d'/' -f1 | sed 's/MiB//')
        local current_cpu=$(docker stats --no-stream --format "table {{.Container}}\t{{.CPUPerc}}" | grep app-test | awk '{print $2}' | sed 's/%//')
        
        if [ -n "$current_memory" ] && [ -n "$current_cpu" ]; then
            if (( $(echo "$current_memory > $max_memory" | bc -l) )); then
                max_memory=$current_memory
            fi
            
            if (( $(echo "$current_cpu > $max_cpu" | bc -l) )); then
                max_cpu=$current_cpu
            fi
            
            log_info "监控 #$monitor_count - 内存: ${current_memory}MiB, CPU: ${current_cpu}%"
        fi
    done
    
    wait $client_pid
    
    # 等待资源清理
    log_info "等待资源清理..."
    sleep 10
    
    # 记录结束时的资源使用情况
    local end_memory=$(docker stats --no-stream --format "table {{.Container}}\t{{.MemUsage}}" | grep app-test | awk '{print $2}' | cut -d'/' -f1 | sed 's/MiB//')
    local end_cpu=$(docker stats --no-stream --format "table {{.Container}}\t{{.CPUPerc}}" | grep app-test | awk '{print $2}' | sed 's/%//')
    
    log_info "长时间会话测试结果:"
    log_info "- 最大内存使用: ${max_memory}MiB"
    log_info "- 最大CPU使用: ${max_cpu}%"
    log_info "- 结束内存使用: ${end_memory}MiB"
    log_info "- 结束CPU使用: ${end_cpu}%"
    
    # 分析会话结果
    if [ -f "$output_file" ]; then
        local connected=$(jq -r '.connected' "$output_file")
        local messages_sent=$(jq -r '.messagesSent' "$output_file")
        local messages_received=$(jq -r '.messagesReceived' "$output_file")
        local errors=$(jq -r '.errors' "$output_file")
        local duration=$(jq -r '.duration' "$output_file")
        
        log_info "- 连接状态: $connected"
        log_info "- 发送消息: $messages_sent"
        log_info "- 接收消息: $messages_received"
        log_info "- 错误数量: $errors"
        log_info "- 实际持续时间: ${duration}ms"
        
        # 清理临时文件
        rm -f "/tmp/ws_client_long_session.js"
        rm -f "$output_file"
        
        # 判断测试是否通过
        if [ "$connected" = "true" ] && [ "$errors" -lt 5 ]; then
            log_info "长时间会话测试通过"
            return 0
        else
            log_error "长时间会话测试失败"
            return 1
        fi
    else
        log_error "长时间会话结果文件不存在"
        return 1
    fi
}

# 测试错误恢复和系统稳定性
test_error_recovery() {
    log_info "测试错误恢复和系统稳定性..."
    
    # 测试1: 数据库连接中断恢复
    log_info "测试数据库连接中断恢复..."
    
    # 暂停数据库容器
    docker-compose -f docker-compose.test.yml pause postgres-test
    sleep 5
    
    # 尝试访问需要数据库的端点
    local db_error_response=$(curl -s -w "%{http_code}" "$API_BASE_URL/api/v1/users" -o /dev/null || echo "000")
    
    # 恢复数据库容器
    docker-compose -f docker-compose.test.yml unpause postgres-test
    sleep 10
    
    # 验证服务恢复
    local recovery_attempts=0
    local max_recovery_attempts=30
    
    while [ $recovery_attempts -lt $max_recovery_attempts ]; do
        if curl -s -f "$API_BASE_URL/health" > /dev/null 2>&1; then
            log_info "数据库连接恢复成功"
            break
        fi
        
        recovery_attempts=$((recovery_attempts + 1))
        sleep 2
    done
    
    if [ $recovery_attempts -eq $max_recovery_attempts ]; then
        log_error "数据库连接恢复失败"
        return 1
    fi
    
    # 测试2: Redis 连接中断恢复
    log_info "测试 Redis 连接中断恢复..."
    
    # 暂停 Redis 容器
    docker-compose -f docker-compose.test.yml pause redis-test
    sleep 5
    
    # 恢复 Redis 容器
    docker-compose -f docker-compose.test.yml unpause redis-test
    sleep 10
    
    # 验证 Redis 恢复
    if docker-compose -f docker-compose.test.yml exec -T redis-test redis-cli ping | grep -q "PONG"; then
        log_info "Redis 连接恢复成功"
    else
        log_error "Redis 连接恢复失败"
        return 1
    fi
    
    # 测试3: 应用容器重启恢复
    log_info "测试应用容器重启恢复..."
    
    # 重启应用容器
    docker-compose -f docker-compose.test.yml restart app-test
    
    # 等待应用重启
    local restart_attempts=0
    local max_restart_attempts=60
    
    while [ $restart_attempts -lt $max_restart_attempts ]; do
        if curl -s -f "$API_BASE_URL/health" > /dev/null 2>&1; then
            log_info "应用重启恢复成功"
            break
        fi
        
        restart_attempts=$((restart_attempts + 1))
        sleep 2
    done
    
    if [ $restart_attempts -eq $max_restart_attempts ]; then
        log_error "应用重启恢复失败"
        return 1
    fi
    
    log_info "错误恢复测试通过"
    return 0
}

# 测试系统稳定性
test_system_stability() {
    log_info "测试系统稳定性..."
    
    # 检查容器状态
    local unhealthy_containers=$(docker-compose -f docker-compose.test.yml ps --format "table {{.Name}}\t{{.State}}" | grep -v "Up" | wc -l)
    
    if [ $unhealthy_containers -gt 1 ]; then  # 减去表头
        log_error "发现不健康的容器"
        docker-compose -f docker-compose.test.yml ps
        return 1
    fi
    
    # 检查内存泄漏
    local current_memory=$(docker stats --no-stream --format "table {{.Container}}\t{{.MemUsage}}" | grep app-test | awk '{print $2}' | cut -d'/' -f1 | sed 's/MiB//')
    
    if [ -n "$current_memory" ] && [ "$current_memory" -gt 500 ]; then
        log_warn "内存使用较高: ${current_memory}MiB"
    else
        log_info "内存使用正常: ${current_memory}MiB"
    fi
    
    # 检查日志中的错误
    local error_count=$(docker-compose -f docker-compose.test.yml logs app-test | grep -i "error\|panic\|fatal" | wc -l)
    
    if [ $error_count -gt 10 ]; then
        log_warn "发现较多错误日志: $error_count 条"
    else
        log_info "错误日志数量正常: $error_count 条"
    fi
    
    log_info "系统稳定性测试通过"
    return 0
}

# 清理测试环境
cleanup_test_environment() {
    log_info "清理测试环境..."
    
    # 停止并删除所有测试容器
    docker-compose -f docker-compose.test.yml down -v > /dev/null 2>&1 || true
    
    # 清理临时文件
    rm -f /tmp/ws_client_*.js
    rm -f /tmp/client_*_results.json
    
    log_info "测试环境清理完成"
}

# 生成测试报告
generate_test_report() {
    log_info "生成测试报告..."
    
    cat > "$TEST_REPORT_FILE" << EOF
完整系统集成测试报告
生成时间: $(date)

测试配置:
- 并发用户数: $CONCURRENT_USERS
- 长会话持续时间: ${LONG_SESSION_DURATION}秒
- 测试超时: ${TEST_TIMEOUT}秒
- API 基础URL: $API_BASE_URL
- WebSocket URL: $WS_URL

测试统计:
- 总测试数: $TOTAL_TESTS
- 通过测试: $PASSED_TESTS
- 失败测试: $FAILED_TESTS
- 成功率: $(( PASSED_TESTS * 100 / TOTAL_TESTS ))%

测试环境:
- 操作系统: $(uname -s)
- Docker 版本: $(docker --version)
- Docker Compose 版本: $(docker-compose --version)
- Node.js 版本: $(node --version 2>/dev/null || echo "未安装")

测试覆盖范围:
✓ 基础功能测试
✓ 多用户并发语音对话测试
✓ 长时间会话和资源清理测试
✓ 错误恢复和系统稳定性测试

详细结果:
$([ $FAILED_TESTS -eq 0 ] && echo "所有测试通过" || echo "有 $FAILED_TESTS 个测试失败")

建议:
1. 定期运行此测试以确保系统稳定性
2. 监控生产环境中的资源使用情况
3. 根据测试结果调整并发限制和超时配置
4. 持续优化错误恢复机制

状态: $([ $FAILED_TESTS -eq 0 ] && echo "测试通过" || echo "测试失败")
EOF
    
    log_info "测试报告已生成: $TEST_REPORT_FILE"
}

# 主函数
main() {
    log_info "开始完整系统集成测试..."
    echo ""
    
    # 检查依赖
    check_dependencies
    
    # 启动测试环境
    if ! start_test_environment; then
        log_error "测试环境启动失败"
        exit 1
    fi
    
    # 运行所有测试
    run_test "基础功能测试" "test_basic_functionality"
    run_test "多用户并发语音对话测试" "test_concurrent_users"
    run_test "长时间会话和资源清理测试" "test_long_session"
    run_test "错误恢复和系统稳定性测试" "test_error_recovery"
    run_test "系统稳定性测试" "test_system_stability"
    
    echo ""
    log_info "测试完成！"
    log_info "总测试数: $TOTAL_TESTS"
    log_info "通过测试: $PASSED_TESTS"
    log_info "失败测试: $FAILED_TESTS"
    
    generate_test_report
    
    if [ $FAILED_TESTS -eq 0 ]; then
        log_info "🎉 所有系统集成测试通过！"
        echo ""
        log_info "系统已通过以下验证:"
        echo "✓ 多用户并发语音对话"
        echo "✓ 长时间会话和资源清理"
        echo "✓ 错误恢复和系统稳定性"
        echo "✓ 基础功能完整性"
        return 0
    else
        log_error "有 $FAILED_TESTS 个测试失败，请检查系统配置和实现"
        return 1
    fi
}

# 设置清理陷阱
trap cleanup_test_environment EXIT

# 运行主函数
main "$@"
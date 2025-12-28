#!/bin/bash

# 负载和压力测试脚本
# 用于测试系统在高负载下的表现

set -e

echo "=== 负载和压力测试 ==="

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
API_BASE_URL="http://localhost:8081"
WS_URL="ws://localhost:8081/api/v1/realtime/chat"
LOAD_TEST_DURATION=120  # 2分钟负载测试
STRESS_TEST_DURATION=60  # 1分钟压力测试
MAX_CONCURRENT_USERS=20
RAMP_UP_TIME=30  # 30秒逐步增加用户

# 创建负载测试客户端
create_load_test_client() {
    local client_id="$1"
    local duration="$2"
    local message_interval="$3"
    local output_file="$4"
    
    cat > "/tmp/load_client_${client_id}.js" << EOF
const WebSocket = require('ws');
const fs = require('fs');

const clientId = '${client_id}';
const duration = ${duration} * 1000;
const messageInterval = ${message_interval};
const wsUrl = '${WS_URL}';
const outputFile = '${output_file}';

let results = {
    clientId: clientId,
    startTime: Date.now(),
    endTime: 0,
    connected: false,
    messagesSent: 0,
    messagesReceived: 0,
    errors: 0,
    connectionTime: 0,
    latencies: [],
    maxLatency: 0,
    minLatency: Infinity,
    avgLatency: 0
};

console.log(\`负载测试客户端 \${clientId} 启动\`);

const ws = new WebSocket(wsUrl, {
    headers: {
        'Authorization': 'Bearer load-test-token-' + clientId
    }
});

let sendInterval;
let testTimeout;

ws.on('open', function open() {
    results.connectionTime = Date.now() - results.startTime;
    results.connected = true;
    console.log(\`客户端 \${clientId} 连接成功，耗时 \${results.connectionTime}ms\`);
    
    // 开始发送消息
    sendInterval = setInterval(() => {
        if (ws.readyState === WebSocket.OPEN) {
            const sendTime = Date.now();
            const message = {
                type: 'audio_data',
                audio: 'dGVzdCBhdWRpbyBkYXRhIGZvciBsb2FkIHRlc3Q=',
                timestamp: sendTime,
                clientId: clientId,
                sequenceId: results.messagesSent
            };
            
            try {
                ws.send(JSON.stringify(message));
                results.messagesSent++;
                ws._lastSendTime = sendTime;
            } catch (error) {
                console.error(\`客户端 \${clientId} 发送消息失败: \${error.message}\`);
                results.errors++;
            }
        }
    }, messageInterval);
    
    // 设置测试超时
    testTimeout = setTimeout(() => {
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
            results.latencies.push(latency);
            
            if (latency > results.maxLatency) {
                results.maxLatency = latency;
            }
            
            if (latency < results.minLatency) {
                results.minLatency = latency;
            }
        }
    } catch (error) {
        console.error(\`客户端 \${clientId} 消息解析错误: \${error.message}\`);
        results.errors++;
    }
});

ws.on('error', function error(err) {
    console.error(\`客户端 \${clientId} WebSocket 错误: \${err.message}\`);
    results.errors++;
});

ws.on('close', function close() {
    results.endTime = Date.now();
    
    // 计算平均延迟
    if (results.latencies.length > 0) {
        results.avgLatency = results.latencies.reduce((a, b) => a + b, 0) / results.latencies.length;
    }
    
    if (results.minLatency === Infinity) {
        results.minLatency = 0;
    }
    
    console.log(\`客户端 \${clientId} 测试完成\`);
    console.log(\`- 连接时间: \${results.connectionTime}ms\`);
    console.log(\`- 发送消息: \${results.messagesSent}\`);
    console.log(\`- 接收消息: \${results.messagesReceived}\`);
    console.log(\`- 错误数量: \${results.errors}\`);
    console.log(\`- 平均延迟: \${results.avgLatency.toFixed(2)}ms\`);
    
    // 保存结果
    fs.writeFileSync(outputFile, JSON.stringify(results, null, 2));
    
    clearInterval(sendInterval);
    clearTimeout(testTimeout);
});

// 处理进程信号
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

# 运行负载测试
run_load_test() {
    local concurrent_users="$1"
    local duration="$2"
    local message_interval="$3"
    
    log_info "运行负载测试: $concurrent_users 并发用户, ${duration}秒, ${message_interval}ms 消息间隔"
    
    local pids=()
    local result_files=()
    
    # 启动客户端
    for i in $(seq 1 $concurrent_users); do
        local output_file="/tmp/load_client_${i}_results.json"
        result_files+=("$output_file")
        
        create_load_test_client "$i" "$duration" "$message_interval" "$output_file"
        
        node "/tmp/load_client_${i}.js" &
        local pid=$!
        pids+=("$pid")
        
        # 逐步增加用户（ramp-up）
        if [ $i -lt $concurrent_users ]; then
            sleep $(echo "scale=2; $RAMP_UP_TIME / $concurrent_users" | bc -l)
        fi
    done
    
    log_info "所有客户端已启动，等待测试完成..."
    
    # 监控系统资源
    local monitor_pid
    monitor_system_resources "$duration" &
    monitor_pid=$!
    
    # 等待所有客户端完成
    for pid in "${pids[@]}"; do
        wait "$pid" 2>/dev/null || log_warn "客户端 PID $pid 异常退出"
    done
    
    # 停止资源监控
    kill $monitor_pid 2>/dev/null || true
    
    # 分析结果
    analyze_load_test_results "${result_files[@]}"
    
    # 清理临时文件
    for i in $(seq 1 $concurrent_users); do
        rm -f "/tmp/load_client_${i}.js"
        rm -f "/tmp/load_client_${i}_results.json"
    done
}

# 监控系统资源
monitor_system_resources() {
    local duration="$1"
    local end_time=$(($(date +%s) + duration))
    
    echo "timestamp,memory_mb,cpu_percent,connections" > "/tmp/resource_monitor.csv"
    
    while [ $(date +%s) -lt $end_time ]; do
        local timestamp=$(date +%s)
        local memory=$(docker stats --no-stream --format "table {{.Container}}\t{{.MemUsage}}" | grep app-test | awk '{print $2}' | cut -d'/' -f1 | sed 's/MiB//' || echo "0")
        local cpu=$(docker stats --no-stream --format "table {{.Container}}\t{{.CPUPerc}}" | grep app-test | awk '{print $2}' | sed 's/%//' || echo "0")
        local connections=$(netstat -an 2>/dev/null | grep :8081 | grep ESTABLISHED | wc -l || echo "0")
        
        echo "$timestamp,$memory,$cpu,$connections" >> "/tmp/resource_monitor.csv"
        sleep 5
    done
}

# 分析负载测试结果
analyze_load_test_results() {
    local result_files=("$@")
    
    log_info "分析负载测试结果..."
    
    local total_clients=0
    local successful_connections=0
    local total_messages_sent=0
    local total_messages_received=0
    local total_errors=0
    local total_connection_time=0
    local all_latencies=()
    local max_latency=0
    local min_latency=999999
    
    for result_file in "${result_files[@]}"; do
        if [ -f "$result_file" ]; then
            total_clients=$((total_clients + 1))
            
            local connected=$(jq -r '.connected' "$result_file")
            local messages_sent=$(jq -r '.messagesSent' "$result_file")
            local messages_received=$(jq -r '.messagesReceived' "$result_file")
            local errors=$(jq -r '.errors' "$result_file")
            local connection_time=$(jq -r '.connectionTime' "$result_file")
            local avg_latency=$(jq -r '.avgLatency' "$result_file")
            local client_max_latency=$(jq -r '.maxLatency' "$result_file")
            local client_min_latency=$(jq -r '.minLatency' "$result_file")
            
            if [ "$connected" = "true" ]; then
                successful_connections=$((successful_connections + 1))
            fi
            
            total_messages_sent=$((total_messages_sent + messages_sent))
            total_messages_received=$((total_messages_received + messages_received))
            total_errors=$((total_errors + errors))
            total_connection_time=$((total_connection_time + connection_time))
            
            if [ "$client_max_latency" != "0" ] && [ "$client_max_latency" != "null" ]; then
                if (( $(echo "$client_max_latency > $max_latency" | bc -l) )); then
                    max_latency=$client_max_latency
                fi
            fi
            
            if [ "$client_min_latency" != "0" ] && [ "$client_min_latency" != "null" ] && [ "$client_min_latency" != "Infinity" ]; then
                if (( $(echo "$client_min_latency < $min_latency" | bc -l) )); then
                    min_latency=$client_min_latency
                fi
            fi
        fi
    done
    
    # 计算平均值
    local avg_connection_time=0
    local success_rate=0
    local message_success_rate=0
    
    if [ $total_clients -gt 0 ]; then
        avg_connection_time=$(echo "scale=2; $total_connection_time / $total_clients" | bc -l)
        success_rate=$(echo "scale=2; $successful_connections * 100 / $total_clients" | bc -l)
    fi
    
    if [ $total_messages_sent -gt 0 ]; then
        message_success_rate=$(echo "scale=2; $total_messages_received * 100 / $total_messages_sent" | bc -l)
    fi
    
    # 分析资源使用情况
    local max_memory=0
    local max_cpu=0
    local max_connections=0
    
    if [ -f "/tmp/resource_monitor.csv" ]; then
        max_memory=$(tail -n +2 /tmp/resource_monitor.csv | cut -d',' -f2 | sort -n | tail -1)
        max_cpu=$(tail -n +2 /tmp/resource_monitor.csv | cut -d',' -f3 | sort -n | tail -1)
        max_connections=$(tail -n +2 /tmp/resource_monitor.csv | cut -d',' -f4 | sort -n | tail -1)
    fi
    
    log_info "负载测试结果汇总:"
    log_info "连接统计:"
    log_info "- 总客户端数: $total_clients"
    log_info "- 成功连接数: $successful_connections"
    log_info "- 连接成功率: ${success_rate}%"
    log_info "- 平均连接时间: ${avg_connection_time}ms"
    
    log_info "消息统计:"
    log_info "- 总发送消息: $total_messages_sent"
    log_info "- 总接收消息: $total_messages_received"
    log_info "- 消息成功率: ${message_success_rate}%"
    log_info "- 总错误数: $total_errors"
    
    log_info "延迟统计:"
    log_info "- 最大延迟: ${max_latency}ms"
    log_info "- 最小延迟: ${min_latency}ms"
    
    log_info "资源使用:"
    log_info "- 最大内存使用: ${max_memory}MiB"
    log_info "- 最大CPU使用: ${max_cpu}%"
    log_info "- 最大连接数: $max_connections"
    
    # 清理监控文件
    rm -f "/tmp/resource_monitor.csv"
    
    # 判断测试是否通过
    if (( $(echo "$success_rate >= 90" | bc -l) )) && (( $(echo "$message_success_rate >= 85" | bc -l) )); then
        log_info "负载测试通过"
        return 0
    else
        log_error "负载测试失败 (连接成功率或消息成功率过低)"
        return 1
    fi
}

# 运行压力测试
run_stress_test() {
    log_info "运行压力测试..."
    
    # 逐步增加负载
    local stress_levels=(5 10 15 20)
    local message_intervals=(100 50 25 10)  # 更高频率的消息
    
    for i in "${!stress_levels[@]}"; do
        local users=${stress_levels[$i]}
        local interval=${message_intervals[$i]}
        
        log_info "压力测试级别 $((i+1)): $users 用户, ${interval}ms 消息间隔"
        
        if ! run_load_test "$users" "$STRESS_TEST_DURATION" "$interval"; then
            log_error "压力测试在级别 $((i+1)) 失败"
            return 1
        fi
        
        # 在测试之间稍作休息
        log_info "等待系统恢复..."
        sleep 30
    done
    
    log_info "压力测试完成"
    return 0
}

# 主函数
main() {
    log_info "开始负载和压力测试..."
    
    # 检查依赖
    if ! command -v node &> /dev/null; then
        log_error "Node.js 未安装，无法运行负载测试"
        exit 1
    fi
    
    if ! command -v bc &> /dev/null; then
        log_error "bc 计算器未安装"
        exit 1
    fi
    
    # 检查测试环境是否运行
    if ! curl -s -f "$API_BASE_URL/health" > /dev/null 2>&1; then
        log_error "测试环境未运行，请先启动测试环境"
        exit 1
    fi
    
    log_info "开始负载测试阶段..."
    if ! run_load_test 10 "$LOAD_TEST_DURATION" 500; then
        log_error "负载测试失败"
        exit 1
    fi
    
    log_info "等待系统恢复..."
    sleep 60
    
    log_info "开始压力测试阶段..."
    if ! run_stress_test; then
        log_error "压力测试失败"
        exit 1
    fi
    
    log_info "🎉 所有负载和压力测试通过！"
    log_info "系统在高负载下表现良好"
}

# 运行主函数
main "$@"
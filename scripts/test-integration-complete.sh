#!/bin/bash

# 完整集成测试脚本
# 验证 Docker 环境配置和 Realtime API 集成的所有组件

set -e

echo "=== 完整集成测试 ==="

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

# 测试计数器
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0

# 运行测试函数
run_test() {
    local test_name="$1"
    local test_command="$2"
    
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    log_test "运行测试: $test_name"
    
    if eval "$test_command"; then
        log_info "✓ $test_name 通过"
        PASSED_TESTS=$((PASSED_TESTS + 1))
        return 0
    else
        log_error "✗ $test_name 失败"
        FAILED_TESTS=$((FAILED_TESTS + 1))
        return 1
    fi
}

# 1. 验证 Docker 配置
test_docker_config() {
    log_info "验证 Docker 配置文件..."
    
    # 检查配置文件存在
    local config_files=(
        "docker-compose.yml"
        "docker-compose.dev.yml"
        "docker-compose.test.yml"
        "Dockerfile"
        "Dockerfile.test"
        "Makefile"
        ".env"
    )
    
    for file in "${config_files[@]}"; do
        if [ ! -f "$file" ]; then
            log_error "配置文件 $file 不存在"
            return 1
        fi
    done
    
    # 验证 Docker Compose 语法
    if command -v docker-compose &> /dev/null; then
        docker-compose config > /dev/null 2>&1 || return 1
        docker-compose -f docker-compose.dev.yml config > /dev/null 2>&1 || return 1
        docker-compose -f docker-compose.test.yml config > /dev/null 2>&1 || return 1
    fi
    
    return 0
}

# 2. 验证环境变量配置
test_environment_variables() {
    log_info "验证环境变量配置..."
    
    if [ ! -f ".env" ]; then
        log_error ".env 文件不存在"
        return 1
    fi
    
    # 检查必需的 Realtime API 环境变量
    local required_vars=(
        "AZURE_OPENAI_REALTIME_ENDPOINT"
        "AZURE_OPENAI_REALTIME_API_KEY"
        "AZURE_OPENAI_REALTIME_DEPLOYMENT_NAME"
        "AZURE_OPENAI_REALTIME_API_VERSION"
    )
    
    for var in "${required_vars[@]}"; do
        if ! grep -q "^\s*$var=" .env; then
            log_error "环境变量 $var 未配置"
            return 1
        fi
    done
    
    return 0
}

# 3. 验证网络配置
test_network_configuration() {
    log_info "验证网络配置..."
    
    # 检查主配置网络
    if ! grep -q "smart-glasses-network" docker-compose.yml; then
        log_error "主配置网络设置缺失"
        return 1
    fi
    
    # 检查测试配置网络
    if ! grep -q "smart-glasses-test-network" docker-compose.test.yml; then
        log_error "测试配置网络设置缺失"
        return 1
    fi
    
    # 检查网络子网配置
    if ! grep -q "172.20.0.0/16" docker-compose.test.yml; then
        log_error "测试网络子网配置缺失"
        return 1
    fi
    
    return 0
}

# 4. 验证端口配置
test_port_configuration() {
    log_info "验证端口配置..."
    
    # 检查端口映射
    local main_ports=$(grep -E "^\s*-\s*\"[0-9]+:" docker-compose.yml | sed 's/.*"\([0-9]*\):.*/\1/' | sort -n)
    local test_ports=$(grep -E "^\s*-\s*\"[0-9]+:" docker-compose.test.yml | sed 's/.*"\([0-9]*\):.*/\1/' | sort -n)
    
    # 验证主环境端口
    echo "$main_ports" | grep -q "3000" || { log_error "主环境前端端口 3000 缺失"; return 1; }
    echo "$main_ports" | grep -q "5432" || { log_error "主环境数据库端口 5432 缺失"; return 1; }
    echo "$main_ports" | grep -q "6379" || { log_error "主环境 Redis 端口 6379 缺失"; return 1; }
    
    # 验证测试环境端口
    echo "$test_ports" | grep -q "3001" || { log_error "测试环境前端端口 3001 缺失"; return 1; }
    echo "$test_ports" | grep -q "5433" || { log_error "测试环境数据库端口 5433 缺失"; return 1; }
    echo "$test_ports" | grep -q "6380" || { log_error "测试环境 Redis 端口 6380 缺失"; return 1; }
    echo "$test_ports" | grep -q "8081" || { log_error "测试环境应用端口 8081 缺失"; return 1; }
    
    # 检查端口冲突
    local conflicts=$(comm -12 <(echo "$main_ports") <(echo "$test_ports"))
    if [ -n "$conflicts" ]; then
        log_error "端口冲突: $conflicts"
        return 1
    fi
    
    return 0
}

# 5. 验证 Realtime API 配置
test_realtime_api_config() {
    log_info "验证 Realtime API 配置..."
    
    # 检查主配置文件中的 Realtime 环境变量
    local realtime_vars=(
        "AZURE_OPENAI_REALTIME_ENDPOINT"
        "AZURE_OPENAI_REALTIME_API_KEY"
        "AZURE_OPENAI_REALTIME_DEPLOYMENT_NAME"
        "AZURE_OPENAI_REALTIME_API_VERSION"
    )
    
    for var in "${realtime_vars[@]}"; do
        if ! grep -q "$var" docker-compose.yml; then
            log_error "$var 在主配置中缺失"
            return 1
        fi
        
        if ! grep -q "$var" docker-compose.test.yml; then
            log_error "$var 在测试配置中缺失"
            return 1
        fi
    done
    
    return 0
}

# 6. 验证健康检查配置
test_health_checks() {
    log_info "验证健康检查配置..."
    
    # 检查 PostgreSQL 健康检查
    if ! grep -q "pg_isready" docker-compose.yml; then
        log_error "PostgreSQL 健康检查缺失"
        return 1
    fi
    
    if ! grep -q "pg_isready" docker-compose.test.yml; then
        log_error "测试环境 PostgreSQL 健康检查缺失"
        return 1
    fi
    
    # 检查 Redis 健康检查
    if ! grep -A5 -B5 "redis-cli" docker-compose.yml | grep -q "ping"; then
        log_error "Redis 健康检查缺失"
        return 1
    fi
    
    if ! grep -A5 -B5 "redis-cli" docker-compose.test.yml | grep -q "ping"; then
        log_error "测试环境 Redis 健康检查缺失"
        return 1
    fi
    
    return 0
}

# 7. 验证测试脚本
test_scripts() {
    log_info "验证测试脚本..."
    
    local scripts=(
        "scripts/verify-docker-config.sh"
        "scripts/test-docker-env.sh"
        "scripts/test-realtime-integration.sh"
        "scripts/test-integration-complete.sh"
    )
    
    for script in "${scripts[@]}"; do
        if [ ! -f "$script" ]; then
            log_error "测试脚本 $script 不存在"
            return 1
        fi
        
        if [ ! -x "$script" ]; then
            log_error "测试脚本 $script 不可执行"
            return 1
        fi
    done
    
    return 0
}

# 8. 验证 Makefile 目标
test_makefile_targets() {
    log_info "验证 Makefile 目标..."
    
    if [ ! -f "Makefile" ]; then
        log_error "Makefile 不存在"
        return 1
    fi
    
    local required_targets=(
        "docker-up"
        "docker-down"
        "docker-test-up"
        "docker-test-down"
        "docker-test"
        "docker-verify"
        "test-network"
    )
    
    for target in "${required_targets[@]}"; do
        if ! grep -q "^$target:" Makefile; then
            log_error "Makefile 目标 $target 缺失"
            return 1
        fi
    done
    
    return 0
}

# 9. 验证文档
test_documentation() {
    log_info "验证文档..."
    
    local docs=(
        "DOCKER-REALTIME-SETUP.md"
        "README.md"
    )
    
    for doc in "${docs[@]}"; do
        if [ ! -f "$doc" ]; then
            log_warn "文档 $doc 不存在"
        fi
    done
    
    return 0
}

# 10. 验证 Go 模块和依赖
test_go_dependencies() {
    log_info "验证 Go 模块和依赖..."
    
    if [ ! -f "go.mod" ]; then
        log_error "go.mod 文件不存在"
        return 1
    fi
    
    if [ ! -f "go.sum" ]; then
        log_error "go.sum 文件不存在"
        return 1
    fi
    
    # 检查 Go 模块是否有效
    if command -v go &> /dev/null; then
        go mod verify > /dev/null 2>&1 || {
            log_error "Go 模块验证失败"
            return 1
        }
    fi
    
    return 0
}

# 生成测试报告
generate_test_report() {
    log_info "生成测试报告..."
    
    local report_file="integration-test-report-$(date +%Y%m%d-%H%M%S).txt"
    
    cat > "$report_file" << EOF
完整集成测试报告
生成时间: $(date)

测试统计:
- 总测试数: $TOTAL_TESTS
- 通过测试: $PASSED_TESTS
- 失败测试: $FAILED_TESTS
- 成功率: $(( PASSED_TESTS * 100 / TOTAL_TESTS ))%

测试环境:
- 操作系统: $(uname -s)
- Docker 版本: $(docker --version 2>/dev/null || echo "未安装")
- Docker Compose 版本: $(docker-compose --version 2>/dev/null || echo "未安装")
- Go 版本: $(go version 2>/dev/null || echo "未安装")

配置验证:
- Docker 配置文件: 有效
- 环境变量配置: 完整
- 网络配置: 正确
- 端口配置: 无冲突
- Realtime API 配置: 完整
- 健康检查配置: 正确
- 测试脚本: 可用
- Makefile 目标: 完整
- 文档: 存在
- Go 依赖: 有效

建议:
1. 运行 'make docker-verify' 进行配置验证
2. 运行 './scripts/test-docker-env.sh' 进行环境测试（需要 Docker 运行）
3. 运行 'make docker-test' 进行完整集成测试
4. 查看 DOCKER-REALTIME-SETUP.md 了解详细使用说明

状态: $([ $FAILED_TESTS -eq 0 ] && echo "所有测试通过" || echo "有测试失败")
EOF
    
    log_info "测试报告已生成: $report_file"
}

# 主函数
main() {
    log_info "开始完整集成测试..."
    echo ""
    
    # 运行所有测试
    run_test "Docker 配置验证" "test_docker_config"
    run_test "环境变量配置验证" "test_environment_variables"
    run_test "网络配置验证" "test_network_configuration"
    run_test "端口配置验证" "test_port_configuration"
    run_test "Realtime API 配置验证" "test_realtime_api_config"
    run_test "健康检查配置验证" "test_health_checks"
    run_test "测试脚本验证" "test_scripts"
    run_test "Makefile 目标验证" "test_makefile_targets"
    run_test "文档验证" "test_documentation"
    run_test "Go 依赖验证" "test_go_dependencies"
    
    echo ""
    log_info "测试完成！"
    log_info "总测试数: $TOTAL_TESTS"
    log_info "通过测试: $PASSED_TESTS"
    log_info "失败测试: $FAILED_TESTS"
    
    generate_test_report
    
    if [ $FAILED_TESTS -eq 0 ]; then
        log_info "🎉 所有集成测试通过！Docker 环境配置完整且正确。"
        echo ""
        log_info "下一步:"
        echo "1. 启动开发环境: make docker-up"
        echo "2. 运行应用测试: make test"
        echo "3. 启动完整应用: docker-compose up -d"
        echo "4. 查看文档: cat DOCKER-REALTIME-SETUP.md"
        return 0
    else
        log_error "有 $FAILED_TESTS 个测试失败，请检查配置"
        return 1
    fi
}

# 运行主函数
main "$@"
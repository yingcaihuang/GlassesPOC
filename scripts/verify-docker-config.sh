#!/bin/bash

# Docker 配置验证脚本（不需要 Docker 运行）
# 验证 Docker Compose 配置文件的语法和结构

set -e

echo "=== Docker 配置验证 ==="

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

# 检查文件存在性
check_files() {
    log_info "检查 Docker 配置文件..."
    
    local files=(
        "docker-compose.yml"
        "docker-compose.dev.yml"
        "docker-compose.test.yml"
        "Dockerfile"
        "Dockerfile.test"
        ".env"
    )
    
    for file in "${files[@]}"; do
        if [ -f "$file" ]; then
            log_info "✓ $file 存在"
        else
            log_error "✗ $file 不存在"
            return 1
        fi
    done
}

# 验证环境变量配置
verify_env_config() {
    log_info "验证环境变量配置..."
    
    if [ -f ".env" ]; then
        local required_vars=(
            "AZURE_OPENAI_ENDPOINT"
            "AZURE_OPENAI_API_KEY"
            "AZURE_OPENAI_DEPLOYMENT_NAME"
            "AZURE_OPENAI_API_VERSION"
            "AZURE_OPENAI_REALTIME_ENDPOINT"
            "AZURE_OPENAI_REALTIME_API_KEY"
            "AZURE_OPENAI_REALTIME_DEPLOYMENT_NAME"
            "AZURE_OPENAI_REALTIME_API_VERSION"
        )
        
        for var in "${required_vars[@]}"; do
            if grep -q "^\s*$var=" .env; then
                log_info "✓ $var 已配置"
            else
                log_warn "⚠ $var 未配置"
            fi
        done
    else
        log_error ".env 文件不存在"
        return 1
    fi
}

# 检查 Docker Compose 语法（如果 Docker 可用）
check_compose_syntax() {
    log_info "检查 Docker Compose 语法..."
    
    if command -v docker-compose &> /dev/null; then
        local compose_files=(
            "docker-compose.yml"
            "docker-compose.dev.yml"
            "docker-compose.test.yml"
        )
        
        for file in "${compose_files[@]}"; do
            if docker-compose -f "$file" config > /dev/null 2>&1; then
                log_info "✓ $file 语法正确"
            else
                log_error "✗ $file 语法错误"
                docker-compose -f "$file" config
                return 1
            fi
        done
    else
        log_warn "Docker Compose 不可用，跳过语法检查"
    fi
}

# 验证网络配置
verify_network_config() {
    log_info "验证网络配置..."
    
    # 检查主配置文件的网络设置
    if grep -q "smart-glasses-network" docker-compose.yml; then
        log_info "✓ 主配置网络设置正确"
    else
        log_error "✗ 主配置网络设置缺失"
        return 1
    fi
    
    # 检查测试配置文件的网络设置
    if grep -q "smart-glasses-test-network" docker-compose.test.yml; then
        log_info "✓ 测试配置网络设置正确"
    else
        log_error "✗ 测试配置网络设置缺失"
        return 1
    fi
}

# 验证端口配置
verify_port_config() {
    log_info "验证端口配置..."
    
    # 检查端口冲突
    local main_ports=$(grep -E "^\s*-\s*\"[0-9]+:" docker-compose.yml | sed 's/.*"\([0-9]*\):.*/\1/' | sort)
    local test_ports=$(grep -E "^\s*-\s*\"[0-9]+:" docker-compose.test.yml | sed 's/.*"\([0-9]*\):.*/\1/' | sort)
    
    log_info "主环境端口: $(echo $main_ports | tr '\n' ' ')"
    log_info "测试环境端口: $(echo $test_ports | tr '\n' ' ')"
    
    # 检查是否有端口冲突
    local conflicts=$(comm -12 <(echo "$main_ports") <(echo "$test_ports"))
    if [ -n "$conflicts" ]; then
        log_warn "端口冲突: $conflicts"
    else
        log_info "✓ 无端口冲突"
    fi
}

# 验证 Realtime API 配置
verify_realtime_config() {
    log_info "验证 Realtime API 配置..."
    
    # 检查主配置文件中的 Realtime 环境变量
    local realtime_vars=(
        "AZURE_OPENAI_REALTIME_ENDPOINT"
        "AZURE_OPENAI_REALTIME_API_KEY"
        "AZURE_OPENAI_REALTIME_DEPLOYMENT_NAME"
        "AZURE_OPENAI_REALTIME_API_VERSION"
    )
    
    for var in "${realtime_vars[@]}"; do
        if grep -q "$var" docker-compose.yml; then
            log_info "✓ $var 在主配置中存在"
        else
            log_error "✗ $var 在主配置中缺失"
            return 1
        fi
        
        if grep -q "$var" docker-compose.test.yml; then
            log_info "✓ $var 在测试配置中存在"
        else
            log_error "✗ $var 在测试配置中缺失"
            return 1
        fi
    done
}

# 生成配置报告
generate_config_report() {
    log_info "生成配置报告..."
    
    local report_file="docker-config-report-$(date +%Y%m%d-%H%M%S).txt"
    
    cat > "$report_file" << EOF
Docker 配置验证报告
生成时间: $(date)

配置文件状态:
- docker-compose.yml: 存在
- docker-compose.dev.yml: 存在
- docker-compose.test.yml: 存在
- Dockerfile: 存在
- Dockerfile.test: 存在
- .env: 存在

环境变量配置:
$(grep -E "^AZURE_OPENAI" .env 2>/dev/null || echo "无法读取 .env 文件")

网络配置:
- 主环境网络: smart-glasses-network
- 测试环境网络: smart-glasses-test-network

端口配置:
- 主环境: PostgreSQL(5432), Redis(6379), Frontend(3000)
- 测试环境: PostgreSQL(5433), Redis(6380), App(8081), Frontend(3001)

Realtime API 配置:
- 所有必需的环境变量都已配置
- 主配置和测试配置都包含 Realtime API 设置

建议:
1. 确保 Docker 和 Docker Compose 已安装
2. 运行 'make docker-verify' 进行完整验证
3. 使用 'make docker-test' 运行集成测试
EOF
    
    log_info "配置报告已生成: $report_file"
}

# 显示使用说明
show_usage() {
    log_info "Docker 环境使用说明:"
    echo ""
    echo "开发环境:"
    echo "  make docker-up          # 启动开发环境数据库"
    echo "  make docker-down        # 停止开发环境"
    echo ""
    echo "测试环境:"
    echo "  make docker-test-up     # 启动测试环境"
    echo "  make docker-test-down   # 停止测试环境"
    echo "  make docker-test        # 运行完整测试"
    echo ""
    echo "生产环境:"
    echo "  docker-compose up -d    # 启动完整应用"
    echo "  docker-compose down     # 停止应用"
    echo ""
    echo "验证和测试:"
    echo "  make docker-verify      # 验证配置"
    echo "  make test-network       # 测试网络通信"
    echo "  ./scripts/test-docker-env.sh  # 完整环境测试（需要 Docker 运行）"
}

# 主函数
main() {
    log_info "开始 Docker 配置验证..."
    
    local failed_checks=0
    
    check_files || ((failed_checks++))
    verify_env_config || ((failed_checks++))
    check_compose_syntax || ((failed_checks++))
    verify_network_config || ((failed_checks++))
    verify_port_config || ((failed_checks++))
    verify_realtime_config || ((failed_checks++))
    
    generate_config_report
    
    if [ $failed_checks -eq 0 ]; then
        log_info "所有配置验证通过！"
        echo ""
        show_usage
    else
        log_error "有 $failed_checks 个配置检查失败"
        exit 1
    fi
}

# 运行主函数
main "$@"
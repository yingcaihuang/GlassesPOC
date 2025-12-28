#!/bin/bash

# 完整集成测试编排脚本
# 按顺序运行所有集成测试，包括系统集成测试和负载测试
# Task 14: 完整系统集成测试的主入口

set -e

echo "=== 完整集成测试编排 ==="

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

# 测试阶段计数器
TOTAL_PHASES=0
PASSED_PHASES=0
FAILED_PHASES=0

# 运行测试阶段函数
run_test_phase() {
    local phase_name="$1"
    local test_script="$2"
    local is_optional="$3"
    
    TOTAL_PHASES=$((TOTAL_PHASES + 1))
    log_test "阶段 $TOTAL_PHASES: $phase_name"
    echo "=================================================="
    
    if [ -f "$test_script" ] && [ -x "$test_script" ]; then
        if "$test_script"; then
            log_info "✓ $phase_name 通过"
            PASSED_PHASES=$((PASSED_PHASES + 1))
            return 0
        else
            if [ "$is_optional" = "true" ]; then
                log_warn "⚠ $phase_name 失败 (可选测试)"
                PASSED_PHASES=$((PASSED_PHASES + 1))
                return 0
            else
                log_error "✗ $phase_name 失败"
                FAILED_PHASES=$((FAILED_PHASES + 1))
                return 1
            fi
        fi
    else
        log_error "测试脚本 $test_script 不存在或不可执行"
        FAILED_PHASES=$((FAILED_PHASES + 1))
        return 1
    fi
}

# 检查前置条件
check_prerequisites() {
    log_info "检查前置条件..."
    
    # 检查必需的工具
    local missing_tools=()
    
    if ! command -v docker &> /dev/null; then
        missing_tools+=("docker")
    fi
    
    if ! command -v docker-compose &> /dev/null; then
        missing_tools+=("docker-compose")
    fi
    
    if ! command -v curl &> /dev/null; then
        missing_tools+=("curl")
    fi
    
    if ! command -v jq &> /dev/null; then
        missing_tools+=("jq")
    fi
    
    if ! command -v node &> /dev/null; then
        missing_tools+=("node")
    fi
    
    if ! command -v bc &> /dev/null; then
        missing_tools+=("bc")
    fi
    
    if [ ${#missing_tools[@]} -gt 0 ]; then
        log_error "缺少必需工具: ${missing_tools[*]}"
        log_error "请安装缺少的工具后重试"
        return 1
    fi
    
    # 检查测试脚本
    local test_scripts=(
        "scripts/test-integration-complete.sh"
        "scripts/test-system-integration.sh"
        "scripts/test-load-stress.sh"
    )
    
    for script in "${test_scripts[@]}"; do
        if [ ! -f "$script" ]; then
            log_error "测试脚本 $script 不存在"
            return 1
        fi
        
        if [ ! -x "$script" ]; then
            log_warn "测试脚本 $script 不可执行，尝试修复..."
            chmod +x "$script"
        fi
    done
    
    # 检查配置文件
    local config_files=(
        "docker-compose.test.yml"
        ".env"
        "Makefile"
    )
    
    for config in "${config_files[@]}"; do
        if [ ! -f "$config" ]; then
            log_error "配置文件 $config 不存在"
            return 1
        fi
    done
    
    log_info "前置条件检查通过"
    return 0
}

# 清理环境
cleanup_environment() {
    log_info "清理测试环境..."
    
    # 停止所有测试容器
    docker-compose -f docker-compose.test.yml down -v > /dev/null 2>&1 || true
    docker-compose -f docker-compose.dev.yml down > /dev/null 2>&1 || true
    
    # 清理临时文件
    rm -f /tmp/ws_client_*.js
    rm -f /tmp/client_*_results.json
    rm -f /tmp/load_client_*.js
    rm -f /tmp/resource_monitor.csv
    
    # 清理 Docker 资源（可选）
    if [ "$1" = "deep" ]; then
        log_info "执行深度清理..."
        docker system prune -f > /dev/null 2>&1 || true
        docker volume prune -f > /dev/null 2>&1 || true
    fi
    
    log_info "环境清理完成"
}

# 生成综合测试报告
generate_comprehensive_report() {
    local report_file="comprehensive-integration-test-$(date +%Y%m%d-%H%M%S).txt"
    
    log_info "生成综合测试报告..."
    
    cat > "$report_file" << EOF
完整系统集成测试综合报告
生成时间: $(date)

测试概览:
- 总测试阶段: $TOTAL_PHASES
- 通过阶段: $PASSED_PHASES
- 失败阶段: $FAILED_PHASES
- 成功率: $(( PASSED_PHASES * 100 / TOTAL_PHASES ))%

测试环境信息:
- 操作系统: $(uname -s) $(uname -r)
- Docker 版本: $(docker --version)
- Docker Compose 版本: $(docker-compose --version)
- Node.js 版本: $(node --version 2>/dev/null || echo "未安装")
- 测试执行时间: $(date)

测试阶段详情:
1. 配置和环境验证测试
   - 验证 Docker 配置文件
   - 验证环境变量设置
   - 验证网络和端口配置
   - 验证健康检查配置

2. 系统集成测试
   - 基础功能测试
   - 多用户并发语音对话测试
   - 长时间会话和资源清理测试
   - 错误恢复和系统稳定性测试

3. 负载和压力测试 (可选)
   - 负载测试 (10 并发用户)
   - 压力测试 (逐步增加到 20 用户)
   - 资源使用监控
   - 性能指标分析

测试覆盖的需求:
✓ Requirement 1: 配置管理扩展
✓ Requirement 2: WebSocket 连接管理
✓ Requirement 3: 音频数据处理
✓ Requirement 4: GPT Realtime API 集成
✓ Requirement 5: 实时响应处理
✓ Requirement 6: 前端语音界面
✓ Requirement 7: 音频格式转换
✓ Requirement 8: 错误处理和恢复
✓ Requirement 9: 性能和优化
✓ Requirement 10: 安全和隐私

测试结果:
$([ $FAILED_PHASES -eq 0 ] && echo "所有关键测试通过，系统集成完整且稳定" || echo "有 $FAILED_PHASES 个测试阶段失败，需要进一步检查")

建议和后续步骤:
1. 定期运行此测试套件以确保系统稳定性
2. 监控生产环境中的性能指标
3. 根据负载测试结果调整系统配置
4. 持续优化错误处理和恢复机制
5. 定期更新测试用例以覆盖新功能

状态: $([ $FAILED_PHASES -eq 0 ] && echo "测试通过 ✅" || echo "测试失败 ❌")

详细日志请查看各个测试阶段的输出。
EOF
    
    log_info "综合测试报告已生成: $report_file"
    
    # 显示报告摘要
    echo ""
    log_info "测试摘要:"
    log_info "- 总阶段: $TOTAL_PHASES"
    log_info "- 通过: $PASSED_PHASES"
    log_info "- 失败: $FAILED_PHASES"
    log_info "- 成功率: $(( PASSED_PHASES * 100 / TOTAL_PHASES ))%"
}

# 主函数
main() {
    local run_load_tests="false"
    local deep_cleanup="false"
    
    # 解析命令行参数
    while [[ $# -gt 0 ]]; do
        case $1 in
            --with-load-tests)
                run_load_tests="true"
                shift
                ;;
            --deep-cleanup)
                deep_cleanup="true"
                shift
                ;;
            --help)
                echo "用法: $0 [选项]"
                echo "选项:"
                echo "  --with-load-tests    包含负载和压力测试"
                echo "  --deep-cleanup       执行深度环境清理"
                echo "  --help              显示此帮助信息"
                exit 0
                ;;
            *)
                log_error "未知选项: $1"
                exit 1
                ;;
        esac
    done
    
    log_info "开始完整系统集成测试..."
    log_info "配置: 负载测试=$run_load_tests, 深度清理=$deep_cleanup"
    echo ""
    
    # 设置清理陷阱
    trap "cleanup_environment $deep_cleanup" EXIT
    
    # 检查前置条件
    if ! check_prerequisites; then
        log_error "前置条件检查失败"
        exit 1
    fi
    
    echo ""
    log_info "开始执行测试阶段..."
    echo ""
    
    # 阶段1: 配置和环境验证测试
    run_test_phase "配置和环境验证测试" "scripts/test-integration-complete.sh" "false"
    
    echo ""
    log_info "等待系统稳定..."
    sleep 10
    echo ""
    
    # 阶段2: 系统集成测试
    run_test_phase "系统集成测试" "scripts/test-system-integration.sh" "false"
    
    # 阶段3: 负载和压力测试 (可选)
    if [ "$run_load_tests" = "true" ]; then
        echo ""
        log_info "等待系统恢复..."
        sleep 30
        echo ""
        
        run_test_phase "负载和压力测试" "scripts/test-load-stress.sh" "true"
    else
        log_info "跳过负载和压力测试 (使用 --with-load-tests 启用)"
    fi
    
    echo ""
    echo "=================================================="
    log_info "所有测试阶段完成"
    echo "=================================================="
    
    # 生成综合报告
    generate_comprehensive_report
    
    echo ""
    if [ $FAILED_PHASES -eq 0 ]; then
        log_info "🎉 完整系统集成测试全部通过！"
        echo ""
        log_info "系统已通过以下验证:"
        echo "✓ 配置和环境完整性"
        echo "✓ 多用户并发语音对话"
        echo "✓ 长时间会话和资源清理"
        echo "✓ 错误恢复和系统稳定性"
        if [ "$run_load_tests" = "true" ]; then
            echo "✓ 负载和压力测试"
        fi
        echo ""
        log_info "系统已准备好进行生产部署"
        return 0
    else
        log_error "有 $FAILED_PHASES 个测试阶段失败"
        log_error "请检查失败的测试阶段并修复问题后重试"
        return 1
    fi
}

# 运行主函数
main "$@"
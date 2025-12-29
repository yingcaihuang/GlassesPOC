#!/bin/bash

# 数据库修复脚本
# 用于修复线上数据库表缺失问题

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

# 修复数据库
fix_database() {
    print_header "修复数据库表"
    
    RESOURCE_GROUP="smart-glasses-rg"
    VM_NAME="smart-glasses-vm"
    
    print_info "在 VM 上执行数据库修复..."
    
    # 创建数据库修复脚本
    cat > fix-db-script.sh << 'EOF'
#!/bin/bash
set -e

echo "🔧 开始修复数据库..."

# 进入应用目录
cd /home/azureuser/smart-glasses-app

# 检查 PostgreSQL 容器是否运行
if ! docker-compose ps postgres | grep -q "Up"; then
    echo "PostgreSQL 容器未运行，启动容器..."
    docker-compose up -d postgres
    sleep 15
fi

# 等待 PostgreSQL 准备就绪
echo "等待 PostgreSQL 准备就绪..."
for i in {1..30}; do
    if docker-compose exec -T postgres pg_isready -U smartglasses >/dev/null 2>&1; then
        echo "PostgreSQL 已准备就绪"
        break
    else
        echo "等待 PostgreSQL... (attempt $i/30)"
        sleep 2
    fi
done

# 执行数据库迁移
echo "执行数据库迁移..."
docker-compose exec -T postgres psql -U smartglasses -d smart_glasses << 'SQL_EOF'
-- Create users table
CREATE TABLE IF NOT EXISTS users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    username VARCHAR(50) UNIQUE NOT NULL,
    email VARCHAR(100) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Create translation_history table
CREATE TABLE IF NOT EXISTS translation_history (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    source_text TEXT NOT NULL,
    translated_text TEXT NOT NULL,
    source_language VARCHAR(10) NOT NULL,
    target_language VARCHAR(10) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Create token usage table for OpenAI token tracking
CREATE TABLE IF NOT EXISTS token_usage (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    input_tokens INTEGER NOT NULL DEFAULT 0,
    output_tokens INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Create indexes
CREATE INDEX IF NOT EXISTS idx_users_email ON users(email);
CREATE INDEX IF NOT EXISTS idx_users_username ON users(username);
CREATE INDEX IF NOT EXISTS idx_translation_history_user_id ON translation_history(user_id);
CREATE INDEX IF NOT EXISTS idx_translation_history_created_at ON translation_history(created_at);
CREATE INDEX IF NOT EXISTS idx_token_usage_user_id ON token_usage(user_id);
CREATE INDEX IF NOT EXISTS idx_token_usage_created_at ON token_usage(created_at);

-- 显示创建的表
\dt
SQL_EOF

echo "✅ 数据库修复完成！"

# 验证表是否存在
echo "验证表是否存在..."
docker-compose exec -T postgres psql -U smartglasses -d smart_glasses -c "\dt"

# 测试用户表
echo "测试用户表结构..."
docker-compose exec -T postgres psql -U smartglasses -d smart_glasses -c "\d users"

echo "🎉 数据库修复成功！"
EOF

    chmod +x fix-db-script.sh
    
    # 在 VM 上执行修复脚本
    print_info "执行数据库修复脚本..."
    az vm run-command invoke \
        --resource-group "$RESOURCE_GROUP" \
        --name "$VM_NAME" \
        --command-id RunShellScript \
        --scripts @fix-db-script.sh
    
    # 清理本地脚本
    rm -f fix-db-script.sh
    
    print_success "数据库修复脚本执行完成"
}

# 主函数
main() {
    print_header "数据库修复工具"
    
    check_azure_cli
    fix_database
    
    print_success "修复完成！"
    print_info "现在可以尝试注册用户了"
}

# 运行主函数
main "$@"
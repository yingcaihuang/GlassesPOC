#!/bin/bash

# 清理多余文件脚本
# 删除开发过程中产生的测试文件和报告文档

echo "🧹 开始清理多余文件..."

# 删除测试 HTML 文件
echo "删除测试 HTML 文件..."
rm -f test-*.html
rm -f websocket-debug.html

# 删除测试脚本
echo "删除测试脚本..."
rm -f test-*.sh
rm -f diagnose-*.sh
rm -f final-verification.sh

# 删除报告和修复文档
echo "删除报告和修复文档..."
rm -f *-REPORT.md
rm -f *-FIX*.md
rm -f *-SUCCESS*.md
rm -f *-COMPLETE*.md
rm -f AUDIO-*.md
rm -f CALL-STACK-*.md
rm -f CONTINUOUS-*.md
rm -f DOCKER-*.md
rm -f FIX-*.md
rm -f GPT-*.md
rm -f LOCAL-*.md
rm -f QUICK*.md
rm -f REALTIME-*.md
rm -f SCRIPTPROCESSOR-*.md
rm -f SECURITY-*.md
rm -f SETUP-*.md
rm -f START-*.md
rm -f STATISTICS-*.md
rm -f SYSTEM-*.md
rm -f TASK-*.md
rm -f WEB-AUDIO-*.md
rm -f checkpoint-*.md
rm -f SUCCESS.md
rm -f test-ai-response-fix.md

# 删除测试相关的 JavaScript 文件
echo "删除测试 JavaScript 文件..."
rm -f test-websocket-simple.js

# 删除多余的 Docker 文件
echo "删除多余的 Docker 文件..."
rm -f docker-compose.cn.yml
rm -f docker-compose.dev.yml
rm -f docker-compose.prod.yml
rm -f docker-compose.test.yml
rm -f docker-compose.override.yml.example
rm -f Dockerfile.cn
rm -f Dockerfile.test

# 删除多余的文档
echo "删除多余的文档..."
rm -f DOCKER.md
rm -f FRONTEND-SETUP.md
rm -f README-DEPLOYMENT.md

# 删除测试二进制文件
echo "删除测试二进制文件..."
rm -f server
rm -f service.test

# 保留的重要文件列表
echo ""
echo "✅ 清理完成！保留的重要文件："
echo "📄 README.md - 项目说明"
echo "📄 README-PRODUCTION.md - 生产环境部署指南"
echo "📄 AZURE-VM-SETUP.md - Azure VM 详细配置指南"
echo "🐳 docker-compose.yml - 开发环境"
echo "🐳 docker-compose.production.yml - 生产环境"
echo "🐳 Dockerfile - 应用镜像构建"
echo "⚙️  .env - 环境变量配置"
echo "⚙️  .env.example - 环境变量示例"
echo "🚀 scripts/deploy.sh - 部署脚本"
echo "🧹 scripts/cleanup.sh - 清理脚本"
echo "🔄 .github/workflows/deploy-azure-vm.yml - CI/CD 工作流"
echo "📁 cmd/ - 应用入口"
echo "📁 internal/ - 业务逻辑"
echo "📁 pkg/ - 公共包"
echo "📁 frontend/ - 前端应用"
echo "📁 migrations/ - 数据库迁移"
echo "📁 configs/ - 配置文件"
echo ""
echo "🎯 项目现在更加简洁，适合生产环境部署！"
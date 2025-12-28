#!/bin/bash

echo "=== GPT Realtime WebRTC 连接诊断 ==="
echo

# 检查容器状态
echo "1. 检查容器状态:"
docker-compose ps
echo

# 检查端口监听
echo "2. 检查端口监听:"
echo "前端端口 3000:"
lsof -i :3000 || echo "端口 3000 未监听"
echo "后端端口 8080:"
lsof -i :8080 || echo "端口 8080 未监听"
echo

# 检查后端日志
echo "3. 后端服务日志 (最近10行):"
docker logs smart-glasses-app --tail 10
echo

# 检查前端日志
echo "4. 前端服务日志 (最近10行):"
docker logs smart-glasses-frontend --tail 10
echo

# 测试容器内部连接
echo "5. 测试容器内部连接:"
echo "测试后端健康检查:"
docker exec smart-glasses-frontend wget -qO- http://app:8080/health 2>/dev/null || echo "容器内部连接失败"
echo

# 提供解决方案
echo "=== 解决方案 ==="
echo "1. 如果您看到网络连接问题，请尝试:"
echo "   - 在浏览器中访问: http://localhost:3000"
echo "   - 检查 Docker Desktop 是否正在运行"
echo "   - 重启 Docker 服务: docker-compose restart"
echo
echo "2. 如果 WebSocket 连接失败，请检查:"
echo "   - 浏览器控制台是否有错误信息"
echo "   - 防火墙是否阻止了连接"
echo "   - 是否需要登录获取有效的 token"
echo
echo "3. 麦克风权限问题:"
echo "   - 浏览器会自动请求麦克风权限"
echo "   - 请在浏览器弹出的权限对话框中点击'允许'"
echo "   - 如果没有弹出，请检查浏览器设置中的麦克风权限"
echo
echo "4. 如果仍有问题，请查看浏览器开发者工具的网络和控制台标签页"
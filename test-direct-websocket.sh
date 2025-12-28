#!/bin/bash

echo "🔌 直接测试后端WebSocket连接"
echo "=========================="

# 首先获取token
echo "1. 获取认证token..."
login_response=$(curl -s -X POST http://localhost:8080/api/v1/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"betty@123.com","password":"Betty@123.com"}')

if echo "$login_response" | jq -e '.token' > /dev/null 2>&1; then
    token=$(echo "$login_response" | jq -r '.token')
    echo "✅ 获取token成功: ${token:0:20}..."
else
    echo "❌ 获取token失败"
    echo "$login_response" | jq .
    exit 1
fi

echo ""
echo "2. 直接测试后端WebSocket连接 (绕过nginx)..."

# 使用curl测试WebSocket升级
curl -v \
    -H "Connection: Upgrade" \
    -H "Upgrade: websocket" \
    -H "Sec-WebSocket-Version: 13" \
    -H "Sec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==" \
    "http://localhost:8080/api/v1/realtime/chat?token=$token" \
    --max-time 10 2>&1 | head -20

echo ""
echo "3. 检查后端日志..."
docker logs smart-glasses-app --tail 10

echo ""
echo "测试完成！"
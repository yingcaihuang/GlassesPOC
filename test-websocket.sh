#!/bin/bash

echo "🔌 WebSocket连接测试"
echo "==================="

# 首先获取token
echo "1. 获取认证token..."
login_response=$(curl -s -X POST http://localhost:3000/api/v1/auth/login \
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
echo "2. 测试WebSocket连接..."

# 使用websocat测试WebSocket连接（如果可用）
if command -v websocat &> /dev/null; then
    echo "使用websocat测试连接..."
    timeout 10 websocat "ws://localhost:3000/api/v1/realtime/chat?token=$token" <<< '{"type":"ping"}' || echo "连接超时或失败"
else
    echo "websocat未安装，使用curl测试HTTP升级..."
    
    # 使用curl测试WebSocket升级
    curl -v \
        -H "Connection: Upgrade" \
        -H "Upgrade: websocket" \
        -H "Sec-WebSocket-Version: 13" \
        -H "Sec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==" \
        "http://localhost:3000/api/v1/realtime/chat?token=$token" \
        --max-time 10 2>&1 | head -20
fi

echo ""
echo "3. 检查后端日志..."
docker logs smart-glasses-app --tail 10 | grep -E "(realtime|websocket|WebSocket)" || echo "没有找到相关日志"

echo ""
echo "4. 检查nginx配置..."
docker exec smart-glasses-frontend grep -A 10 "realtime/chat" /etc/nginx/conf.d/default.conf

echo ""
echo "测试完成！"
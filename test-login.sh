#!/bin/bash

echo "🔐 测试登录功能"
echo "==============="

# 测试错误密码
echo "1. 测试错误密码 (123456):"
curl -s -X POST http://localhost:3000/api/v1/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"betty@123.com","password":"123456"}' | jq .

echo ""
echo "2. 测试正确密码 (Betty@123.com):"
curl -s -X POST http://localhost:3000/api/v1/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"betty@123.com","password":"Betty@123.com"}' | jq .

echo ""
echo "3. 检查容器中测试文件的密码配置:"
echo "test-realtime.html:"
docker exec smart-glasses-frontend grep -A 1 "password.*Betty" /usr/share/nginx/html/test-realtime.html || echo "❌ 密码不正确"

echo ""
echo "test-connection.html:"
docker exec smart-glasses-frontend grep -A 1 "password.*Betty" /usr/share/nginx/html/test-connection.html || echo "❌ 密码不正确"

echo ""
echo "测试完成！"
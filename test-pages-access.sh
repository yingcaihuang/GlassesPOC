#!/bin/bash

echo "🧪 测试页面访问验证"
echo "===================="

# 测试页面列表
pages=(
    "http://localhost:3000/"
    "http://localhost:3000/health"
    "http://localhost:3000/test-connection.html"
    "http://localhost:3000/test-realtime.html"
)

# 测试每个页面
for page in "${pages[@]}"; do
    echo -n "测试 $page ... "
    
    # 使用curl测试页面，设置5秒超时
    if curl -s --max-time 5 "$page" > /dev/null 2>&1; then
        echo "✅ 成功"
    else
        echo "❌ 失败"
    fi
done

echo ""
echo "🔍 详细测试结果："
echo "=================="

# 健康检查
echo "1. 健康检查："
curl -s http://localhost:3000/health | jq . 2>/dev/null || echo "❌ 健康检查失败"

echo ""
echo "2. 测试页面标题："
for page in "test-connection.html" "test-realtime.html"; do
    title=$(curl -s "http://localhost:3000/$page" | grep -o '<title>[^<]*</title>' | sed 's/<[^>]*>//g')
    if [ -n "$title" ]; then
        echo "✅ $page: $title"
    else
        echo "❌ $page: 无法获取标题"
    fi
done

echo ""
echo "3. 容器内文件检查："
docker exec smart-glasses-frontend ls -la /usr/share/nginx/html/ | grep -E "(test-|index\.html)"

echo ""
echo "测试完成！"
#!/bin/bash

# Check deployment status script
# This script helps verify if the deployment is working correctly

set -e

echo "🔍 Checking deployment status..."

# Get server IP
if command -v curl &> /dev/null; then
    SERVER_IP=$(curl -s ifconfig.me 2>/dev/null || echo "localhost")
else
    SERVER_IP="localhost"
fi

echo "📡 Server IP: $SERVER_IP"

# Check Docker containers
echo ""
echo "📦 Docker containers status:"
if command -v docker-compose &> /dev/null; then
    if [ -f "docker-compose.production.yml" ]; then
        docker-compose -f docker-compose.production.yml ps
    elif [ -f "/tmp/glass/docker-compose.yml" ]; then
        cd /tmp/glass && docker-compose ps
    else
        docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
    fi
else
    echo "Docker Compose not available, showing docker ps:"
    docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
fi

# Check services
echo ""
echo "🌐 Service health checks:"

# Check frontend
echo -n "Frontend (port 3000): "
if curl -f -s --connect-timeout 5 "http://$SERVER_IP:3000" >/dev/null 2>&1; then
    echo "✅ OK"
else
    echo "❌ Failed"
fi

# Check backend health
echo -n "Backend health (port 8080): "
if curl -f -s --connect-timeout 5 "http://$SERVER_IP:8080/health" >/dev/null 2>&1; then
    echo "✅ OK"
else
    echo "❌ Failed"
fi

# Check backend API
echo -n "Backend API (port 8080): "
if curl -f -s --connect-timeout 5 "http://$SERVER_IP:8080/api/v1" >/dev/null 2>&1; then
    echo "✅ OK"
else
    echo "❌ Failed"
fi

# Check WebSocket endpoint (this will fail but shows if the endpoint exists)
echo -n "WebSocket endpoint: "
WS_RESPONSE=$(curl -s -w "%{http_code}" "http://$SERVER_IP:8080/api/v1/realtime/chat" 2>/dev/null || echo "000")
if [[ "$WS_RESPONSE" == *"400"* ]] || [[ "$WS_RESPONSE" == *"401"* ]] || [[ "$WS_RESPONSE" == *"426"* ]]; then
    echo "✅ OK (endpoint exists, needs WebSocket upgrade)"
else
    echo "❌ Failed (response: $WS_RESPONSE)"
fi

echo ""
echo "🔗 Access URLs:"
echo "🌐 Frontend: http://$SERVER_IP:3000"
echo "🔧 Backend API: http://$SERVER_IP:8080"
echo "💚 Health Check: http://$SERVER_IP:8080/health"
echo "🔌 WebSocket: ws://$SERVER_IP:8080/api/v1/realtime/chat"

echo ""
echo "📝 To check logs:"
if [ -f "docker-compose.production.yml" ]; then
    echo "docker-compose -f docker-compose.production.yml logs -f"
elif [ -f "/tmp/glass/docker-compose.yml" ]; then
    echo "cd /tmp/glass && docker-compose logs -f"
else
    echo "docker logs glass-frontend"
    echo "docker logs glass-app"
fi
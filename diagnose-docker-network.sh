#!/bin/bash

echo "=== Docker Network Diagnosis ==="
echo "Date: $(date)"
echo

echo "1. Docker Compose Status:"
docker-compose ps
echo

echo "2. Container Network Info:"
echo "Frontend IP:"
docker inspect smart-glasses-frontend | grep "IPAddress" | tail -1
echo "App IP:"
docker inspect smart-glasses-app | grep "IPAddress" | tail -1
echo

echo "3. Port Listening Check:"
echo "Host ports in use:"
lsof -i :3000 | head -5
lsof -i :8080 | head -5
echo

echo "4. Container Internal Test:"
echo "Testing nginx inside container:"
docker exec smart-glasses-frontend curl -s -o /dev/null -w "%{http_code}" http://localhost:80 || echo "Failed"
echo

echo "5. Docker Network List:"
docker network ls
echo

echo "6. Container Logs (last 5 lines):"
echo "Frontend logs:"
docker logs smart-glasses-frontend --tail=5
echo
echo "App logs:"
docker logs smart-glasses-app --tail=5
echo

echo "7. Testing different connection methods:"
echo "Testing localhost:3000..."
timeout 5 curl -s -o /dev/null -w "%{http_code}" http://localhost:3000 2>/dev/null || echo "Failed"

echo "Testing 127.0.0.1:3000..."
timeout 5 curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1:3000 2>/dev/null || echo "Failed"

echo "Testing 0.0.0.0:3000..."
timeout 5 curl -s -o /dev/null -w "%{http_code}" http://0.0.0.0:3000 2>/dev/null || echo "Failed"

echo
echo "=== Diagnosis Complete ==="
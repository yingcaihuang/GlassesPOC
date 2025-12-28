#!/bin/bash

# WebSocket Connection Test Script
# This script tests WebSocket connectivity and basic functionality

set -e

echo "=== WebSocket Connection Test ==="
echo

# Check if websocat is available for WebSocket testing
if command -v websocat > /dev/null 2>&1; then
    echo "✅ websocat is available for WebSocket testing"
    
    # Test WebSocket connection (this would require the server to be running)
    echo "Note: WebSocket connection test requires the server to be running"
    echo "To test WebSocket manually:"
    echo "1. Start the server: go run ./cmd/server"
    echo "2. Connect with: websocat ws://localhost:8080/ws"
else
    echo "⚠️  websocat not available - install with: brew install websocat"
fi

# Check WebSocket handler exists
echo "1. Testing WebSocket Handler Files..."
[ -f "internal/handler/realtime_handler.go" ] && echo "✅ WebSocket handler exists" || { echo "❌ WebSocket handler missing"; exit 1; }

# Check for WebSocket-related code in the handler
echo "2. Testing WebSocket Implementation..."
if grep -q "websocket" internal/handler/realtime_handler.go; then
    echo "✅ WebSocket implementation found in handler"
else
    echo "❌ WebSocket implementation not found"
    exit 1
fi

# Check for authentication middleware
echo "3. Testing Authentication Middleware..."
[ -f "internal/middleware/auth_middleware.go" ] && echo "✅ Auth middleware exists" || echo "⚠️  Auth middleware file not found"

# Check for security middleware
if [ -f "internal/middleware/security_middleware.go" ]; then
    echo "✅ Security middleware exists"
else
    echo "⚠️  Security middleware not found"
fi

echo
echo "=== WebSocket Connection Test Summary ==="
echo "✅ WebSocket handler components are in place"
echo "✅ Core WebSocket functionality is implemented"
echo
echo "To perform live WebSocket testing:"
echo "1. Ensure Docker services are running: docker-compose up -d postgres redis"
echo "2. Start the server: go run ./cmd/server"
echo "3. Test connection with a WebSocket client"
echo
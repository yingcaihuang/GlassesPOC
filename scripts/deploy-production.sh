#!/bin/bash

# Production deployment script
# This script helps deploy the application with the correct server host configuration

set -e

# Get the server's public IP or hostname
if [ -z "$SERVER_HOST" ]; then
    echo "SERVER_HOST environment variable not set."
    echo "Please set it to your server's public IP or domain name:"
    echo "export SERVER_HOST=your-server-ip-or-domain"
    echo ""
    echo "For example:"
    echo "export SERVER_HOST=123.456.789.123"
    echo "export SERVER_HOST=yourdomain.com"
    echo ""
    echo "Then run this script again."
    exit 1
fi

echo "🚀 Starting production deployment..."
echo "📡 Server Host: $SERVER_HOST"

# Stop existing containers
echo "🛑 Stopping existing containers..."
docker-compose -f docker-compose.production.yml down

# Remove old images to force rebuild
echo "🗑️  Removing old images..."
docker-compose -f docker-compose.production.yml down --rmi all || true

# Build and start services
echo "🔨 Building and starting services..."
SERVER_HOST=$SERVER_HOST docker-compose -f docker-compose.production.yml up --build -d

# Wait for services to be ready
echo "⏳ Waiting for services to start..."
sleep 10

# Check service status
echo "📊 Service status:"
docker-compose -f docker-compose.production.yml ps

echo ""
echo "✅ Deployment complete!"
echo "🌐 Frontend: http://$SERVER_HOST:3000"
echo "🔧 Backend API: http://$SERVER_HOST:8080"
echo ""
echo "📝 To check logs:"
echo "docker-compose -f docker-compose.production.yml logs -f"
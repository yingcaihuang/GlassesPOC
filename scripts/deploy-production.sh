#!/bin/bash

# Production deployment script
# This script helps deploy the application using pre-built images from Azure Container Registry

set -e

# Default values
CONTAINER_REGISTRY=${CONTAINER_REGISTRY:-smartglassesacr}
IMAGE_NAME=${IMAGE_NAME:-smart-glasses-app}
IMAGE_TAG=${IMAGE_TAG:-latest}

echo "🚀 Starting production deployment with pre-built images..."
echo "📦 Container Registry: $CONTAINER_REGISTRY"
echo "🔧 Backend Image: $CONTAINER_REGISTRY.azurecr.io/$IMAGE_NAME-backend:$IMAGE_TAG"
echo "🌐 Frontend Image: $CONTAINER_REGISTRY.azurecr.io/$IMAGE_NAME-frontend:$IMAGE_TAG"

# Check if we have Azure CLI and are logged in
if command -v az &> /dev/null; then
    echo "🔐 Logging into Azure Container Registry..."
    az acr login --name $CONTAINER_REGISTRY || {
        echo "⚠️  Failed to login to ACR. Make sure you're logged into Azure CLI."
        echo "ℹ️  You can login with: az login"
        echo "ℹ️  Or use managed identity if running on Azure VM"
    }
else
    echo "ℹ️  Azure CLI not found. Assuming Docker is already authenticated to ACR."
fi

# Stop existing containers
echo "🛑 Stopping existing containers..."
docker-compose -f docker-compose.production.yml down || true

# Pull latest images
echo "📥 Pulling latest images..."
docker pull $CONTAINER_REGISTRY.azurecr.io/$IMAGE_NAME-backend:$IMAGE_TAG || {
    echo "❌ Failed to pull backend image. Please check:"
    echo "   - Image exists: $CONTAINER_REGISTRY.azurecr.io/$IMAGE_NAME-backend:$IMAGE_TAG"
    echo "   - You have access to the registry"
    echo "   - Network connectivity"
    exit 1
}

docker pull $CONTAINER_REGISTRY.azurecr.io/$IMAGE_NAME-frontend:$IMAGE_TAG || {
    echo "❌ Failed to pull frontend image. Please check:"
    echo "   - Image exists: $CONTAINER_REGISTRY.azurecr.io/$IMAGE_NAME-frontend:$IMAGE_TAG"
    echo "   - You have access to the registry"
    echo "   - Network connectivity"
    exit 1
}

# Start services
echo "🔨 Starting services with pre-built images..."
CONTAINER_REGISTRY=$CONTAINER_REGISTRY \
IMAGE_NAME=$IMAGE_NAME \
IMAGE_TAG=$IMAGE_TAG \
docker-compose -f docker-compose.production.yml up -d

# Wait for services to be ready
echo "⏳ Waiting for services to start..."
sleep 15

# Check service status
echo "📊 Service status:"
docker-compose -f docker-compose.production.yml ps

# Get the server IP for display
if command -v curl &> /dev/null; then
    SERVER_IP=$(curl -s ifconfig.me 2>/dev/null || echo "localhost")
else
    SERVER_IP="localhost"
fi

echo ""
echo "✅ Deployment complete!"
echo "🌐 Frontend: http://$SERVER_IP:3000"
echo "🔧 Backend API: http://$SERVER_IP:8080"
echo ""
echo "📝 To check logs:"
echo "docker-compose -f docker-compose.production.yml logs -f"
echo ""
echo "🔍 To check specific service logs:"
echo "docker-compose -f docker-compose.production.yml logs -f frontend"
echo "docker-compose -f docker-compose.production.yml logs -f app"
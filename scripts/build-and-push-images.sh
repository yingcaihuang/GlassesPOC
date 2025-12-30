#!/bin/bash

# Build and push Docker images to Azure Container Registry
# This script builds both frontend and backend images and pushes them to ACR

set -e

# Configuration
CONTAINER_REGISTRY=${CONTAINER_REGISTRY:-smartglassesacr}
IMAGE_NAME=${IMAGE_NAME:-smart-glasses-app}
IMAGE_TAG=${IMAGE_TAG:-$(git rev-parse HEAD)}
SERVER_HOST=${SERVER_HOST:-localhost}
AUTO_CLEANUP=${AUTO_CLEANUP:-true}

echo "🔨 Building and pushing Docker images..."
echo "📦 Container Registry: $CONTAINER_REGISTRY"
echo "🏷️  Image Tag: $IMAGE_TAG"
echo "📡 Server Host: $SERVER_HOST"
echo "🧹 Auto cleanup: $AUTO_CLEANUP"

# Login to Azure Container Registry
echo "🔐 Logging into Azure Container Registry..."
az acr login --name $CONTAINER_REGISTRY

# Build and push backend image
echo "🔧 Building backend image..."
docker build -t $CONTAINER_REGISTRY.azurecr.io/$IMAGE_NAME-backend:$IMAGE_TAG .

echo "📤 Pushing backend image..."
docker push $CONTAINER_REGISTRY.azurecr.io/$IMAGE_NAME-backend:$IMAGE_TAG

# Build and push frontend image with proper API URL
echo "🌐 Building frontend image..."
docker build \
  --build-arg VITE_API_URL=http://$SERVER_HOST:8080/api/v1 \
  -t $CONTAINER_REGISTRY.azurecr.io/$IMAGE_NAME-frontend:$IMAGE_TAG \
  ./frontend

echo "📤 Pushing frontend image..."
docker push $CONTAINER_REGISTRY.azurecr.io/$IMAGE_NAME-frontend:$IMAGE_TAG

# Tag as latest
echo "🏷️  Tagging as latest..."
docker tag $CONTAINER_REGISTRY.azurecr.io/$IMAGE_NAME-backend:$IMAGE_TAG $CONTAINER_REGISTRY.azurecr.io/$IMAGE_NAME-backend:latest
docker tag $CONTAINER_REGISTRY.azurecr.io/$IMAGE_NAME-frontend:$IMAGE_TAG $CONTAINER_REGISTRY.azurecr.io/$IMAGE_NAME-frontend:latest

docker push $CONTAINER_REGISTRY.azurecr.io/$IMAGE_NAME-backend:latest
docker push $CONTAINER_REGISTRY.azurecr.io/$IMAGE_NAME-frontend:latest

echo ""
echo "✅ Images built and pushed successfully!"
echo "🔧 Backend: $CONTAINER_REGISTRY.azurecr.io/$IMAGE_NAME-backend:$IMAGE_TAG"
echo "🌐 Frontend: $CONTAINER_REGISTRY.azurecr.io/$IMAGE_NAME-frontend:$IMAGE_TAG"

# Auto cleanup old images
if [ "$AUTO_CLEANUP" = "true" ]; then
    echo ""
    echo "🧹 Running automatic cleanup of old images..."
    CONTAINER_REGISTRY=$CONTAINER_REGISTRY IMAGE_NAME=$IMAGE_NAME ./scripts/cleanup-acr-images.sh
else
    echo ""
    echo "ℹ️  Auto cleanup is disabled. To cleanup old images manually, run:"
    echo "   ./scripts/cleanup-acr-images.sh"
fi

echo ""
echo "📝 Update your .env file with:"
echo "IMAGE_NAME=$IMAGE_NAME"
echo "IMAGE_TAG=$IMAGE_TAG"
echo ""
echo "🚀 Now you can deploy with:"
echo "./scripts/deploy-production.sh"
#!/bin/bash

# List ACR Images Script
# This script shows all images and tags in your Azure Container Registry

set -e

# Configuration
CONTAINER_REGISTRY=${CONTAINER_REGISTRY:-smartglassesacr}
IMAGE_NAME=${IMAGE_NAME:-smart-glasses-app}

echo "📦 Listing images in Azure Container Registry: $CONTAINER_REGISTRY"
echo ""

# Check if Azure CLI is available
if ! command -v az &> /dev/null; then
    echo "❌ Azure CLI not found. Please install Azure CLI first."
    exit 1
fi

# Check Azure login
if ! az account show &>/dev/null; then
    echo "❌ Not logged into Azure. Please run: az login"
    exit 1
fi

# List all repositories
echo "📋 All repositories in $CONTAINER_REGISTRY:"
az acr repository list --name $CONTAINER_REGISTRY --output table 2>/dev/null || {
    echo "❌ Failed to list repositories. Check if ACR exists and you have access."
    exit 1
}

echo ""

# Show backend repository details
echo "🔧 Backend repository ($IMAGE_NAME-backend):"
if az acr repository show-tags \
    --name $CONTAINER_REGISTRY \
    --repository "$IMAGE_NAME-backend" \
    --orderby time_desc \
    --output table 2>/dev/null; then
    echo ""
else
    echo "   No backend repository found or no tags"
    echo ""
fi

# Show frontend repository details
echo "🌐 Frontend repository ($IMAGE_NAME-frontend):"
if az acr repository show-tags \
    --name $CONTAINER_REGISTRY \
    --repository "$IMAGE_NAME-frontend" \
    --orderby time_desc \
    --output table 2>/dev/null; then
    echo ""
else
    echo "   No frontend repository found or no tags"
    echo ""
fi

# Show repository sizes
echo "💾 Repository sizes:"
az acr repository list --name $CONTAINER_REGISTRY --output tsv 2>/dev/null | while read repo; do
    if [[ "$repo" == *"$IMAGE_NAME"* ]]; then
        echo "📊 $repo:"
        az acr repository show-manifests \
            --name $CONTAINER_REGISTRY \
            --repository "$repo" \
            --output table 2>/dev/null | head -10 || echo "   Could not get manifest info"
        echo ""
    fi
done

echo "🔧 Management commands:"
echo "   List images: ./scripts/list-acr-images.sh"
echo "   Cleanup old images: ./scripts/cleanup-acr-images.sh"
echo "   Build and push: ./scripts/build-and-push-images.sh"
#!/bin/bash

# ACR Image Cleanup Script
# This script keeps only the latest 3 versions of each repository and deletes older ones

set -e

# Configuration
CONTAINER_REGISTRY=${CONTAINER_REGISTRY:-smartglassesacr}
IMAGE_NAME=${IMAGE_NAME:-smart-glasses-app}
KEEP_COUNT=${KEEP_COUNT:-3}

echo "🧹 Starting ACR image cleanup..."
echo "📦 Container Registry: $CONTAINER_REGISTRY"
echo "🏷️  Image Name: $IMAGE_NAME"
echo "📊 Keeping latest $KEEP_COUNT versions"

# Check if Azure CLI is available
if ! command -v az &> /dev/null; then
    echo "❌ Azure CLI not found. Please install Azure CLI first."
    exit 1
fi

# Login to Azure (if not already logged in)
echo "🔐 Checking Azure login status..."
if ! az account show &>/dev/null; then
    echo "Please login to Azure first:"
    echo "az login"
    exit 1
fi

# Function to cleanup repository
cleanup_repository() {
    local repo_name=$1
    echo ""
    echo "🔍 Cleaning up repository: $repo_name"
    
    # Get all tags sorted by creation time (newest first)
    echo "📋 Getting tags for $repo_name..."
    local tags=$(az acr repository show-tags \
        --name $CONTAINER_REGISTRY \
        --repository $repo_name \
        --orderby time_desc \
        --output tsv 2>/dev/null || echo "")
    
    if [ -z "$tags" ]; then
        echo "⚠️  No tags found for repository $repo_name or repository doesn't exist"
        return
    fi
    
    # Convert tags to array
    local tag_array=($tags)
    local total_tags=${#tag_array[@]}
    
    echo "📊 Found $total_tags tags in $repo_name"
    
    if [ $total_tags -le $KEEP_COUNT ]; then
        echo "✅ Repository $repo_name has $total_tags tags (≤ $KEEP_COUNT), no cleanup needed"
        return
    fi
    
    # Show what we're keeping
    echo "🔒 Keeping latest $KEEP_COUNT tags:"
    for i in $(seq 0 $((KEEP_COUNT-1))); do
        if [ $i -lt $total_tags ]; then
            echo "   - ${tag_array[$i]}"
        fi
    done
    
    # Delete older tags
    local deleted_count=0
    echo "🗑️  Deleting older tags:"
    for i in $(seq $KEEP_COUNT $((total_tags-1))); do
        local tag_to_delete=${tag_array[$i]}
        echo "   - Deleting $repo_name:$tag_to_delete"
        
        if az acr repository delete \
            --name $CONTAINER_REGISTRY \
            --image "$repo_name:$tag_to_delete" \
            --yes &>/dev/null; then
            echo "     ✅ Deleted successfully"
            ((deleted_count++))
        else
            echo "     ❌ Failed to delete"
        fi
    done
    
    echo "📊 Deleted $deleted_count old tags from $repo_name"
}

# Cleanup both backend and frontend repositories
cleanup_repository "$IMAGE_NAME-backend"
cleanup_repository "$IMAGE_NAME-frontend"

echo ""
echo "✅ ACR cleanup completed!"
echo ""
echo "📊 Current repository status:"
echo "🔧 Backend tags:"
az acr repository show-tags \
    --name $CONTAINER_REGISTRY \
    --repository "$IMAGE_NAME-backend" \
    --orderby time_desc \
    --output table 2>/dev/null || echo "   No backend repository found"

echo ""
echo "🌐 Frontend tags:"
az acr repository show-tags \
    --name $CONTAINER_REGISTRY \
    --repository "$IMAGE_NAME-frontend" \
    --orderby time_desc \
    --output table 2>/dev/null || echo "   No frontend repository found"
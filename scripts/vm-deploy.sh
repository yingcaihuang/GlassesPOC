#!/bin/bash

# Simple Azure VM deployment script
set -e

echo "Starting Azure VM deployment"
echo "Current user: $(whoami)"
echo "Current directory: $(pwd)"
echo "Time: $(date)"

# Ensure Docker service is running
echo "Starting Docker service..."
sudo systemctl start docker
sudo systemctl enable docker

# Fix Docker permissions
echo "Fixing Docker permissions..."
sudo usermod -aG docker azureuser
sudo chmod 666 /var/run/docker.sock

# Switch to azureuser and execute deployment
echo "Switching to azureuser for deployment..."
sudo -u azureuser bash -c "
set -e

# Load environment variables file if exists
if [ -f '/tmp/glass/deployment.env' ]; then
    echo 'Loading environment variables file...'
    source /tmp/glass/deployment.env
    echo 'Environment variables file loaded'
else
    echo 'Environment variables file not found, using passed variables'
    export CONTAINER_REGISTRY='${CONTAINER_REGISTRY}'
    export IMAGE_NAME='${IMAGE_NAME}'
    export IMAGE_TAG='${IMAGE_TAG}'
    export AZURE_OPENAI_ENDPOINT='${AZURE_OPENAI_ENDPOINT}'
    export AZURE_OPENAI_API_KEY='${AZURE_OPENAI_API_KEY}'
    export AZURE_OPENAI_DEPLOYMENT_NAME='${AZURE_OPENAI_DEPLOYMENT_NAME}'
    export AZURE_OPENAI_API_VERSION='${AZURE_OPENAI_API_VERSION}'
    export AZURE_OPENAI_REALTIME_ENDPOINT='${AZURE_OPENAI_REALTIME_ENDPOINT}'
    export AZURE_OPENAI_REALTIME_API_KEY='${AZURE_OPENAI_REALTIME_API_KEY}'
    export AZURE_OPENAI_REALTIME_DEPLOYMENT_NAME='${AZURE_OPENAI_REALTIME_DEPLOYMENT_NAME}'
    export AZURE_OPENAI_REALTIME_API_VERSION='${AZURE_OPENAI_REALTIME_API_VERSION}'
    export POSTGRES_PASSWORD='${POSTGRES_PASSWORD}'
    export JWT_SECRET_KEY='${JWT_SECRET_KEY}'
fi

echo \"Current user: \$(whoami)\"
echo \"Current directory: \$(pwd)\"

# Set working directory
mkdir -p /tmp/glass
cd /tmp/glass
echo \"Application directory: \$(pwd)\"

# Check Docker access
echo \"Checking Docker access...\"
if ! docker info >/dev/null 2>&1; then
    echo \"Docker access failed, waiting for permissions...\"
    sleep 10
    if ! docker info >/dev/null 2>&1; then
        echo \"Docker still not accessible\"
        exit 1
    fi
fi
echo \"Docker access OK\"

# Login to ACR using managed identity
echo \"Logging in to Azure Container Registry using managed identity...\"

# Set defaults for environment variables
if [ -z \"\$CONTAINER_REGISTRY\" ]; then
    echo \"CONTAINER_REGISTRY not set, using default: smartglassesacr\"
    CONTAINER_REGISTRY=\"smartglassesacr\"
fi

if [ -z \"\$IMAGE_NAME\" ]; then
    echo \"IMAGE_NAME not set, using default: smart-glasses-app\"
    IMAGE_NAME=\"smart-glasses-app\"
fi

if [ -z \"\$IMAGE_TAG\" ]; then
    echo \"IMAGE_TAG not set, trying to get latest tag...\"
    LATEST_TAG=\$(az acr repository show-tags --name \$CONTAINER_REGISTRY --repository \${IMAGE_NAME}-backend --orderby time_desc --output tsv | head -1 2>/dev/null || echo \"\")
    if [ -n \"\$LATEST_TAG\" ]; then
        IMAGE_TAG=\"\$LATEST_TAG\"
        echo \"Found latest tag: \$IMAGE_TAG\"
    else
        echo \"Could not get latest tag, using default: latest\"
        IMAGE_TAG=\"latest\"
    fi
fi

echo \"Using configuration:\"
echo \"  CONTAINER_REGISTRY: \$CONTAINER_REGISTRY\"
echo \"  IMAGE_NAME: \$IMAGE_NAME\"
echo \"  IMAGE_TAG: \$IMAGE_TAG\"

# Validate environment variables
echo \"Validating environment variables:\"
if [ -z \"\$AZURE_OPENAI_ENDPOINT\" ]; then
    echo \"ERROR: AZURE_OPENAI_ENDPOINT not set\"
    echo \"Please check GitHub Secrets for AZURE_OPENAI_ENDPOINT\"
else
    echo \"OK: AZURE_OPENAI_ENDPOINT is set\"
fi

if [ -z \"\$AZURE_OPENAI_API_KEY\" ]; then
    echo \"ERROR: AZURE_OPENAI_API_KEY not set\"
    echo \"Please check GitHub Secrets for AZURE_OPENAI_API_KEY\"
else
    echo \"OK: AZURE_OPENAI_API_KEY is set\"
fi

if [ -z \"\$POSTGRES_PASSWORD\" ]; then
    echo \"ERROR: POSTGRES_PASSWORD not set\"
    echo \"Please check GitHub Secrets for POSTGRES_PASSWORD\"
else
    echo \"OK: POSTGRES_PASSWORD is set\"
fi

if [ -z \"\$JWT_SECRET_KEY\" ]; then
    echo \"ERROR: JWT_SECRET_KEY not set\"
    echo \"Please check GitHub Secrets for JWT_SECRET_KEY\"
else
    echo \"OK: JWT_SECRET_KEY is set\"
fi

# Install Azure CLI if needed
if ! command -v az &> /dev/null; then
    echo \"Installing Azure CLI...\"
    curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash
fi

# Login with managed identity
echo \"Logging in with managed identity...\"
if az login --identity; then
    echo \"Managed identity login successful\"
    
    # Login to ACR
    echo \"Logging in to ACR: \$CONTAINER_REGISTRY.azurecr.io\"
    if az acr login --name \$CONTAINER_REGISTRY; then
        echo \"ACR login successful\"
    else
        echo \"ACR login failed\"
        echo \"Possible reasons:\"
        echo \"  1. VM managed identity does not have AcrPull permission\"
        echo \"  2. ACR does not exist or name is incorrect: \$CONTAINER_REGISTRY\"
        echo \"Please run manual role assignment script: ./scripts/assign-acr-role-manual.sh\"
        exit 1
    fi
else
    echo \"Managed identity login failed\"
    echo \"Possible reasons:\"
    echo \"  1. VM does not have assigned managed identity\"
    echo \"  2. Managed identity configuration issue\"
    echo \"Please check VM managed identity configuration\"
    exit 1
fi

# Create migrations directory and files
mkdir -p migrations

# Create database migration files
cat > migrations/001_init.sql << 'SQL_EOF'
CREATE TABLE IF NOT EXISTS users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    username VARCHAR(50) UNIQUE NOT NULL,
    email VARCHAR(100) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS translation_history (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    source_text TEXT NOT NULL,
    translated_text TEXT NOT NULL,
    source_language VARCHAR(10) NOT NULL,
    target_language VARCHAR(10) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_users_email ON users(email);
CREATE INDEX IF NOT EXISTS idx_users_username ON users(username);
CREATE INDEX IF NOT EXISTS idx_translation_history_user_id ON translation_history(user_id);
CREATE INDEX IF NOT EXISTS idx_translation_history_created_at ON translation_history(created_at);
SQL_EOF

cat > migrations/002_add_statistics.sql << 'SQL2_EOF'
CREATE TABLE IF NOT EXISTS token_usage (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    input_tokens INTEGER NOT NULL DEFAULT 0,
    output_tokens INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_token_usage_user_id ON token_usage(user_id);
CREATE INDEX IF NOT EXISTS idx_token_usage_created_at ON token_usage(created_at);
SQL2_EOF

# Create docker-compose.yml
cat > docker-compose.yml << 'COMPOSE_EOF'
services:
  postgres:
    image: postgres:15-alpine
    container_name: glass-postgres
    environment:
      POSTGRES_USER: smartglasses
      POSTGRES_PASSWORD: \${POSTGRES_PASSWORD:-smartglasses123}
      POSTGRES_DB: smart_glasses
    ports:
      - \"5432:5432\"
    volumes:
      - glass_postgres_data:/var/lib/postgresql/data
      - ./migrations:/docker-entrypoint-initdb.d
    healthcheck:
      test: [\"CMD-SHELL\", \"pg_isready -U smartglasses\"]
      interval: 10s
      timeout: 5s
      retries: 5
    restart: unless-stopped

  redis:
    image: redis:7-alpine
    container_name: glass-redis
    ports:
      - \"6379:6379\"
    volumes:
      - glass_redis_data:/data
    command: redis-server --appendonly yes
    healthcheck:
      test: [\"CMD\", \"redis-cli\", \"ping\"]
      interval: 10s
      timeout: 5s
      retries: 5
    restart: unless-stopped

  app:
    image: \${CONTAINER_REGISTRY:-smartglassesacr}.azurecr.io/\${IMAGE_NAME:-smart-glasses-app}-backend:\${IMAGE_TAG:-latest}
    container_name: glass-app
    environment:
      SERVER_PORT: \"8080\"
      SERVER_ENV: \"production\"
      POSTGRES_DSN: \"postgres://smartglasses:\${POSTGRES_PASSWORD:-smartglasses123}@postgres:5432/smart_glasses?sslmode=disable\"
      REDIS_ADDR: \"redis:6379\"
      REDIS_PASSWORD: \"\"
      JWT_SECRET_KEY: \"\${JWT_SECRET_KEY:-change-this-in-production}\"
      JWT_ACCESS_TOKEN_EXPIRY: \"1h\"
      JWT_REFRESH_TOKEN_EXPIRY: \"168h\"
      AZURE_OPENAI_ENDPOINT: \"\${AZURE_OPENAI_ENDPOINT}\"
      AZURE_OPENAI_API_KEY: \"\${AZURE_OPENAI_API_KEY}\"
      AZURE_OPENAI_DEPLOYMENT_NAME: \"\${AZURE_OPENAI_DEPLOYMENT_NAME:-gpt-4o}\"
      AZURE_OPENAI_API_VERSION: \"\${AZURE_OPENAI_API_VERSION:-2024-08-01-preview}\"
      AZURE_OPENAI_REALTIME_ENDPOINT: \"\${AZURE_OPENAI_REALTIME_ENDPOINT}\"
      AZURE_OPENAI_REALTIME_API_KEY: \"\${AZURE_OPENAI_REALTIME_API_KEY}\"
      AZURE_OPENAI_REALTIME_DEPLOYMENT_NAME: \"\${AZURE_OPENAI_REALTIME_DEPLOYMENT_NAME:-gpt-realtime}\"
      AZURE_OPENAI_REALTIME_API_VERSION: \"\${AZURE_OPENAI_REALTIME_API_VERSION:-2024-10-01-preview}\"
    ports:
      - \"8080:8080\"
    depends_on:
      postgres:
        condition: service_healthy
      redis:
        condition: service_healthy
    restart: unless-stopped

  frontend:
    image: \${CONTAINER_REGISTRY:-smartglassesacr}.azurecr.io/\${IMAGE_NAME:-smart-glasses-app}-frontend:\${IMAGE_TAG:-latest}
    container_name: glass-frontend
    ports:
      - \"3000:80\"
    depends_on:
      - app
    restart: unless-stopped

volumes:
  glass_postgres_data:
  glass_redis_data:
COMPOSE_EOF

# Create .env file
echo \"Creating .env file...\"
cat > .env << ENV_EOF
AZURE_OPENAI_ENDPOINT=\$AZURE_OPENAI_ENDPOINT
AZURE_OPENAI_API_KEY=\$AZURE_OPENAI_API_KEY
AZURE_OPENAI_DEPLOYMENT_NAME=\$AZURE_OPENAI_DEPLOYMENT_NAME
AZURE_OPENAI_API_VERSION=\$AZURE_OPENAI_API_VERSION
AZURE_OPENAI_REALTIME_ENDPOINT=\$AZURE_OPENAI_REALTIME_ENDPOINT
AZURE_OPENAI_REALTIME_API_KEY=\$AZURE_OPENAI_REALTIME_API_KEY
AZURE_OPENAI_REALTIME_DEPLOYMENT_NAME=\$AZURE_OPENAI_REALTIME_DEPLOYMENT_NAME
AZURE_OPENAI_REALTIME_API_VERSION=\$AZURE_OPENAI_REALTIME_API_VERSION
POSTGRES_PASSWORD=\$POSTGRES_PASSWORD
JWT_SECRET_KEY=\$JWT_SECRET_KEY
CONTAINER_REGISTRY=\$CONTAINER_REGISTRY
IMAGE_NAME=\$IMAGE_NAME
IMAGE_TAG=\$IMAGE_TAG
ENV_EOF

echo \".env file created\"
echo \"Verifying .env file content (hiding sensitive info):\"
cat .env | sed 's/=.*/=***/' | head -10

echo \"Files created successfully:\"
ls -la

# Stop existing services
echo \"Stopping existing services...\"
docker-compose down || true

# Clean old database data (force fresh initialization)
echo \"Cleaning old database data...\"
docker volume rm glass_postgres_data 2>/dev/null || true

# Pull latest images
echo \"Pulling latest images...\"
if ! docker-compose pull; then
    echo \"Image pull failed, trying to find available image tags...\"
    
    echo \"Looking for latest image tags...\"
    AVAILABLE_TAG=\$(az acr repository show-tags --name \$CONTAINER_REGISTRY --repository \${IMAGE_NAME}-backend --orderby time_desc --output tsv | head -1 2>/dev/null || echo \"\")
    
    if [ -n \"\$AVAILABLE_TAG\" ]; then
        echo \"Found available tag: \$AVAILABLE_TAG\"
        echo \"Updating IMAGE_TAG and recreating config files...\"
        
        # Update environment variable
        export IMAGE_TAG=\"\$AVAILABLE_TAG\"
        
        # Recreate .env file
        echo \"Recreating .env file...\"
        cat > .env << ENV_EOF
AZURE_OPENAI_ENDPOINT=\$AZURE_OPENAI_ENDPOINT
AZURE_OPENAI_API_KEY=\$AZURE_OPENAI_API_KEY
AZURE_OPENAI_DEPLOYMENT_NAME=\$AZURE_OPENAI_DEPLOYMENT_NAME
AZURE_OPENAI_API_VERSION=\$AZURE_OPENAI_API_VERSION
AZURE_OPENAI_REALTIME_ENDPOINT=\$AZURE_OPENAI_REALTIME_ENDPOINT
AZURE_OPENAI_REALTIME_API_KEY=\$AZURE_OPENAI_REALTIME_API_KEY
AZURE_OPENAI_REALTIME_DEPLOYMENT_NAME=\$AZURE_OPENAI_REALTIME_DEPLOYMENT_NAME
AZURE_OPENAI_REALTIME_API_VERSION=\$AZURE_OPENAI_REALTIME_API_VERSION
POSTGRES_PASSWORD=\$POSTGRES_PASSWORD
JWT_SECRET_KEY=\$JWT_SECRET_KEY
CONTAINER_REGISTRY=\$CONTAINER_REGISTRY
IMAGE_NAME=\$IMAGE_NAME
IMAGE_TAG=\$IMAGE_TAG
ENV_EOF
        
        echo \".env file recreated\"
        
        # Recreate docker-compose.yml with new tag
        cat > docker-compose.yml << 'COMPOSE_EOF'
services:
  postgres:
    image: postgres:15-alpine
    container_name: glass-postgres
    environment:
      POSTGRES_USER: smartglasses
      POSTGRES_PASSWORD: \${POSTGRES_PASSWORD:-smartglasses123}
      POSTGRES_DB: smart_glasses
    ports:
      - \"5432:5432\"
    volumes:
      - glass_postgres_data:/var/lib/postgresql/data
      - ./migrations:/docker-entrypoint-initdb.d
    healthcheck:
      test: [\"CMD-SHELL\", \"pg_isready -U smartglasses\"]
      interval: 10s
      timeout: 5s
      retries: 5
    restart: unless-stopped

  redis:
    image: redis:7-alpine
    container_name: glass-redis
    ports:
      - \"6379:6379\"
    volumes:
      - glass_redis_data:/data
    command: redis-server --appendonly yes
    healthcheck:
      test: [\"CMD\", \"redis-cli\", \"ping\"]
      interval: 10s
      timeout: 5s
      retries: 5
    restart: unless-stopped

  app:
    image: \${CONTAINER_REGISTRY:-smartglassesacr}.azurecr.io/\${IMAGE_NAME:-smart-glasses-app}-backend:\${IMAGE_TAG}
    container_name: glass-app
    environment:
      SERVER_PORT: \"8080\"
      SERVER_ENV: \"production\"
      POSTGRES_DSN: \"postgres://smartglasses:\${POSTGRES_PASSWORD:-smartglasses123}@postgres:5432/smart_glasses?sslmode=disable\"
      REDIS_ADDR: \"redis:6379\"
      REDIS_PASSWORD: \"\"
      JWT_SECRET_KEY: \"\${JWT_SECRET_KEY:-change-this-in-production}\"
      JWT_ACCESS_TOKEN_EXPIRY: \"1h\"
      JWT_REFRESH_TOKEN_EXPIRY: \"168h\"
      AZURE_OPENAI_ENDPOINT: \"\${AZURE_OPENAI_ENDPOINT}\"
      AZURE_OPENAI_API_KEY: \"\${AZURE_OPENAI_API_KEY}\"
      AZURE_OPENAI_DEPLOYMENT_NAME: \"\${AZURE_OPENAI_DEPLOYMENT_NAME:-gpt-4o}\"
      AZURE_OPENAI_API_VERSION: \"\${AZURE_OPENAI_API_VERSION:-2024-08-01-preview}\"
      AZURE_OPENAI_REALTIME_ENDPOINT: \"\${AZURE_OPENAI_REALTIME_ENDPOINT}\"
      AZURE_OPENAI_REALTIME_API_KEY: \"\${AZURE_OPENAI_REALTIME_API_KEY}\"
      AZURE_OPENAI_REALTIME_DEPLOYMENT_NAME: \"\${AZURE_OPENAI_REALTIME_DEPLOYMENT_NAME:-gpt-realtime}\"
      AZURE_OPENAI_REALTIME_API_VERSION: \"\${AZURE_OPENAI_REALTIME_API_VERSION:-2024-10-01-preview}\"
    ports:
      - \"8080:8080\"
    depends_on:
      postgres:
        condition: service_healthy
      redis:
        condition: service_healthy
    restart: unless-stopped

  frontend:
    image: \${CONTAINER_REGISTRY:-smartglassesacr}.azurecr.io/\${IMAGE_NAME:-smart-glasses-app}-frontend:\${IMAGE_TAG}
    container_name: glass-frontend
    ports:
      - \"3000:80\"
    depends_on:
      - app
    restart: unless-stopped

volumes:
  glass_postgres_data:
  glass_redis_data:
COMPOSE_EOF
        
        echo \"Pulling images with new tag...\"
        docker-compose pull
    else
        echo \"Could not find available image tags\"
        echo \"Please check if images exist in ACR\"
        exit 1
    fi
fi

# Start services
echo \"Starting services...\"
docker-compose up -d

# Wait for services to start
echo \"Waiting for services to start...\"
sleep 30

# Check service status
echo \"Checking service status...\"
docker-compose ps

# Force database migration
echo \"Force executing database migration...\"
echo \"Waiting for PostgreSQL to fully start...\"
sleep 10

# Check if PostgreSQL is ready
for i in \$(seq 1 30); do
    if docker-compose exec -T postgres pg_isready -U smartglasses >/dev/null 2>&1; then
        echo \"PostgreSQL is ready\"
        break
    else
        echo \"Waiting for PostgreSQL... attempt \$i/30\"
        sleep 2
    fi
done

# Execute database migration
echo \"Executing database migration scripts...\"
docker-compose exec -T postgres psql -U smartglasses -d smart_glasses << 'MIGRATION_SQL'
CREATE TABLE IF NOT EXISTS users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    username VARCHAR(50) UNIQUE NOT NULL,
    email VARCHAR(100) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS translation_history (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    source_text TEXT NOT NULL,
    translated_text TEXT NOT NULL,
    source_language VARCHAR(10) NOT NULL,
    target_language VARCHAR(10) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS token_usage (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    input_tokens INTEGER NOT NULL DEFAULT 0,
    output_tokens INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_users_email ON users(email);
CREATE INDEX IF NOT EXISTS idx_users_username ON users(username);
CREATE INDEX IF NOT EXISTS idx_translation_history_user_id ON translation_history(user_id);
CREATE INDEX IF NOT EXISTS idx_translation_history_created_at ON translation_history(created_at);
CREATE INDEX IF NOT EXISTS idx_token_usage_user_id ON token_usage(user_id);
CREATE INDEX IF NOT EXISTS idx_token_usage_created_at ON token_usage(created_at);
MIGRATION_SQL

echo \"Database migration execution completed\"

# Verify tables were created successfully
echo \"Verifying database tables...\"
docker-compose exec -T postgres psql -U smartglasses -d smart_glasses -c \"\\\\dt\"

# Test database connection
echo \"Testing database connection...\"
docker-compose exec -T postgres psql -U smartglasses -d smart_glasses -c \"SELECT 'Database connection successful' as status;\"

# Show application logs
echo \"Application logs:\"
docker-compose logs --tail=20 app

echo \"Deployment completed!\"
"

echo "VM deployment script completed!"
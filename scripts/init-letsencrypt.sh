#!/bin/bash

# Initialize Let's Encrypt certificates for glasses.gslb.vip
# This script sets up certbot and obtains SSL certificates

set -e

DOMAIN="glasses.gslb.vip"
EMAIL="admin@gslb.vip"  # Change this to your email
STAGING=${STAGING:-0}   # Set to 1 for testing

echo "🔒 Initializing Let's Encrypt for $DOMAIN"
echo "📧 Email: $EMAIL"
echo "🧪 Staging mode: $STAGING"

# Create required directories
mkdir -p nginx/ssl
mkdir -p certbot/conf
mkdir -p certbot/www

# Generate self-signed certificate as fallback
echo "🔑 Generating self-signed certificate as fallback..."
./scripts/generate-self-signed-cert.sh

# Check if certificate already exists
if [ -d "certbot/conf/live/$DOMAIN" ]; then
    echo "✅ Certificate for $DOMAIN already exists"
    
    # Copy Let's Encrypt certificate to nginx ssl directory
    cp "certbot/conf/live/$DOMAIN/fullchain.pem" "nginx/ssl/$DOMAIN.crt"
    cp "certbot/conf/live/$DOMAIN/privkey.pem" "nginx/ssl/$DOMAIN.key"
    
    echo "📋 Certificate copied to nginx ssl directory"
    exit 0
fi

# Start nginx with self-signed certificate first
echo "🚀 Starting nginx with self-signed certificate..."
docker-compose up -d nginx

# Wait for nginx to be ready
echo "⏳ Waiting for nginx to be ready..."
sleep 10

# Test if nginx is responding
if ! curl -k -f -s https://localhost >/dev/null 2>&1; then
    echo "❌ Nginx is not responding. Please check the configuration."
    docker-compose logs nginx
    exit 1
fi

echo "✅ Nginx is ready"

# Determine certbot server
if [ $STAGING != "0" ]; then
    CERTBOT_SERVER="--server https://acme-staging-v02.api.letsencrypt.org/directory"
    echo "🧪 Using Let's Encrypt staging server"
else
    CERTBOT_SERVER=""
    echo "🔴 Using Let's Encrypt production server"
fi

# Request certificate
echo "📜 Requesting Let's Encrypt certificate..."
docker-compose run --rm certbot certonly \
    --webroot \
    --webroot-path=/var/www/certbot \
    --email $EMAIL \
    --agree-tos \
    --no-eff-email \
    $CERTBOT_SERVER \
    -d $DOMAIN

# Check if certificate was obtained
if [ -d "certbot/conf/live/$DOMAIN" ]; then
    echo "✅ Certificate obtained successfully!"
    
    # Copy certificate to nginx ssl directory
    cp "certbot/conf/live/$DOMAIN/fullchain.pem" "nginx/ssl/$DOMAIN.crt"
    cp "certbot/conf/live/$DOMAIN/privkey.pem" "nginx/ssl/$DOMAIN.key"
    
    echo "📋 Certificate copied to nginx ssl directory"
    
    # Reload nginx to use new certificate
    echo "🔄 Reloading nginx with new certificate..."
    docker-compose exec nginx nginx -s reload
    
    echo "🎉 HTTPS setup completed successfully!"
    echo "🌐 Your site is now available at: https://$DOMAIN"
    
else
    echo "❌ Failed to obtain certificate"
    echo "📋 Check the logs above for errors"
    echo "💡 Common issues:"
    echo "   - Domain doesn't point to this server"
    echo "   - Port 80 is not accessible from internet"
    echo "   - Rate limiting (try staging mode first)"
    exit 1
fi
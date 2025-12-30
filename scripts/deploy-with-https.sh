#!/bin/bash

# Deploy Smart Glasses App with HTTPS support
# This script sets up the complete application with SSL certificates

set -e

DOMAIN="glasses.gslb.vip"
STAGING=${STAGING:-0}  # Set to 1 for testing with Let's Encrypt staging

echo "🚀 Deploying Smart Glasses App with HTTPS"
echo "=========================================="
echo "🌐 Domain: $DOMAIN"
echo "🧪 Staging mode: $STAGING"

# Check if domain resolves to this server
echo "🔍 Checking DNS resolution..."
DOMAIN_IP=$(dig +short $DOMAIN | tail -n1 2>/dev/null || echo "")
SERVER_IP=$(curl -s ifconfig.me 2>/dev/null || echo "unknown")

if [ -n "$DOMAIN_IP" ] && [ "$DOMAIN_IP" != "$SERVER_IP" ]; then
    echo "⚠️  Warning: Domain $DOMAIN resolves to $DOMAIN_IP, but this server's IP is $SERVER_IP"
    echo "   Please update your DNS records to point to $SERVER_IP"
    echo "   Continue anyway? (y/N)"
    read -r CONTINUE
    if [ "$CONTINUE" != "y" ] && [ "$CONTINUE" != "Y" ]; then
        exit 1
    fi
elif [ -z "$DOMAIN_IP" ]; then
    echo "⚠️  Warning: Could not resolve domain $DOMAIN"
    echo "   Please ensure DNS is configured correctly"
    echo "   Continue anyway? (y/N)"
    read -r CONTINUE
    if [ "$CONTINUE" != "y" ] && [ "$CONTINUE" != "Y" ]; then
        exit 1
    fi
else
    echo "✅ DNS resolution looks good"
fi

# Create required directories
echo "📁 Creating required directories..."
mkdir -p nginx/ssl
mkdir -p certbot/conf
mkdir -p certbot/www

# Generate self-signed certificate as fallback
echo "🔑 Generating self-signed certificate..."
./scripts/generate-self-signed-cert.sh

# Stop existing containers
echo "🛑 Stopping existing containers..."
docker-compose -f docker-compose.production.yml down || true

# Pull latest images
echo "📥 Pulling latest images..."
docker-compose -f docker-compose.production.yml pull

# Start database and redis first
echo "🗄️  Starting database services..."
docker-compose -f docker-compose.production.yml up -d postgres redis

# Wait for database to be ready
echo "⏳ Waiting for database to be ready..."
sleep 15

# Start application services
echo "🚀 Starting application services..."
docker-compose -f docker-compose.production.yml up -d app frontend

# Wait for application to be ready
echo "⏳ Waiting for application to be ready..."
sleep 10

# Start nginx with self-signed certificate
echo "🌐 Starting nginx with self-signed certificate..."
docker-compose -f docker-compose.production.yml up -d nginx

# Wait for nginx to be ready
echo "⏳ Waiting for nginx to be ready..."
sleep 5

# Test if nginx is responding
if curl -k -f -s https://localhost >/dev/null 2>&1; then
    echo "✅ Nginx is responding with self-signed certificate"
else
    echo "❌ Nginx is not responding. Checking logs..."
    docker-compose -f docker-compose.production.yml logs nginx
    exit 1
fi

# Try to get Let's Encrypt certificate
echo "📜 Attempting to get Let's Encrypt certificate..."

# Set staging flag for certbot
if [ $STAGING != "0" ]; then
    CERTBOT_SERVER="--server https://acme-staging-v02.api.letsencrypt.org/directory"
    echo "🧪 Using Let's Encrypt staging server"
else
    CERTBOT_SERVER=""
    echo "🔴 Using Let's Encrypt production server"
fi

# Request certificate
if docker-compose -f docker-compose.production.yml run --rm certbot certonly \
    --webroot \
    --webroot-path=/var/www/certbot \
    --email admin@gslb.vip \
    --agree-tos \
    --no-eff-email \
    $CERTBOT_SERVER \
    -d $DOMAIN; then
    
    echo "✅ Let's Encrypt certificate obtained successfully!"
    
    # Copy certificate to nginx ssl directory
    cp "certbot/conf/live/$DOMAIN/fullchain.pem" "nginx/ssl/$DOMAIN.crt"
    cp "certbot/conf/live/$DOMAIN/privkey.pem" "nginx/ssl/$DOMAIN.key"
    
    echo "📋 Certificate copied to nginx ssl directory"
    
    # Reload nginx to use new certificate
    echo "🔄 Reloading nginx with Let's Encrypt certificate..."
    docker-compose -f docker-compose.production.yml exec nginx nginx -s reload
    
    echo "🎉 Let's Encrypt certificate is now active!"
    
else
    echo "⚠️  Failed to obtain Let's Encrypt certificate"
    echo "📋 Continuing with self-signed certificate"
    echo "💡 Common reasons for failure:"
    echo "   - Domain doesn't point to this server"
    echo "   - Port 80 is not accessible from internet"
    echo "   - Rate limiting (try STAGING=1 first)"
fi

# Set up certificate renewal cron job
echo "🔄 Setting up certificate renewal..."
(crontab -l 2>/dev/null | grep -v "renew-certificates.sh"; echo "0 12 * * * cd $(pwd) && ./scripts/renew-certificates.sh >> /var/log/certbot-renewal.log 2>&1") | crontab -

# Final status check
echo ""
echo "📊 Deployment Status:"
echo "===================="

# Check services
docker-compose -f docker-compose.production.yml ps

echo ""
echo "🧪 Testing endpoints:"

# Test HTTPS
if curl -k -f -s https://localhost >/dev/null 2>&1; then
    echo "✅ HTTPS endpoint responding"
else
    echo "❌ HTTPS endpoint not responding"
fi

# Test HTTP redirect
if curl -s -I http://localhost | grep -q "301\|302"; then
    echo "✅ HTTP to HTTPS redirect working"
else
    echo "❌ HTTP to HTTPS redirect not working"
fi

# Test backend API
if curl -k -f -s https://localhost/api/health >/dev/null 2>&1; then
    echo "✅ Backend API responding"
else
    echo "❌ Backend API not responding"
fi

echo ""
echo "🎉 Deployment completed!"
echo "========================"
echo "🌐 Your application is available at:"
echo "   https://$DOMAIN"
echo ""
echo "🔒 SSL Certificate Status:"
if [ -d "certbot/conf/live/$DOMAIN" ]; then
    echo "   ✅ Let's Encrypt certificate active"
    docker-compose -f docker-compose.production.yml run --rm certbot certificates
else
    echo "   ⚠️  Self-signed certificate active"
    echo "   🔄 Let's Encrypt certificate will be retried automatically"
fi

echo ""
echo "📋 Next steps:"
echo "   1. Update DNS to point $DOMAIN to $SERVER_IP"
echo "   2. Test microphone functionality at https://$DOMAIN"
echo "   3. Monitor certificate renewal logs"
echo ""
echo "🔧 Management commands:"
echo "   Check status: docker-compose -f docker-compose.production.yml ps"
echo "   View logs: docker-compose -f docker-compose.production.yml logs -f"
echo "   Renew certificates: ./scripts/renew-certificates.sh"
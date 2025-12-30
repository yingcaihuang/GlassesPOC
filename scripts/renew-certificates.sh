#!/bin/bash

# Renew Let's Encrypt certificates and reload nginx
# This script should be run periodically (e.g., via cron)

set -e

DOMAIN="glasses.gslb.vip"

echo "🔄 Renewing Let's Encrypt certificates..."

# Renew certificates
docker-compose run --rm certbot renew

# Check if certificate was renewed
if [ -d "certbot/conf/live/$DOMAIN" ]; then
    # Copy renewed certificate to nginx ssl directory
    cp "certbot/conf/live/$DOMAIN/fullchain.pem" "nginx/ssl/$DOMAIN.crt"
    cp "certbot/conf/live/$DOMAIN/privkey.pem" "nginx/ssl/$DOMAIN.key"
    
    echo "📋 Certificate copied to nginx ssl directory"
    
    # Reload nginx
    docker-compose exec nginx nginx -s reload
    
    echo "✅ Certificate renewal completed"
else
    echo "⚠️  No certificate found or renewal not needed"
fi

# Show certificate status
echo "📊 Certificate status:"
docker-compose run --rm certbot certificates
#!/bin/bash

# Generate self-signed SSL certificate for glasses.gslb.vip
# This is used as a fallback before Let's Encrypt certificate is obtained

set -e

DOMAIN="glasses.gslb.vip"
SSL_DIR="./nginx/ssl"
CERT_FILE="$SSL_DIR/$DOMAIN.crt"
KEY_FILE="$SSL_DIR/$DOMAIN.key"

echo "🔒 Generating self-signed SSL certificate for $DOMAIN"

# Create SSL directory
mkdir -p "$SSL_DIR"

# Generate private key
echo "🔑 Generating private key..."
openssl genrsa -out "$KEY_FILE" 2048

# Generate certificate signing request
echo "📝 Generating certificate signing request..."
openssl req -new -key "$KEY_FILE" -out "$SSL_DIR/$DOMAIN.csr" -subj "/C=US/ST=State/L=City/O=Smart Glasses/OU=IT Department/CN=$DOMAIN"

# Generate self-signed certificate
echo "📜 Generating self-signed certificate..."
openssl x509 -req -in "$SSL_DIR/$DOMAIN.csr" -signkey "$KEY_FILE" -out "$CERT_FILE" -days 365 \
    -extensions v3_req -extfile <(cat <<EOF
[v3_req]
keyUsage = keyEncipherment, dataEncipherment
extendedKeyUsage = serverAuth
subjectAltName = @alt_names

[alt_names]
DNS.1 = $DOMAIN
DNS.2 = *.$DOMAIN
EOF
)

# Set proper permissions
chmod 600 "$KEY_FILE"
chmod 644 "$CERT_FILE"

# Clean up CSR
rm -f "$SSL_DIR/$DOMAIN.csr"

echo "✅ Self-signed certificate generated successfully!"
echo "📁 Certificate: $CERT_FILE"
echo "🔑 Private key: $KEY_FILE"
echo ""
echo "⚠️  This is a self-signed certificate. Browsers will show a security warning."
echo "   Users need to click 'Advanced' → 'Proceed to $DOMAIN (unsafe)'"
echo ""
echo "🔄 The certificate will be automatically replaced with a Let's Encrypt certificate"
echo "   when the certbot container runs successfully."
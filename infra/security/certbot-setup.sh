#!/bin/bash
# Скрипт для настройки Let's Encrypt сертификатов через Certbot

set -e

DOMAIN=${1:-api.ringo.example.com}
EMAIL=${2:-admin@ringo.example.com}

if [ -z "$DOMAIN" ]; then
    echo "Usage: $0 <domain> [email]"
    exit 1
fi

echo "Setting up Let's Encrypt certificate for $DOMAIN"

# Установка certbot
if ! command -v certbot &> /dev/null; then
    echo "Installing certbot..."
    apt-get update
    apt-get install -y certbot python3-certbot-nginx
fi

# Получение сертификата
certbot certonly \
    --nginx \
    --non-interactive \
    --agree-tos \
    --email "$EMAIL" \
    -d "$DOMAIN" \
    --keep-until-expiring

# Настройка автоматического обновления
echo "Setting up automatic renewal..."
systemctl enable certbot.timer
systemctl start certbot.timer

# Проверка обновления
certbot renew --dry-run

echo "Certificate setup completed!"
echo "Certificate location: /etc/letsencrypt/live/$DOMAIN/"
echo "Key location: /etc/letsencrypt/live/$DOMAIN/privkey.pem"
echo "Full chain: /etc/letsencrypt/live/$DOMAIN/fullchain.pem"


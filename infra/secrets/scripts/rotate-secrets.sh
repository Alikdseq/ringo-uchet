#!/bin/bash
# Скрипт для ротации секретов через SOPS
# Использование: ./rotate-secrets.sh [staging|production]

set -e

ENVIRONMENT=${1:-staging}
SECRETS_FILE="infra/secrets/${ENVIRONMENT}/secrets.enc.yaml"

if [ ! -f "$SECRETS_FILE" ]; then
    echo "Error: Secrets file not found: $SECRETS_FILE"
    exit 1
fi

echo "Rotating secrets for environment: $ENVIRONMENT"

# Генерация нового Django SECRET_KEY
NEW_SECRET_KEY=$(openssl rand -hex 32)
echo "Generated new SECRET_KEY"

# Генерация нового encryption key
NEW_ENCRYPTION_KEY=$(openssl rand -base64 32)
echo "Generated new encryption key"

# Обновление через SOPS
sops --set "[\"django\"][\"secret_key\"] \"$NEW_SECRET_KEY\"" "$SECRETS_FILE"
sops --set "[\"encryption\"][\"key\"] \"$NEW_ENCRYPTION_KEY\"" "$SECRETS_FILE"

echo "Secrets rotated successfully!"
echo "⚠️  IMPORTANT: Update application servers with new secrets and restart services"


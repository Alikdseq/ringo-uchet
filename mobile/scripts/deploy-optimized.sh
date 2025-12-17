#!/bin/bash
# Скрипт для деплоя оптимизированной веб-версии на сервер (Linux/Mac)
# Использование: ./scripts/deploy-optimized.sh [SERVER_USER] [SERVER_IP] [WEB_DIR]

set -e

# Цвета
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Параметры
SERVER_USER="${1:-root}"
SERVER_IP="${2:-}"
WEB_DIR="${3:-/var/www/ringo-uchet}"

if [ -z "$SERVER_IP" ]; then
    error "Укажите IP адрес сервера: ./scripts/deploy-optimized.sh [USER] [SERVER_IP] [WEB_DIR]"
    exit 1
fi

echo "========================================"
echo "  Optimized Web Deployment"
echo "========================================"
echo ""

# Переходим в директорию проекта
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$SCRIPT_DIR/.."

# Шаг 1: Сборка
info "Step 1: Building optimized web version..."
chmod +x scripts/build-web-optimized.sh
./scripts/build-web-optimized.sh

# Шаг 2: Очистка лишних файлов
info "Step 2: Cleaning unnecessary files..."

if [ -d "build/web" ]; then
    # Удалить source maps
    find build/web -name "*.map" -type f -delete 2>/dev/null || true
    info "  Removed source maps"
    
    # Удалить NOTICES файлы
    find build/web -name "NOTICES*" -type f -delete 2>/dev/null || true
    info "  Removed NOTICES files"
    
    # Проверить размер
    SIZE=$(du -sh build/web | cut -f1)
    info "  Final size: $SIZE"
fi

# Шаг 3: Создание архива
info "Step 3: Creating optimized archive..."

TIMESTAMP=$(date +%Y%m%d-%H%M%S)
ARCHIVE_NAME="web-optimized-$TIMESTAMP.tar.gz"
ARCHIVE_PATH="build/$ARCHIVE_NAME"

cd build
tar -czf "$ARCHIVE_NAME" web/
cd ..

info "  Archive created: $ARCHIVE_NAME"

# Шаг 4: Загрузка на сервер
info "Step 4: Uploading to server..."
info "  Server: $SERVER_USER@$SERVER_IP"
info "  Destination: $WEB_DIR"

REMOTE_ARCHIVE="/tmp/web-latest.tar.gz"

scp "$ARCHIVE_PATH" "${SERVER_USER}@${SERVER_IP}:${REMOTE_ARCHIVE}"

if [ $? -ne 0 ]; then
    error "Failed to upload archive to server"
    exit 1
fi

info "  Archive uploaded successfully"

# Шаг 5: Развертывание на сервере
info "Step 5: Deploying on server..."

ssh "${SERVER_USER}@${SERVER_IP}" << EOF
    # Create backup
    sudo mkdir -p ${WEB_DIR}-backup-\$(date +%Y%m%d-%H%M%S)
    sudo cp -r ${WEB_DIR}/* ${WEB_DIR}-backup-\$(date +%Y%m%d-%H%M%S)/ 2>/dev/null || true
    
    # Create directory if not exists
    sudo mkdir -p ${WEB_DIR}
    
    # Extract new version
    sudo tar -xzf ${REMOTE_ARCHIVE} -C ${WEB_DIR} --strip-components=1
    
    # Set permissions
    sudo chown -R www-data:www-data ${WEB_DIR}
    sudo chmod -R 755 ${WEB_DIR}
    
    # Cleanup
    rm -f ${REMOTE_ARCHIVE}
    
    echo "✅ Deployment completed successfully!"
EOF

if [ $? -ne 0 ]; then
    error "Failed to deploy on server"
    exit 1
fi

echo ""
echo "========================================"
echo "  Deployment completed successfully!"
echo "========================================"
echo ""
echo "Next steps:"
echo "1. Ensure Nginx is configured with gzip/brotli compression"
echo "2. Reload Nginx: ssh $SERVER_USER@$SERVER_IP 'sudo systemctl reload nginx'"
echo "3. Check the application in browser"
echo ""
echo "See DEPLOY_OPTIMIZED.md for Nginx configuration"


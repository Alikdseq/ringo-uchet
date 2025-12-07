#!/bin/bash

# Скрипт для сборки и развертывания Flutter Web приложения
# Использование: ./scripts/build-and-deploy-web.sh [SERVER_USER] [SERVER_IP] [DOMAIN]

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
SERVER_USER="${1:-ringo}"
SERVER_IP="${2:-}"
DOMAIN="${3:-your-domain.com}"
WEB_DIR="/var/www/ringo-uchet"

if [ -z "$SERVER_IP" ]; then
    error "Укажите IP адрес сервера: ./scripts/build-and-deploy-web.sh [USER] [SERVER_IP] [DOMAIN]"
    exit 1
fi

info "Сборка Flutter Web приложения..."

# Проверка Flutter
if ! command -v flutter &> /dev/null; then
    error "Flutter не установлен или не в PATH"
    exit 1
fi

# Переход в директорию mobile
cd "$(dirname "$0")/../mobile" || exit 1

# Очистка
info "Очистка предыдущих сборок..."
flutter clean

# Получение зависимостей
info "Получение зависимостей..."
flutter pub get

# Сборка
info "Сборка для production..."
flutter build web --release --base-href / --dart-define=FLUTTER_WEB_USE_SKIA=true

# Проверка результата
if [ ! -d "build/web" ]; then
    error "Сборка не удалась. Директория build/web не найдена."
    exit 1
fi

info "Сборка завершена успешно!"

# Создание архива
info "Создание архива..."
cd build
tar -czf web-build.tar.gz web/
info "Архив создан: build/web-build.tar.gz"

# Копирование на сервер
info "Копирование на сервер..."
scp web-build.tar.gz $SERVER_USER@$SERVER_IP:/tmp/

# Распаковка на сервере
info "Распаковка на сервере..."
ssh $SERVER_USER@$SERVER_IP << EOF
    sudo mkdir -p $WEB_DIR
    sudo tar -xzf /tmp/web-build.tar.gz -C $WEB_DIR --strip-components=1
    sudo chown -R www-data:www-data $WEB_DIR
    sudo chmod -R 755 $WEB_DIR
    rm /tmp/web-build.tar.gz
    echo "Файлы развернуты в $WEB_DIR"
EOF

info "✅ Развертывание завершено!"
info "Проверьте приложение: https://$DOMAIN"


#!/bin/bash

# Скрипт автоматического развертывания PWA приложения Ringo Uchet
# Использование: ./scripts/deploy-pwa.sh

set -e  # Остановка при ошибке

echo "🚀 Начинаем развертывание PWA приложения Ringo Uchet..."

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Функция для вывода сообщений
info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Проверка, что скрипт запущен от root или с sudo
if [ "$EUID" -ne 0 ]; then 
    error "Пожалуйста, запустите скрипт с sudo"
    exit 1
fi

# Переменные (настройте под себя)
DOMAIN="${DOMAIN:-your-domain.com}"
PROJECT_DIR="${PROJECT_DIR:-/var/www/ringo-uchet}"
BACKEND_DIR="${BACKEND_DIR:-/home/ringo/ringo-uchet/backend}"

info "Домен: $DOMAIN"
info "Директория проекта: $PROJECT_DIR"

# Шаг 1: Создание директорий
info "Создание необходимых директорий..."
mkdir -p $PROJECT_DIR
mkdir -p $PROJECT_DIR/staticfiles
mkdir -p $PROJECT_DIR/media
chown -R www-data:www-data $PROJECT_DIR
chmod -R 755 $PROJECT_DIR

# Шаг 2: Проверка Docker
info "Проверка Docker..."
if ! command -v docker &> /dev/null; then
    error "Docker не установлен. Установите Docker сначала."
    exit 1
fi

# Шаг 3: Проверка Nginx
info "Проверка Nginx..."
if ! command -v nginx &> /dev/null; then
    warn "Nginx не установлен. Устанавливаем..."
    apt update
    apt install -y nginx
fi

# Шаг 4: Копирование конфигурации Nginx
info "Настройка Nginx..."
if [ -f "/etc/nginx/sites-available/ringo-uchet" ]; then
    warn "Конфигурация Nginx уже существует. Пропускаем..."
else
    # Здесь должна быть конфигурация Nginx (см. документацию)
    info "Создайте конфигурацию Nginx вручную (см. docs/PWA_DEPLOYMENT_GUIDE.md)"
fi

# Шаг 5: Проверка SSL
info "Проверка SSL сертификата..."
if [ -f "/etc/letsencrypt/live/$DOMAIN/fullchain.pem" ]; then
    info "SSL сертификат найден"
else
    warn "SSL сертификат не найден. Запустите: sudo certbot certonly --standalone -d $DOMAIN"
fi

# Шаг 6: Запуск Docker контейнеров
info "Запуск Docker контейнеров..."
if [ -f "$BACKEND_DIR/../docker-compose.prod.yml" ]; then
    cd $BACKEND_DIR/..
    docker compose -f docker-compose.prod.yml up -d
    info "Docker контейнеры запущены"
else
    error "Файл docker-compose.prod.yml не найден"
    exit 1
fi

# Шаг 7: Применение миграций
info "Применение миграций базы данных..."
docker compose -f docker-compose.prod.yml exec -T django-api python manage.py migrate --noinput

# Шаг 8: Сбор статических файлов
info "Сбор статических файлов..."
docker compose -f docker-compose.prod.yml exec -T django-api python manage.py collectstatic --noinput

# Шаг 9: Перезагрузка Nginx
info "Перезагрузка Nginx..."
nginx -t && systemctl reload nginx

info "✅ Развертывание завершено!"
info "Проверьте приложение по адресу: https://$DOMAIN"


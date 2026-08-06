#!/usr/bin/env bash
# Деплой Ringo Uchet на production (ringoouchet.ru / 89.169.38.5)
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

COMPOSE="docker compose -f docker-compose.prod.yml --env-file .env.prod"

if [[ ! -f .env.prod ]]; then
  echo "Создайте .env.prod из шаблона:"
  echo "  cp .env.prod.example .env.prod"
  echo "  nano .env.prod"
  exit 1
fi

echo "==> Сборка и запуск контейнеров..."
export NGINX_CONF="${NGINX_CONF:-prod-init.conf}"
$COMPOSE up -d --build

echo "==> Ожидание API..."
for i in $(seq 1 30); do
  if $COMPOSE exec -T django-api python -c \
    "import urllib.request; urllib.request.urlopen('http://127.0.0.1:8000/api/health/', timeout=3)" 2>/dev/null; then
    echo "API healthy"
    break
  fi
  sleep 3
done

echo ""
echo "Готово (HTTP). Проверка:"
echo "  curl -I http://ringoouchet.ru/api/health/"
echo ""
echo "SSL (после того как DNS указывает на 89.169.38.5):"
echo "  $COMPOSE --profile ssl run --rm certbot"
echo "  export NGINX_CONF=prod.conf"
echo "  $COMPOSE up -d nginx"
echo ""
echo "Повторный деплой (без пересборки):"
echo "  $COMPOSE up -d"

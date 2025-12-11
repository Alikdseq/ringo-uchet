# 🔧 ИСПРАВЛЕНИЕ: CORS заголовки отсутствуют

## ❌ ПРОБЛЕМА

**API работает, но CORS заголовки НЕ возвращаются!**

Это может быть причиной проблем на некоторых устройствах/браузерах.

---

## ✅ ПРОВЕРКА: Полный вывод команды

**В вашем выводе не видно результата проверки Nginx конфигурации.**

**На сервере выполните:**

```bash
echo "=== Конфигурация Nginx для /api/ ==="
sudo cat /etc/nginx/sites-available/ringo-uchet | grep -A 15 "location /api/"
```

**Пришлите вывод!**

---

## ✅ ПРОВЕРКА 2: CORS заголовки подробно

**На сервере:**

```bash
echo "=== Все заголовки ответа ==="
curl -k -v -H "Origin: https://ringoouchet.ru" https://ringoouchet.ru/api/health/ 2>&1 | grep -E "< HTTP|< access-control|access-control"
```

**Пришлите вывод!**

---

## ✅ ПРОВЕРКА 3: CORS настройки Django

**На сервере:**

```bash
cd /root/ringo-uchet/backend
echo "=== CORS переменные в контейнере ==="
docker compose -f docker-compose.prod.yml exec api env | grep -E "CORS" | sort
```

**Пришлите вывод!**

---

## 🔧 РЕШЕНИЕ: Если CORS не работает

### Вариант 1: Добавить CORS заголовки в Nginx

**Если Django не возвращает CORS, добавим в Nginx:**

```bash
sudo nano /etc/nginx/sites-available/ringo-uchet
```

**Найдите блок `location /api/` и добавьте:**

```nginx
location /api/ {
    proxy_pass http://127.0.0.1:8001;
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
    
    # CORS заголовки (если Django не возвращает)
    add_header Access-Control-Allow-Origin "$http_origin" always;
    add_header Access-Control-Allow-Methods "GET, POST, PUT, DELETE, OPTIONS" always;
    add_header Access-Control-Allow-Headers "Authorization, Content-Type, X-CSRFToken" always;
    add_header Access-Control-Allow-Credentials "true" always;
    
    # Для OPTIONS запросов
    if ($request_method = OPTIONS) {
        add_header Access-Control-Allow-Origin "$http_origin" always;
        add_header Access-Control-Allow-Methods "GET, POST, PUT, DELETE, OPTIONS" always;
        add_header Access-Control-Allow-Headers "Authorization, Content-Type, X-CSRFToken" always;
        add_header Access-Control-Allow-Credentials "true" always;
        add_header Access-Control-Max-Age "3600" always;
        return 204;
    }
}
```

**После изменений:**

```bash
sudo nginx -t
sudo systemctl reload nginx
```

---

### Вариант 2: Исправить CORS в Django

**Проверим что CORS настроен правильно:**

```bash
cd /root/ringo-uchet/backend

# Проверить что corsheaders установлен
docker compose -f docker-compose.prod.yml exec api pip list | grep cors

# Проверить настройки
docker compose -f docker-compose.prod.yml exec api python -c "
import os
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'ringo_backend.settings.prod')
import django
django.setup()
from django.conf import settings
print('CORS_ALLOWED_ORIGINS:', getattr(settings, 'CORS_ALLOWED_ORIGINS', 'NOT SET'))
print('CORS_ALLOW_ALL_ORIGINS:', getattr(settings, 'CORS_ALLOW_ALL_ORIGINS', 'NOT SET'))
print('CORS middleware:', 'corsheaders.middleware.CorsMiddleware' in settings.MIDDLEWARE)
"
```

---

**Выполните проверки 1-3 и пришлите результаты!**


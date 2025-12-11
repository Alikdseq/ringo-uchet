# 🔍 ПОЛНАЯ ПРОВЕРКА: Django логин не работает на телефоне

## 🎯 ЦЕЛЬ

**Проверить ВСЕ настройки Django для логина!**

---

## ✅ ШАГ 1: Проверить все настройки Django в контейнере

**На сервере:**

```bash
cd /root/ringo-uchet/backend

echo "=== 1. Все переменные окружения Django ==="
docker compose -f docker-compose.prod.yml exec api env | grep -E "DJANGO|CORS|ALLOWED|CSRF" | sort

echo -e "\n=== 2. Проверка настроек Django ==="
docker compose -f docker-compose.prod.yml exec api python -c "
import os
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'ringo_backend.settings.prod')
import django
django.setup()
from django.conf import settings

print('ALLOWED_HOSTS:', settings.ALLOWED_HOSTS)
print('CSRF_TRUSTED_ORIGINS:', settings.CSRF_TRUSTED_ORIGINS)
print('CORS_ALLOWED_ORIGINS:', getattr(settings, 'CORS_ALLOWED_ORIGINS', 'NOT SET'))
print('CORS_ALLOW_ALL_ORIGINS:', getattr(settings, 'CORS_ALLOW_ALL_ORIGINS', 'NOT SET'))
print('CORS middleware есть:', 'corsheaders.middleware.CorsMiddleware' in settings.MIDDLEWARE)
print('CORS middleware позиция:', settings.MIDDLEWARE.index('corsheaders.middleware.CorsMiddleware') if 'corsheaders.middleware.CorsMiddleware' in settings.MIDDLEWARE else 'NOT FOUND')
print('SECURE_SSL_REDIRECT:', getattr(settings, 'SECURE_SSL_REDIRECT', 'NOT SET'))
print('SECURE_PROXY_SSL_HEADER:', getattr(settings, 'SECURE_PROXY_SSL_HEADER', 'NOT SET'))
"

echo -e "\n=== 3. Тест логин эндпоинта напрямую ==="
curl -k -X POST https://ringoouchet.ru/api/v1/auth/login/ \
  -H "Content-Type: application/json" \
  -H "Origin: https://ringoouchet.ru" \
  -d '{"phone":"test","password":"test"}' \
  -v 2>&1 | grep -E "< HTTP|status|error|Invalid|success"
```

**Пришлите ВСЕ результаты!**

---

## ✅ ШАГ 2: Включить подробные логи Django

**На сервере:**

```bash
cd /root/ringo-uchet/backend

# Временно изменить уровень логирования
docker compose -f docker-compose.prod.yml exec api python -c "
import os
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'ringo_backend.settings.prod')
import django
django.setup()
from django.conf import settings

# Временно включить DEBUG для логов
settings.DEBUG = True
settings.LOGGING['root']['level'] = 'DEBUG'
"

echo "Логи включены - теперь попробуйте войти на телефоне"
```

---

## ✅ ШАГ 3: Смотреть логи в реальном времени

**На сервере (в одном терминале):**

```bash
cd /root/ringo-uchet/backend
docker compose -f docker-compose.prod.yml logs api -f --tail=100
```

**На телефоне попробуйте войти!**

**Ищите в логах:**
- Ошибки CORS
- Ошибки CSRF
- Ошибки ALLOWED_HOSTS
- Ошибки логина
- Stack traces

**Пришлите логи!**

---

## ✅ ШАГ 4: Тест логина с curl

**На сервере:**

```bash
echo "=== Тест логин через curl ==="
curl -k -X POST https://ringoouchet.ru/api/v1/auth/login/ \
  -H "Content-Type: application/json" \
  -H "Origin: https://ringoouchet.ru" \
  -d '{"phone":"ваш_телефон","password":"ваш_пароль"}' \
  -v 2>&1 | tee /tmp/login_test.log

echo -e "\n=== Результат ==="
cat /tmp/login_test.log | grep -E "< HTTP|< access-control|error|Invalid|success|token" | head -20
```

**Пришлите результат!**

---

## 🔧 РЕШЕНИЕ: Исправить CORS если нужно

**Если CORS не работает, временно разрешим все:**

```bash
cd /root/ringo-uchet/backend

# Обновить docker-compose.prod.yml
sed -i 's/- CORS_ALLOWED_ORIGINS=.*/- CORS_ALLOW_ALL_ORIGINS=true/' docker-compose.prod.yml

# Перезапустить
docker compose -f docker-compose.prod.yml up -d api

# Проверить
docker compose -f docker-compose.prod.yml exec api env | grep CORS
```

---

**Выполните ШАГИ 1-4 и пришлите результаты!**


# 🔍 ПОЛНАЯ ДИАГНОСТИКА: Логин не работает

## ✅ ЧТО ИЗВЕСТНО

1. **API работает** - тест `/api/health/` успешен
2. **Flutter использует правильный эндпоинт** - `/token/` ✅
3. **Проблема в самом процессе логина** ❌

---

## ✅ ШАГ 1: Проверить все настройки Django

**На сервере:**

```bash
cd /root/ringo-uchet/backend

echo "=== 1. Все Django переменные ==="
docker compose -f docker-compose.prod.yml exec api env | grep -E "DJANGO|CORS|ALLOWED|CSRF" | sort

echo -e "\n=== 2. Проверка настроек Django ==="
docker compose -f docker-compose.prod.yml exec api python << 'PYTHON'
import os
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'ringo_backend.settings.prod')
import django
django.setup()
from django.conf import settings

print('ALLOWED_HOSTS:', settings.ALLOWED_HOSTS)
print('CSRF_TRUSTED_ORIGINS:', settings.CSRF_TRUSTED_ORIGINS)
print('CORS_ALLOWED_ORIGINS:', getattr(settings, 'CORS_ALLOWED_ORIGINS', 'NOT SET'))
print('CORS_ALLOW_ALL_ORIGINS:', getattr(settings, 'CORS_ALLOW_ALL_ORIGINS', 'NOT SET'))
print('CORS middleware:', 'corsheaders.middleware.CorsMiddleware' in settings.MIDDLEWARE)
print('MIDDLEWARE порядок:', [m for m in settings.MIDDLEWARE if 'cors' in m.lower() or 'csrf' in m.lower()])
PYTHON
```

**Пришлите ВСЕ результаты!**

---

## ✅ ШАГ 2: Тест логина через curl

**На сервере (ЗАМЕНИТЕ на реальный телефон и пароль!):**

```bash
echo "=== Тест логин через curl ==="
curl -k -X POST https://ringoouchet.ru/api/v1/token/ \
  -H "Content-Type: application/json" \
  -H "Origin: https://ringoouchet.ru" \
  -d '{"phone":"79991234567","password":"admin123"}' \
  -v 2>&1 | tee /tmp/login_curl.log

echo -e "\n=== Результат ==="
cat /tmp/login_curl.log | grep -E "< HTTP|status|error|Invalid|token|access|refresh" | head -20
```

**Пришлите результат!**

---

## ✅ ШАГ 3: Включить подробные логи Django

**На сервере:**

```bash
cd /root/ringo-uchet/backend

# Создать скрипт для включения логов
cat > /tmp/enable_logs.py << 'PYTHON'
import os
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'ringo_backend.settings.prod')
import django
django.setup()
from django.conf import settings

# Временно включить DEBUG
settings.DEBUG = True
settings.LOGGING['root']['level'] = 'DEBUG'
settings.LOGGING['loggers']['django.request']['level'] = 'DEBUG'
settings.LOGGING['loggers']['ringo_backend']['level'] = 'DEBUG'

print("✅ Логи включены")
PYTHON

# Запустить скрипт
docker compose -f docker-compose.prod.yml exec api python /tmp/enable_logs.py
```

---

## ✅ ШАГ 4: Смотреть логи в реальном времени

**На сервере (в одном терминале, оставьте открытым!):**

```bash
cd /root/ringo-uchet/backend
docker compose -f docker-compose.prod.yml logs api -f --tail=0
```

**На телефоне попробуйте войти!**

**Ищите в логах:**
- Запросы к `/api/v1/token/`
- Ошибки CORS
- Ошибки CSRF  
- Ошибки валидации
- Stack traces
- "Invalid phone/password"
- Любые ошибки!

**Пришлите логи!**

---

## ✅ ШАГ 5: Проверить что Flutter использует правильный baseUrl

**Проверьте что в собранном Flutter Web используется правильный URL:**

**На сервере:**

```bash
echo "=== Проверка Flutter конфигурации ==="
grep -r "ringoouchet.ru\|localhost:8001" /var/www/ringo-uchet/*.js 2>/dev/null | head -5

echo -e "\n=== Проверка main.dart.js ==="
grep -o "https://[^\"']*\|http://[^\"']*" /var/www/ringo-uchet/main.dart.js | sort -u | head -10
```

**Пришлите вывод!**

---

## 🔧 ВРЕМЕННОЕ РЕШЕНИЕ: Включить CORS_ALLOW_ALL_ORIGINS

**Если проблема в CORS, временно разрешим все:**

```bash
cd /root/ringo-uchet/backend

# Обновить docker-compose.prod.yml
sed -i 's/- CORS_ALLOWED_ORIGINS=.*/- CORS_ALLOW_ALL_ORIGINS=true/' docker-compose.prod.yml

# Перезапустить API
docker compose -f docker-compose.prod.yml up -d api

# Проверить
docker compose -f docker-compose.prod.yml exec api env | grep CORS
```

---

**Выполните ВСЕ ШАГИ и пришлите результаты!**


# Исправление CORS ошибок

## Проблема
CORS ошибка при запросах с Flutter web приложения на Django backend:
```
Access to XMLHttpRequest at 'http://localhost:8001/api/v1/token/' from origin 'http://localhost:54342' 
has been blocked by CORS policy
```

## Решение
Обновлены настройки CORS в `backend/ringo_backend/settings/local.py` для разрешения всех localhost портов через регулярные выражения.

## Что было исправлено

1. **Добавлены регулярные выражения для localhost портов**:
   - `http://localhost:\d+` - любой порт на localhost
   - `http://127.0.0.1:\d+` - любой порт на 127.0.0.1
   - `http://[::1]:\d+` - IPv6 localhost

2. **Разрешены все необходимые заголовки и методы**:
   - Authorization, Content-Type, Origin и др.
   - GET, POST, PUT, PATCH, DELETE, OPTIONS

## Перезапуск сервера

После изменений нужно перезапустить Django сервер:

```bash
# Остановить контейнеры
docker compose down

# Запустить заново
docker compose up -d

# Или перезапустить только django-api
docker compose restart django-api
```

## Проверка

После перезапуска проверьте логи:
```bash
docker compose logs django-api
```

Должны увидеть, что сервер запустился без ошибок.

## Альтернативное решение (если не помогло)

Если регулярные выражения не работают, можно временно разрешить все origins для разработки:

В `backend/ringo_backend/settings/local.py` добавьте:
```python
CORS_ALLOW_ALL_ORIGINS = True
```

**ВНИМАНИЕ**: Это только для разработки! Никогда не используйте в production!


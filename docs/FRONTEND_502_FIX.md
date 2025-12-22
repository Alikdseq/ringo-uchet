# Исправление ошибки 502 Bad Gateway для Next.js Frontend

## Проблема

Service Worker получал ошибки 502 при попытке загрузить ресурсы, потому что:
1. Nginx проксировал все запросы на Django API вместо Next.js
2. Service Worker имел дублированный код и неправильную обработку ошибок
3. Next.js не был настроен в Docker Compose

## Решение

### 1. Исправлен Service Worker (`frontend/public/webpush-sw.js`)

- Убраны дубликаты кода
- Улучшена обработка ошибок 502/503
- Правильная стратегия retry с fallback на кэш
- Корректная обработка навигационных запросов

### 2. Обновлена конфигурация Nginx (`infra/nginx/default.conf`)

Теперь nginx правильно маршрутизирует запросы:
- `/api/` → Django API (порт 8000)
- `/admin/` → Django Admin
- `/static/`, `/media/` → Django статика
- Все остальное → Next.js (порт 3000)
- `/_next/static/` → Next.js статика
- `/webpush-sw.js`, `/manifest.json` → Next.js

### 3. Добавлен Next.js в Docker Compose

- Создан Dockerfile для Next.js
- Добавлен сервис `frontend` в docker-compose.yml
- Настроен standalone режим для оптимизации

### 4. Исправлен HTTP Client (`frontend/src/shared/api/httpClient.ts`)

- Использует относительные пути `/api/v1` в браузере (работает через nginx)
- Поддерживает переменную окружения `NEXT_PUBLIC_API_BASE_URL` для кастомизации

## Деплой

### Локальная разработка

```bash
# Запуск всех сервисов
docker-compose up -d

# Или только фронтенд для разработки
cd frontend
npm install
npm run dev
```

### Production

```bash
# Пересборка и запуск
docker-compose down
docker-compose build --no-cache frontend
docker-compose up -d

# Проверка логов
docker-compose logs -f frontend nginx
```

## Проверка

1. Откройте `http://localhost` (или ваш домен)
2. Проверьте консоль браузера - не должно быть ошибок 502
3. Service Worker должен зарегистрироваться без ошибок
4. API запросы должны работать через `/api/v1/`

## Переменные окружения

Для фронтенда можно настроить:

```env
NEXT_PUBLIC_API_BASE_URL=/api/v1  # Относительный путь (рекомендуется)
# или
NEXT_PUBLIC_API_BASE_URL=https://ringoouchet.ru/api/v1  # Полный URL
```

## Troubleshooting

### Если все еще получаете 502:

1. Проверьте, что Next.js сервис запущен:
   ```bash
   docker-compose ps frontend
   docker-compose logs frontend
   ```

2. Проверьте nginx конфигурацию:
   ```bash
   docker-compose exec nginx nginx -t
   ```

3. Очистите кэш браузера и Service Worker:
   - Откройте DevTools → Application → Service Workers → Unregister
   - Очистите кэш браузера

4. Пересоберите контейнеры:
   ```bash
   docker-compose down -v
   docker-compose build --no-cache
   docker-compose up -d
   ```

### Если Service Worker не регистрируется:

1. Проверьте, что файл `webpush-sw.js` доступен по `/webpush-sw.js`
2. Проверьте консоль браузера на ошибки
3. Убедитесь, что используется HTTPS или localhost (Service Workers требуют secure context)

## Архитектура

```
Browser
  ↓
Nginx (порт 80)
  ├─ /api/* → Django API (порт 8000)
  ├─ /admin/* → Django Admin
  ├─ /static/*, /media/* → Django статика
  └─ /* → Next.js Frontend (порт 3000)
```


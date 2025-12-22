# Исправление ошибки 502 Bad Gateway

## Проблема
Ошибка 502 означает, что nginx не может достучаться до бэкенда Django.

## Возможные причины и решения

### 1. Проверка статуса сервисов

```bash
# Проверить статус всех контейнеров
docker-compose -f docker-compose.prod.yml ps

# Проверить логи бэкенда
docker-compose -f docker-compose.prod.yml logs api --tail=50

# Проверить логи nginx
docker-compose -f docker-compose.prod.yml logs nginx --tail=50
```

### 2. Проверка имени сервиса в nginx

В `infra/nginx/nginx-ssl.conf` используется имя `django-api`, но в `docker-compose.prod.yml` сервис называется `api`.

**Решение:** Обновить nginx конфигурацию:

```bash
# Заменить все вхождения django-api на api в nginx конфигурации
sed -i 's/django-api/api/g' infra/nginx/nginx-ssl.conf
```

Или вручную заменить в файле `infra/nginx/nginx-ssl.conf`:
- `proxy_pass http://django-api:8000;` → `proxy_pass http://api:8000;`

### 3. Проверка здоровья бэкенда

```bash
# Проверить, отвечает ли бэкенд напрямую
curl http://localhost:8001/api/health/

# Или изнутри Docker сети
docker-compose -f docker-compose.prod.yml exec api curl http://localhost:8000/api/health/
```

### 4. Перезапуск сервисов

```bash
# Остановить все сервисы
docker-compose -f docker-compose.prod.yml down

# Запустить заново
docker-compose -f docker-compose.prod.yml up -d

# Проверить статус
docker-compose -f docker-compose.prod.yml ps
```

### 5. Проверка сетевых подключений

```bash
# Проверить, что nginx может достучаться до api
docker-compose -f docker-compose.prod.yml exec nginx ping api

# Проверить порт 8000 внутри контейнера api
docker-compose -f docker-compose.prod.yml exec api netstat -tlnp | grep 8000
```

### 6. Проверка переменных окружения

Убедитесь, что файл `.env` существует и содержит все необходимые переменные:

```bash
# Проверить наличие .env файла
ls -la backend/.env

# Проверить ключевые переменные
grep -E "DJANGO_SECRET_KEY|POSTGRES|ALLOWED_HOSTS" backend/.env
```

### 7. Проверка миграций БД

```bash
# Проверить статус миграций
docker-compose -f docker-compose.prod.yml exec api python manage.py showmigrations

# Применить миграции если нужно
docker-compose -f docker-compose.prod.yml exec api python manage.py migrate
```

### 8. Быстрое исправление (если проблема в имени сервиса)

```bash
cd /path/to/ringo-uchet

# Обновить nginx конфигурацию
sed -i 's/django-api/api/g' infra/nginx/nginx-ssl.conf

# Перезапустить nginx
docker-compose -f backend/docker-compose.prod.yml restart nginx

# Или перезапустить все
docker-compose -f backend/docker-compose.prod.yml restart
```

## Диагностика на продакшене

Если сайт на сервере `ringoouchet.ru`:

```bash
# SSH подключение к серверу
ssh user@ringoouchet.ru

# Перейти в директорию проекта
cd /path/to/ringo-uchet

# Проверить статус
docker-compose -f backend/docker-compose.prod.yml ps

# Проверить логи
docker-compose -f backend/docker-compose.prod.yml logs api --tail=100
docker-compose -f backend/docker-compose.prod.yml logs nginx --tail=100

# Проверить конфигурацию nginx на сервере
cat /etc/nginx/sites-enabled/ringoouchet.ru  # или путь к конфигу

# Перезапустить nginx на сервере (если используется системный nginx)
sudo systemctl restart nginx
sudo systemctl status nginx
```

## Частые проблемы

1. **Бэкенд не запущен** - запустить `docker-compose up -d api`
2. **Неправильное имя сервиса** - исправить в nginx конфигурации
3. **Проблемы с сетью Docker** - пересоздать сеть: `docker network prune`
4. **Бэкенд упал из-за ошибки** - проверить логи и исправить ошибку
5. **Проблемы с БД** - проверить подключение к PostgreSQL


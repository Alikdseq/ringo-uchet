# 🚨 Быстрое исправление ошибки 502

## Проблема
Ошибка 502 Bad Gateway означает, что nginx не может достучаться до бэкенда Django.

## ⚡ Быстрое решение (выполнить на сервере)

### Шаг 1: Подключиться к серверу
```bash
ssh root@91.229.90.72
# или
ssh user@ringoouchet.ru
```

### Шаг 2: Проверить статус контейнеров
```bash
cd ~/ringo-uchet/backend
docker compose -f docker-compose.prod.yml ps
```

**Если контейнер `api` не запущен или упал:**
```bash
# Перезапустить все сервисы
docker compose -f docker-compose.prod.yml restart

# Или перезапустить только API
docker compose -f docker-compose.prod.yml restart api
```

### Шаг 3: Проверить логи API
```bash
docker compose -f docker-compose.prod.yml logs api --tail=50
```

**Если видите ошибки подключения к БД или другие ошибки - исправьте их.**

### Шаг 4: Проверить, что API отвечает
```bash
# Проверить health endpoint
curl http://localhost:8001/api/health/

# Должен вернуть: {"status": "ok"} или {"status": "healthy"}
```

### Шаг 5: Если используется системный nginx (не из Docker)

Проверьте конфигурацию nginx на сервере:
```bash
# Найти конфигурацию nginx
sudo nginx -t

# Проверить конфигурацию для домена
cat /etc/nginx/sites-enabled/ringoouchet.ru
# или
cat /etc/nginx/conf.d/ringoouchet.ru.conf
```

**Убедитесь, что в конфигурации указан правильный адрес бэкенда:**
- Если бэкенд в Docker: `proxy_pass http://localhost:8001;` или `proxy_pass http://127.0.0.1:8001;`
- Если бэкенд на другом сервере: `proxy_pass http://IP_АДРЕС:8000;`

**Если нужно исправить конфигурацию:**
```bash
# Отредактировать конфигурацию
sudo nano /etc/nginx/sites-enabled/ringoouchet.ru

# Проверить синтаксис
sudo nginx -t

# Перезапустить nginx
sudo systemctl restart nginx
sudo systemctl status nginx
```

### Шаг 6: Если используется nginx из Docker

Проверьте, что конфигурация nginx обновлена:
```bash
cd ~/ringo-uchet

# Обновить код (если еще не обновлен)
git pull origin master

# Проверить конфигурацию nginx
cat infra/nginx/default.conf | grep proxy_pass
cat infra/nginx/nginx-ssl.conf | grep proxy_pass

# Должно быть: proxy_pass http://api:8000;
# Если видите django-api - нужно обновить
```

**Если нужно обновить конфигурацию:**
```bash
# Обновить код
git pull origin master

# Перезапустить nginx контейнер
docker compose -f backend/docker-compose.prod.yml restart nginx
```

## 🔍 Диагностика

### Проверить все сервисы
```bash
cd ~/ringo-uchet/backend

# Статус всех контейнеров
docker compose -f docker-compose.prod.yml ps

# Логи всех сервисов
docker compose -f docker-compose.prod.yml logs --tail=30

# Проверить здоровье БД
docker compose -f docker-compose.prod.yml exec db pg_isready -U ringo_user

# Проверить здоровье Redis
docker compose -f docker-compose.prod.yml exec redis redis-cli ping
```

### Проверить сеть Docker
```bash
# Проверить, что nginx может достучаться до api
docker compose -f docker-compose.prod.yml exec nginx ping -c 2 api

# Проверить порт 8000 в контейнере api
docker compose -f docker-compose.prod.yml exec api netstat -tlnp | grep 8000
```

## ⚠️ Частые причины 502:

1. **Бэкенд не запущен** → `docker compose -f docker-compose.prod.yml up -d api`
2. **Бэкенд упал из-за ошибки** → Проверить логи и исправить ошибку
3. **Неправильное имя сервиса в nginx** → Исправить `django-api` → `api`
4. **Проблемы с БД** → Проверить подключение к PostgreSQL
5. **Проблемы с сетью Docker** → Пересоздать сеть: `docker network prune`

## 🆘 Если ничего не помогает

```bash
# Полный перезапуск всех сервисов
cd ~/ringo-uchet/backend
docker compose -f docker-compose.prod.yml down
docker compose -f docker-compose.prod.yml up -d

# Подождать 30 секунд
sleep 30

# Проверить статус
docker compose -f docker-compose.prod.yml ps

# Проверить health
curl http://localhost:8001/api/health/
```


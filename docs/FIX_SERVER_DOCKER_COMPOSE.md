# 🔧 ИСПРАВЛЕНИЕ DOCKER-COMPOSE НА СЕРВЕРЕ

## 🔴 ПРОБЛЕМА

**Ошибка:** `Error response from daemon: error from registry: invalid repository name`

**Причина:** На сервере старая версия `docker-compose.prod.yml` которая использует несуществующий образ `ghcr.io/ringo-backend:latest` вместо локальной сборки.

**Результат:** Контейнеры `api`, `celery-worker`, `celery-beat` не запускаются.

---

## ✅ РЕШЕНИЕ

### ШАГ 1: Скопировать исправленный файл на сервер

**На вашем компьютере (PowerShell):**

```powershell
scp C:\ringo-uchet\backend\docker-compose.prod.yml root@91.229.90.72:~/ringo-uchet/backend/docker-compose.prod.yml
```

Введите пароль от сервера.

---

### ШАГ 2: Подключиться к серверу

**На вашем компьютере (PowerShell):**

```powershell
ssh root@91.229.90.72
```

---

### ШАГ 3: Проверить что файл обновлен

**На сервере:**

```bash
cd ~/ringo-uchet/backend

# Проверить что файл обновлен (не должно быть строки version:)
head -5 docker-compose.prod.yml

# Должно быть:
# services:
#   db:
#     image: postgres:15-alpine
#     restart: unless-stopped

# Проверить что используется build вместо image
grep -A 3 "api:" docker-compose.prod.yml | head -5

# Должно быть:
#   api:
#     build:
#       context: .
#       dockerfile: Dockerfile
```

---

### ШАГ 4: Остановить все контейнеры

**На сервере:**

```bash
cd ~/ringo-uchet/backend

# Остановить все контейнеры
docker compose -f docker-compose.prod.yml down

# Проверить что все остановлено
docker compose -f docker-compose.prod.yml ps
```

---

### ШАГ 5: Собрать образы

**На сервере:**

```bash
cd ~/ringo-uchet/backend

# Собрать образы
docker compose -f docker-compose.prod.yml build --no-cache

# Это займет 3-5 минут, подождите завершения
```

---

### ШАГ 6: Запустить контейнеры

**На сервере:**

```bash
cd ~/ringo-uchet/backend

# Запустить все сервисы
docker compose -f docker-compose.prod.yml up -d

# Подождать 15 секунд для запуска
sleep 15

# Проверить статус
docker compose -f docker-compose.prod.yml ps
```

**Должны быть запущены:**
- `backend-db-1` - Up (healthy)
- `backend-redis-1` - Up (healthy)
- `backend-minio-1` - Up (healthy)
- `backend-api-1` - Up
- `backend-celery-worker-1` - Up
- `backend-celery-beat-1` - Up

---

### ШАГ 7: Проверить логи API

**На сервере:**

```bash
cd ~/ringo-uchet/backend

# Проверить логи API
docker compose -f docker-compose.prod.yml logs api --tail 50
```

**Должно быть:**
- Нет критических ошибок
- Видны строки "Starting gunicorn"
- Видны строки "Booting worker"

---

### ШАГ 8: Проверить что API работает

**На сервере:**

```bash
# Проверить health endpoint
curl http://localhost:8001/api/health/

# Должен вернуть: {"status": "ok"}
```

---

### ШАГ 9: Применить миграции (если нужно)

**На сервере:**

```bash
cd ~/ringo-uchet/backend

# Проверить статус миграций
docker compose -f docker-compose.prod.yml exec api python manage.py showmigrations

# Применить миграции (если есть непримененные)
docker compose -f docker-compose.prod.yml exec api python manage.py migrate

# Собрать статические файлы
docker compose -f docker-compose.prod.yml exec api python manage.py collectstatic --noinput
```

---

### ШАГ 10: Перезагрузить Nginx

**На сервере:**

```bash
# Проверить конфигурацию Nginx
sudo nginx -t

# Если все ОК, перезагрузить
sudo systemctl reload nginx

# Очистить кэш
sudo rm -rf /var/cache/nginx/*
```

---

## 🚀 БЫСТРАЯ КОМАНДА (ВСЕ СРАЗУ)

**На сервере выполните все команды подряд:**

```bash
cd ~/ringo-uchet/backend && \
docker compose -f docker-compose.prod.yml down && \
docker compose -f docker-compose.prod.yml build --no-cache && \
docker compose -f docker-compose.prod.yml up -d && \
sleep 20 && \
docker compose -f docker-compose.prod.yml ps && \
curl http://localhost:8001/api/health/ && \
docker compose -f docker-compose.prod.yml exec api python manage.py migrate && \
sudo systemctl reload nginx && \
echo "✅ Все готово!"
```

---

## ✅ ПРОВЕРКА ПОСЛЕ ИСПРАВЛЕНИЯ

**На сервере:**

```bash
# 1. Проверить что все контейнеры запущены
cd ~/ringo-uchet/backend
docker compose -f docker-compose.prod.yml ps

# Должны быть все 6 контейнеров: db, redis, minio, api, celery-worker, celery-beat

# 2. Проверить что API работает локально
curl http://localhost:8001/api/health/

# Должен вернуть: {"status": "ok"}

# 3. Проверить что API работает через Nginx
curl https://ringoouchet.ru/api/health/

# Должен вернуть: {"status": "ok"}

# 4. Проверить логи если что-то не так
docker compose -f docker-compose.prod.yml logs api --tail 30
```

**На вашем компьютере:**

1. Откройте `https://ringoouchet.ru`
2. Откройте DevTools (F12)
3. Проверьте что запросы к `/api/v1/orders/` возвращают 200 OK вместо 502

---

## 🔍 ЕСЛИ ЧТО-ТО НЕ РАБОТАЕТ

### Проблема: Файл не скопировался

**Решение:**
```powershell
# На вашем компьютере
scp C:\ringo-uchet\backend\docker-compose.prod.yml root@91.229.90.72:~/ringo-uchet/backend/docker-compose.prod.yml
```

### Проблема: Образы не собираются

**Решение:**
```bash
# На сервере
cd ~/ringo-uchet/backend

# Проверить что Dockerfile существует
ls -la Dockerfile

# Проверить что requirements.txt существует
ls -la requirements.txt

# Попробовать собрать вручную
docker build -t backend-api:latest .
```

### Проблема: Контейнеры не запускаются

**Решение:**
```bash
# На сервере
cd ~/ringo-uchet/backend

# Проверить логи
docker compose -f docker-compose.prod.yml logs

# Проверить переменные окружения
cat .env | grep -E "DB_|CELERY_|DJANGO_"
```

---

**Начните с ШАГА 1 - скопируйте исправленный файл на сервер!** 🚀


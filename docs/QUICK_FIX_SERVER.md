# 🚀 БЫСТРОЕ ИСПРАВЛЕНИЕ НА СЕРВЕРЕ

## Проблема
- API контейнер не запущен (`service "api" is not running`)
- Старая версия `docker-compose.prod.yml` на сервере (есть предупреждение о `version`)

## Решение

### Шаг 1: Обновить код на сервере

```bash
# На сервере
cd ~/ringo-uchet/backend

# Проверить текущий статус
git status

# Обновить код из репозитория
git pull origin master

# Если есть конфликты, разрешить их:
# git checkout --theirs docker-compose.prod.yml
# git add docker-compose.prod.yml
# git commit -m "Update docker-compose.prod.yml"

# Проверить что файл обновлен (не должно быть строки version:)
head -5 docker-compose.prod.yml
```

### Шаг 2: Проверить статус контейнеров

```bash
# На сервере
cd ~/ringo-uchet/backend

# Проверить какие контейнеры запущены
docker compose -f docker-compose.prod.yml ps

# Проверить все контейнеры (включая остановленные)
docker compose -f docker-compose.prod.yml ps -a
```

### Шаг 3: Остановить старые контейнеры

```bash
# На сервере
cd ~/ringo-uchet/backend

# Остановить все контейнеры
docker compose -f docker-compose.prod.yml down

# Убедиться что все остановлено
docker compose -f docker-compose.prod.yml ps
```

### Шаг 4: Собрать образы (если нужно)

```bash
# На сервере
cd ~/ringo-uchet/backend

# Собрать образы (если используете build вместо image)
docker compose -f docker-compose.prod.yml build --no-cache

# Или если образы уже собраны, просто запустить
```

### Шаг 5: Запустить контейнеры

```bash
# На сервере
cd ~/ringo-uchet/backend

# Запустить все сервисы
docker compose -f docker-compose.prod.yml up -d

# Проверить статус
docker compose -f docker-compose.prod.yml ps

# Должны быть запущены:
# - db (healthy)
# - redis (healthy)
# - minio (healthy)
# - api (running)
# - celery-worker (running)
# - celery-beat (running)
```

### Шаг 6: Проверить логи

```bash
# На сервере
cd ~/ringo-uchet/backend

# Проверить логи API
docker compose -f docker-compose.prod.yml logs api --tail 50

# Проверить логи всех сервисов
docker compose -f docker-compose.prod.yml logs --tail 50

# Если есть ошибки, проверить конкретный сервис
docker compose -f docker-compose.prod.yml logs db --tail 20
docker compose -f docker-compose.prod.yml logs redis --tail 20
```

### Шаг 7: Применить миграции (если нужно)

```bash
# На сервере
cd ~/ringo-uchet/backend

# Проверить статус миграций
docker compose -f docker-compose.prod.yml exec api python manage.py showmigrations

# Применить миграции (если есть непримененные)
docker compose -f docker-compose.prod.yml exec api python manage.py migrate

# Собрать статические файлы
docker compose -f docker-compose.prod.yml exec api python manage.py collectstatic --noinput
```

### Шаг 8: Проверить работу API

```bash
# На сервере
cd ~/ringo-uchet/backend

# Проверить health endpoint
curl http://localhost:8001/api/health/

# Должен вернуть: {"status": "ok"}

# Проверить что API доступен
curl -I http://localhost:8001/api/v1/orders/
```

## Если что-то пошло не так

### Проблема: Контейнеры не запускаются

```bash
# Проверить логи ошибок
docker compose -f docker-compose.prod.yml logs

# Проверить переменные окружения
cat .env | grep -E "DB_|CELERY_|DJANGO_"

# Убедиться что .env файл существует и содержит все переменные
```

### Проблема: БД не подключается

```bash
# Проверить что БД запущена
docker compose -f docker-compose.prod.yml ps db

# Проверить логи БД
docker compose -f docker-compose.prod.yml logs db --tail 50

# Проверить подключение к БД
docker compose -f docker-compose.prod.yml exec db psql -U ringo_user -d ringo_prod -c "SELECT version();"
```

### Проблема: Образы не собираются

```bash
# Проверить Dockerfile
cat Dockerfile

# Попробовать собрать вручную
docker build -t backend-api:latest .

# Проверить что файлы на месте
ls -la Dockerfile requirements.txt
```

### Проблема: Порты заняты

```bash
# Проверить какие порты заняты
netstat -tulpn | grep -E "8001|5432|6379|9000"

# Если порт 8001 занят, можно изменить в docker-compose.prod.yml
# Или остановить процесс, занимающий порт
```

## Быстрая команда (все сразу)

```bash
# На сервере
cd ~/ringo-uchet/backend && \
git pull origin master && \
docker compose -f docker-compose.prod.yml down && \
docker compose -f docker-compose.prod.yml build --no-cache && \
docker compose -f docker-compose.prod.yml up -d && \
sleep 10 && \
docker compose -f docker-compose.prod.yml ps && \
docker compose -f docker-compose.prod.yml exec api python manage.py migrate && \
curl http://localhost:8001/api/health/
```

---

**После выполнения всех шагов:**
- ✅ Контейнеры должны быть запущены
- ✅ API должен отвечать на запросы
- ✅ Предупреждение о `version` должно исчезнуть


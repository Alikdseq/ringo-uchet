# 🚀 Команды для деплоя бэкенда НА СЕРВЕРЕ

## ⚠️ ВАЖНО
Эти команды нужно выполнять **НА СЕРВЕРЕ** (через SSH), а не на вашем локальном компьютере!

---

## 📋 Полная последовательность деплоя на сервере

### ШАГ 1: Подключиться к серверу

**На вашем компьютере (PowerShell):**
```powershell
ssh root@91.229.90.72
```

Введите пароль от сервера.

---

### ШАГ 2: Перейти в директорию бэкенда

**На сервере:**
```bash
cd ~/ringo-uchet/backend
```

---

### ШАГ 3: Обновить код из репозитория

**На сервере:**
```bash
# Обновить код
git pull origin master

# Проверить что код обновлен
git log --oneline -3
```

---

### ШАГ 4: Создать резервную копию БД

**На сервере:**
```bash
# Создать резервную копию БД
docker compose -f docker-compose.prod.yml exec -T db pg_dump -U ringo_user ringo_prod > /root/backup-$(date +%Y%m%d-%H%M%S).sql

# Проверить что бэкап создан
ls -lh /root/backup-*.sql | tail -1
```

---

### ШАГ 5: Остановить все контейнеры

**На сервере:**
```bash
docker compose -f docker-compose.prod.yml down
```

---

### ШАГ 6: Собрать новые образы

**На сервере:**
```bash
docker compose -f docker-compose.prod.yml build --no-cache
```

Это займет 5-10 минут в зависимости от изменений.

---

### ШАГ 7: Запустить контейнеры

**На сервере:**
```bash
# Запустить все сервисы
docker compose -f docker-compose.prod.yml up -d

# Подождать запуска (20 секунд)
sleep 20

# Проверить статус
docker compose -f docker-compose.prod.yml ps
```

**Должны быть запущены все 6 контейнеров:**
- `backend-db-1` - Up (healthy)
- `backend-redis-1` - Up (healthy)
- `backend-minio-1` - Up (healthy)
- `backend-api-1` - Up
- `backend-celery-worker-1` - Up
- `backend-celery-beat-1` - Up

---

### ШАГ 8: Применить миграции

**На сервере:**
```bash
# Применить миграции БД
docker compose -f docker-compose.prod.yml exec api python manage.py migrate --noinput

# Собрать статические файлы
docker compose -f docker-compose.prod.yml exec api python manage.py collectstatic --noinput --clear
```

---

### ШАГ 9: Проверить что API работает

**На сервере:**
```bash
# Проверить health endpoint
curl http://localhost:8001/api/health/

# Должен вернуть: {"status": "ok"} или {"status": "healthy"}

# Проверить логи если нужно
docker compose -f docker-compose.prod.yml logs api --tail 30
```

---

### ШАГ 10: Выйти из SSH

**На сервере:**
```bash
exit
```

---

## ⚡ Все команды одной строкой (для копирования на сервере)

```bash
cd ~/ringo-uchet/backend && git pull origin master && docker compose -f docker-compose.prod.yml exec -T db pg_dump -U ringo_user ringo_prod > /root/backup-$(date +%Y%m%d-%H%M%S).sql && docker compose -f docker-compose.prod.yml down && docker compose -f docker-compose.prod.yml build --no-cache && docker compose -f docker-compose.prod.yml up -d && sleep 20 && docker compose -f docker-compose.prod.yml exec api python manage.py migrate --noinput && docker compose -f docker-compose.prod.yml exec api python manage.py collectstatic --noinput --clear && curl http://localhost:8001/api/health/ && docker compose -f docker-compose.prod.yml ps
```

---

## 🔍 Полезные команды для проверки

### Проверить статус контейнеров
```bash
docker compose -f docker-compose.prod.yml ps
```

### Посмотреть логи
```bash
# Логи API
docker compose -f docker-compose.prod.yml logs api --tail 50

# Логи Celery Worker
docker compose -f docker-compose.prod.yml logs celery-worker --tail 50

# Все логи
docker compose -f docker-compose.prod.yml logs --tail 50
```

### Перезапустить сервисы
```bash
docker compose -f docker-compose.prod.yml restart api celery-worker celery-beat
```

### Проверить здоровье
```bash
# API
curl http://localhost:8001/api/health/

# БД
docker compose -f docker-compose.prod.yml exec db pg_isready -U ringo_user

# Redis
docker compose -f docker-compose.prod.yml exec redis redis-cli ping

# Celery
docker compose -f docker-compose.prod.yml exec celery-worker celery -A ringo_backend inspect ping
```

---

## ⚠️ Что делать, если что-то пошло не так

### Откат к предыдущей версии
```bash
cd ~/ringo-uchet/backend

# Откатить код
git reset --hard HEAD~1
git pull origin master --force

# Пересобрать и запустить
docker compose -f docker-compose.prod.yml down
docker compose -f docker-compose.prod.yml build --no-cache
docker compose -f docker-compose.prod.yml up -d
```

### Восстановить БД из бэкапа
```bash
# Найти последний бэкап
ls -lt /root/backup-*.sql | head -1

# Восстановить (замените YYYYMMDD-HHMMSS на реальную дату)
cat /root/backup-YYYYMMDD-HHMMSS.sql | docker compose -f docker-compose.prod.yml exec -T db psql -U ringo_user ringo_prod
```


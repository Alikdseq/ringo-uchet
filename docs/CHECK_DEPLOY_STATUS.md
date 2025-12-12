# ✅ ПРОВЕРКА СТАТУСА ДЕПЛОЯ БЭКЕНДА

## 🔍 Чеклист для проверки

Выполните эти команды на сервере, чтобы убедиться что бэкенд полностью задеплоен:

```bash
cd ~/ringo-uchet/backend

# 1. Проверить что код обновлен (должен быть последний коммит с исправлениями)
git log --oneline -5

# 2. Проверить статус всех контейнеров
docker compose -f docker-compose.prod.yml ps

# Должны быть запущены все 6 контейнеров:
# - backend-db-1 (Up, healthy)
# - backend-redis-1 (Up, healthy)  
# - backend-minio-1 (Up, healthy)
# - backend-api-1 (Up)
# - backend-celery-worker-1 (Up)
# - backend-celery-beat-1 (Up)

# 3. Проверить что API работает
curl http://localhost:8001/api/health/

# Должен вернуть: {"status": "ok"} или {"status": "healthy"}

# 4. Проверить логи API (должно быть без критических ошибок)
docker compose -f docker-compose.prod.yml logs api --tail 20

# 5. Проверить что миграции применены
docker compose -f docker-compose.prod.yml exec api python manage.py showmigrations orders

# Все миграции должны быть отмечены [X]
```

## ⚠️ Если код НЕ обновлен

Если в `git log` нет последних изменений (исправления отчетов, услуг и т.д.), нужно:

```bash
cd ~/ringo-uchet/backend

# 1. Обновить код
git pull origin master

# 2. Пересобрать контейнеры с новым кодом
docker compose -f docker-compose.prod.yml down
docker compose -f docker-compose.prod.yml build --no-cache
docker compose -f docker-compose.prod.yml up -d

# 3. Подождать запуска
sleep 20

# 4. Применить миграции (если еще не применены)
docker compose -f docker-compose.prod.yml exec api python manage.py migrate

# 5. Собрать статические файлы
docker compose -f docker-compose.prod.yml exec api python manage.py collectstatic --noinput

# 6. Проверить работу
curl http://localhost:8001/api/health/
docker compose -f docker-compose.prod.yml ps
```

## ✅ Если все проверки пройдены

Бэкенд задеплоен и готов к работе! 🎉


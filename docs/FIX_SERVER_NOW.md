# 🔧 НЕМЕДЛЕННОЕ ИСПРАВЛЕНИЕ НА СЕРВЕРЕ

## Текущая ситуация
- На сервере есть 2 локальных коммита, которые не запушены
- Исправленный `docker-compose.prod.yml` находится на вашем компьютере
- Нужно применить исправления на сервере

## Вариант 1: Применить исправления напрямую на сервере (БЫСТРЕЕ)

### Шаг 1: Подключиться к серверу
```bash
ssh root@91.229.90.72
```

### Шаг 2: Отредактировать docker-compose.prod.yml на сервере

```bash
cd ~/ringo-uchet/backend

# Создать резервную копию
cp docker-compose.prod.yml docker-compose.prod.yml.backup

# Отредактировать файл (удалить version и добавить недостающие сервисы)
nano docker-compose.prod.yml
```

**Или использовать готовый исправленный файл:**

```bash
cd ~/ringo-uchet/backend

# Создать резервную копию
cp docker-compose.prod.yml docker-compose.prod.yml.backup

# Скопировать исправленный файл с вашего компьютера через scp
# (выполнить на вашем компьютере):
# scp C:\ringo-uchet\backend\docker-compose.prod.yml root@91.229.90.72:~/ringo-uchet/backend/docker-compose.prod.yml
```

### Шаг 3: Проверить что файл исправлен

```bash
# На сервере
cd ~/ringo-uchet/backend

# Проверить что нет строки version:
head -5 docker-compose.prod.yml
# Должно начинаться с "services:" а не "version:"

# Проверить что есть сервисы db, redis, minio
grep -E "^  (db|redis|minio|api):" docker-compose.prod.yml
```

### Шаг 4: Остановить и пересобрать контейнеры

```bash
# На сервере
cd ~/ringo-uchet/backend

# Остановить все контейнеры
docker compose -f docker-compose.prod.yml down

# Проверить что все остановлено
docker compose -f docker-compose.prod.yml ps

# Собрать образы
docker compose -f docker-compose.prod.yml build --no-cache

# Запустить контейнеры
docker compose -f docker-compose.prod.yml up -d

# Подождать 10 секунд для запуска
sleep 10

# Проверить статус
docker compose -f docker-compose.prod.yml ps
```

### Шаг 5: Проверить логи и работу

```bash
# На сервере
cd ~/ringo-uchet/backend

# Проверить логи API
docker compose -f docker-compose.prod.yml logs api --tail 50

# Проверить health endpoint
curl http://localhost:8001/api/health/

# Применить миграции (если нужно)
docker compose -f docker-compose.prod.yml exec api python manage.py migrate
```

---

## Вариант 2: Запушить изменения в репозиторий (ПРАВИЛЬНЕЕ)

### На вашем компьютере:

```powershell
cd C:\ringo-uchet\backend

# Проверить статус
git status

# Добавить исправленный файл
git add docker-compose.prod.yml

# Закоммитить
git commit -m "Fix docker-compose.prod.yml: add missing services, use build instead of image"

# Запушить в репозиторий
git push origin master
```

**Если push не работает из-за токена:**
1. Создать Personal Access Token на GitHub
2. Использовать токен вместо пароля при push

### На сервере:

```bash
cd ~/ringo-uchet/backend

# Обновить код
git pull origin master

# Если есть конфликты с локальными коммитами:
# Вариант A: Сохранить локальные изменения
git stash
git pull origin master
git stash pop

# Вариант B: Перезаписать локальные изменения (ОСТОРОЖНО!)
git fetch origin
git reset --hard origin/master

# Затем выполнить шаги 4-5 из Варианта 1
```

---

## Быстрая команда (Вариант 1 - прямое исправление)

```bash
# На сервере - выполнить все сразу
cd ~/ringo-uchet/backend && \
cp docker-compose.prod.yml docker-compose.prod.yml.backup && \
# (Здесь нужно отредактировать файл или скопировать с компьютера) && \
docker compose -f docker-compose.prod.yml down && \
docker compose -f docker-compose.prod.yml build --no-cache && \
docker compose -f docker-compose.prod.yml up -d && \
sleep 15 && \
docker compose -f docker-compose.prod.yml ps && \
docker compose -f docker-compose.prod.yml logs api --tail 30 && \
curl http://localhost:8001/api/health/
```

---

## Проверка что все работает

После выполнения команд проверьте:

```bash
# 1. Нет предупреждения о version
docker compose -f docker-compose.prod.yml ps
# (не должно быть WARN про version)

# 2. Все контейнеры запущены
docker compose -f docker-compose.prod.yml ps
# Должны быть: db, redis, minio, api, celery-worker, celery-beat

# 3. API отвечает
curl http://localhost:8001/api/health/
# Должен вернуть: {"status": "ok"}

# 4. Нет ошибок в логах
docker compose -f docker-compose.prod.yml logs api --tail 20
# Не должно быть критических ошибок
```

---

## Если что-то пошло не так

### Откат к резервной копии:

```bash
cd ~/ringo-uchet/backend
cp docker-compose.prod.yml.backup docker-compose.prod.yml
docker compose -f docker-compose.prod.yml up -d
```

### Проверка проблем:

```bash
# Проверить логи всех сервисов
docker compose -f docker-compose.prod.yml logs

# Проверить конкретный сервис
docker compose -f docker-compose.prod.yml logs db
docker compose -f docker-compose.prod.yml logs api

# Проверить переменные окружения
cat .env | grep -E "DB_|CELERY_|DJANGO_"
```

---

**Рекомендация:** Используйте Вариант 1 для быстрого исправления, затем Вариант 2 для синхронизации с репозиторием.


# 🚀 Профессиональные команды для деплоя бэкенда

## 📋 Быстрый старт

### Linux/macOS:
```bash
cd backend
chmod +x deploy.sh
./deploy.sh prod
```

### Windows (PowerShell):
```powershell
cd backend
.\deploy.ps1 -Environment prod
```

---

## 🔧 Подготовка к деплою

### 1. Проверка окружения

```bash
# Проверка Docker
docker --version
docker-compose --version

# Проверка Git
git status
git log -1

# Проверка файла .env
ls -la backend/.env
```

### 2. Настройка переменных окружения

Создайте файл `backend/.env` с необходимыми переменными:

```bash
# База данных
POSTGRES_DB=ringo_prod
POSTGRES_USER=ringo_user
POSTGRES_PASSWORD=your_secure_password
DB_PASSWORD=your_secure_password

# Django
DJANGO_SECRET_KEY=your_secret_key_here
DJANGO_ALLOWED_HOSTS=your-domain.com,www.your-domain.com
CSRF_TRUSTED_ORIGINS=https://your-domain.com,https://www.your-domain.com

# Celery
CELERY_BROKER_URL=redis://redis:6379/0
CELERY_RESULT_BACKEND=redis://redis:6379/0

# MinIO/S3
MINIO_ROOT_USER=minioadmin
MINIO_ROOT_PASSWORD=your_minio_password
AWS_ACCESS_KEY_ID=your_access_key
AWS_SECRET_ACCESS_KEY=your_secret_key
AWS_BUCKET=ringo-media
AWS_S3_ENDPOINT_URL=http://minio:9000
```

---

## 🚀 Полный деплой (автоматический)

### Linux/macOS:
```bash
cd backend
./deploy.sh prod
```

### Windows:
```powershell
cd backend
.\deploy.ps1 -Environment prod
```

**Что делает скрипт:**
1. ✅ Проверяет зависимости
2. ✅ Создает бэкап БД
3. ✅ Обновляет код из Git
4. ✅ Останавливает сервисы
5. ✅ Собирает Docker образы
6. ✅ Запускает сервисы
7. ✅ Выполняет миграции
8. ✅ Собирает статические файлы
9. ✅ Проверяет здоровье сервисов

---

## 📝 Ручной деплой (пошагово)

### Шаг 1: Создание бэкапа БД

**Linux/macOS:**
```bash
cd backend
mkdir -p backups
docker-compose -f docker-compose.prod.yml exec db pg_dump -U ringo_user ringo_prod > backups/db_backup_$(date +%Y%m%d_%H%M%S).sql
```

**Windows PowerShell:**
```powershell
cd backend
New-Item -ItemType Directory -Force -Path backups | Out-Null
$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
docker-compose -f docker-compose.prod.yml exec -T db pg_dump -U ringo_user ringo_prod | Out-File -FilePath "backups/db_backup_$timestamp.sql" -Encoding UTF8
```

### Шаг 2: Обновление кода
```bash
cd backend
git fetch origin
git pull origin master
```

### Шаг 3: Остановка сервисов
```bash
cd backend
docker-compose -f docker-compose.prod.yml down
```

### Шаг 4: Сборка образов
```bash
cd backend
docker-compose -f docker-compose.prod.yml build --no-cache
```

### Шаг 5: Запуск зависимостей
```bash
cd backend
docker-compose -f docker-compose.prod.yml up -d db redis minio

# Ожидание готовности БД
sleep 10
docker-compose -f docker-compose.prod.yml exec db pg_isready -U ringo_user
```

### Шаг 6: Запуск API
```bash
cd backend
docker-compose -f docker-compose.prod.yml up -d api
```

### Шаг 7: Выполнение миграций
```bash
cd backend
docker-compose -f docker-compose.prod.yml exec api python manage.py migrate --noinput
```

### Шаг 8: Сборка статических файлов
```bash
cd backend
docker-compose -f docker-compose.prod.yml exec api python manage.py collectstatic --noinput --clear
```

### Шаг 9: Запуск Celery
```bash
cd backend
docker-compose -f docker-compose.prod.yml up -d celery-worker celery-beat
```

### Шаг 10: Проверка здоровья
```bash
curl http://localhost:8001/api/health/
```

---

## 🔍 Проверка статуса

### Проверка контейнеров
```bash
docker-compose -f docker-compose.prod.yml ps
```

### Проверка логов
```bash
# Логи API
docker-compose -f docker-compose.prod.yml logs -f api

# Логи Celery Worker
docker-compose -f docker-compose.prod.yml logs -f celery-worker

# Логи Celery Beat
docker-compose -f docker-compose.prod.yml logs -f celery-beat

# Все логи
docker-compose -f docker-compose.prod.yml logs -f
```

### Проверка здоровья
```bash
# API Health Check
curl http://localhost:8001/api/health/

# Проверка БД
docker-compose -f docker-compose.prod.yml exec db pg_isready -U ringo_user

# Проверка Redis
docker-compose -f docker-compose.prod.yml exec redis redis-cli ping

# Проверка Celery
docker-compose -f docker-compose.prod.yml exec celery-worker celery -A ringo_backend inspect ping
```

---

## 🔄 Откат (Rollback)

### Автоматический откат
Скрипт автоматически выполнит откат при ошибках.

### Ручной откат
```bash
cd backend

# 1. Остановка сервисов
docker-compose -f docker-compose.prod.yml down

# 2. Восстановление БД из бэкапа
gunzip -c backups/db_backup_YYYYMMDD_HHMMSS.sql.gz | \
  docker-compose -f docker-compose.prod.yml exec -T db psql -U ringo_user ringo_prod

# 3. Запуск предыдущей версии
docker-compose -f docker-compose.prod.yml up -d
```

---

## 🧹 Очистка

### Удаление неиспользуемых образов
```bash
docker image prune -a -f --filter "until=168h"
```

### Удаление старых бэкапов (старше 30 дней)
```bash
find backend/backups -name "db_backup_*.sql.gz" -mtime +30 -delete
```

### Полная очистка Docker
```bash
docker system prune -a -f --volumes
```

---

## 🐛 Решение проблем

### Проблема: Контейнер не запускается
```bash
# Проверка логов
docker-compose -f docker-compose.prod.yml logs api

# Проверка конфигурации
docker-compose -f docker-compose.prod.yml config

# Пересборка образа
docker-compose -f docker-compose.prod.yml build --no-cache api
```

### Проблема: Миграции не выполняются
```bash
# Проверка подключения к БД
docker-compose -f docker-compose.prod.yml exec api python manage.py dbshell

# Ручной запуск миграций
docker-compose -f docker-compose.prod.yml exec api python manage.py migrate --verbosity 2
```

### Проблема: Celery не работает
```bash
# Проверка статуса
docker-compose -f docker-compose.prod.yml exec celery-worker celery -A ringo_backend inspect active

# Перезапуск
docker-compose -f docker-compose.prod.yml restart celery-worker celery-beat
```

---

## 📊 Мониторинг

### Проверка использования ресурсов
```bash
docker stats
```

### Проверка метрик Prometheus
```bash
curl http://localhost:8001/metrics
```

### Проверка количества запросов
```bash
docker-compose -f docker-compose.prod.yml logs api | grep "GET\|POST\|PATCH\|DELETE" | wc -l
```

---

## 🔐 Безопасность

### Обновление секретов
```bash
# Генерация нового SECRET_KEY
python -c "from django.core.management.utils import get_random_secret_key; print(get_random_secret_key())"

# Обновление в .env
# Перезапуск сервисов
docker-compose -f docker-compose.prod.yml restart api celery-worker celery-beat
```

### Ротация паролей БД
```bash
# 1. Обновить пароль в .env
# 2. Обновить пароль в PostgreSQL
docker-compose -f docker-compose.prod.yml exec db psql -U ringo_user -d ringo_prod -c "ALTER USER ringo_user WITH PASSWORD 'new_password';"
# 3. Перезапустить сервисы
docker-compose -f docker-compose.prod.yml restart
```

---

## ✅ Чеклист перед деплоем

- [ ] Все изменения закоммичены в Git
- [ ] Файл `.env` настроен и проверен
- [ ] Бэкап БД создан
- [ ] Тесты пройдены (если есть)
- [ ] Миграции проверены локально
- [ ] Docker образы собираются без ошибок
- [ ] Достаточно места на диске
- [ ] Порт 8001 свободен

---

## 📞 Поддержка

При возникновении проблем:
1. Проверьте логи: `docker-compose -f docker-compose.prod.yml logs`
2. Проверьте статус: `docker-compose -f docker-compose.prod.yml ps`
3. Проверьте здоровье: `curl http://localhost:8001/api/health/`
4. Выполните откат при необходимости


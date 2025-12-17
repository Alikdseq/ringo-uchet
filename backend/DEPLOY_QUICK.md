# ⚡ Быстрые команды для деплоя бэкенда

## 🚀 Автоматический деплой (рекомендуется)

### Linux/macOS:
```bash
cd backend
chmod +x deploy.sh
./deploy.sh prod
```

### Windows PowerShell:
```powershell
cd backend
.\deploy.ps1 -Environment prod
```

---

## 📝 Ручной деплой (пошагово)

### 1. Подготовка
```bash
cd backend
git pull origin master
```

### 2. Бэкап БД

**Linux/macOS:**
```bash
docker-compose -f docker-compose.prod.yml exec db pg_dump -U ringo_user ringo_prod > backups/db_backup_$(date +%Y%m%d_%H%M%S).sql
```

**Windows PowerShell:**
```powershell
New-Item -ItemType Directory -Force -Path backups | Out-Null
$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
docker-compose -f docker-compose.prod.yml exec -T db pg_dump -U ringo_user ringo_prod | Out-File -FilePath "backups/db_backup_$timestamp.sql" -Encoding UTF8
```

### 3. Остановка
```bash
docker-compose -f docker-compose.prod.yml down
```

### 4. Сборка
```bash
docker-compose -f docker-compose.prod.yml build --no-cache
```

### 5. Запуск
```bash
# Зависимости
docker-compose -f docker-compose.prod.yml up -d db redis minio
sleep 10

# API
docker-compose -f docker-compose.prod.yml up -d api

# Миграции
docker-compose -f docker-compose.prod.yml exec api python manage.py migrate --noinput

# Статика
docker-compose -f docker-compose.prod.yml exec api python manage.py collectstatic --noinput --clear

# Celery
docker-compose -f docker-compose.prod.yml up -d celery-worker celery-beat
```

### 6. Проверка
```bash
curl http://localhost:8001/api/health/
docker-compose -f docker-compose.prod.yml ps
docker-compose -f docker-compose.prod.yml logs -f api
```

---

## 🔍 Полезные команды

### Статус
```bash
docker-compose -f docker-compose.prod.yml ps
docker-compose -f docker-compose.prod.yml logs -f
```

### Перезапуск
```bash
docker-compose -f docker-compose.prod.yml restart api celery-worker celery-beat
```

### Очистка
```bash
docker system prune -a -f
```

---

**Полная документация:** `DEPLOY_COMMANDS.md`


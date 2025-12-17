# 🚀 Команды деплоя для Windows PowerShell

## ⚡ Быстрый деплой

### Автоматический (рекомендуется):
```powershell
cd backend
.\deploy.ps1 -Environment prod
```

---

## 📝 Ручной деплой (пошагово)

### 1. Подготовка
```powershell
cd backend
git pull origin master
```

### 2. Создание директории для бэкапов
```powershell
New-Item -ItemType Directory -Force -Path backups | Out-Null
```

### 3. Бэкап БД
```powershell
$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
docker-compose -f docker-compose.prod.yml exec -T db pg_dump -U ringo_user ringo_prod | Out-File -FilePath "backups/db_backup_$timestamp.sql" -Encoding UTF8
```

### 4. Остановка сервисов
```powershell
docker-compose -f docker-compose.prod.yml down
```

### 5. Сборка образов
```powershell
docker-compose -f docker-compose.prod.yml build --no-cache
```

### 6. Запуск зависимостей
```powershell
docker-compose -f docker-compose.prod.yml up -d db redis minio
Start-Sleep -Seconds 10
```

### 7. Проверка готовности БД
```powershell
docker-compose -f docker-compose.prod.yml exec db pg_isready -U ringo_user
```

### 8. Запуск API
```powershell
docker-compose -f docker-compose.prod.yml up -d api
```

### 9. Выполнение миграций
```powershell
docker-compose -f docker-compose.prod.yml exec api python manage.py migrate --noinput
```

### 10. Сборка статических файлов
```powershell
docker-compose -f docker-compose.prod.yml exec api python manage.py collectstatic --noinput --clear
```

### 11. Запуск Celery
```powershell
docker-compose -f docker-compose.prod.yml up -d celery-worker celery-beat
```

### 12. Проверка здоровья
```powershell
Invoke-WebRequest -Uri "http://localhost:8001/api/health/" -UseBasicParsing
docker-compose -f docker-compose.prod.yml ps
```

---

## 🔍 Полезные команды

### Статус сервисов
```powershell
docker-compose -f docker-compose.prod.yml ps
```

### Логи API
```powershell
docker-compose -f docker-compose.prod.yml logs -f api
```

### Логи Celery Worker
```powershell
docker-compose -f docker-compose.prod.yml logs -f celery-worker
```

### Все логи
```powershell
docker-compose -f docker-compose.prod.yml logs -f
```

### Перезапуск сервисов
```powershell
docker-compose -f docker-compose.prod.yml restart api celery-worker celery-beat
```

### Проверка здоровья API
```powershell
Invoke-WebRequest -Uri "http://localhost:8001/api/health/" -UseBasicParsing
```

### Проверка БД
```powershell
docker-compose -f docker-compose.prod.yml exec db pg_isready -U ringo_user
```

### Проверка Redis
```powershell
docker-compose -f docker-compose.prod.yml exec redis redis-cli ping
```

### Проверка Celery
```powershell
docker-compose -f docker-compose.prod.yml exec celery-worker celery -A ringo_backend inspect ping
```

---

## 🔄 Откат (Rollback)

### Остановка сервисов
```powershell
docker-compose -f docker-compose.prod.yml down
```

### Восстановление БД из бэкапа
```powershell
$latestBackup = Get-ChildItem -Path backups -Filter "db_backup_*.sql" | Sort-Object LastWriteTime -Descending | Select-Object -First 1
Get-Content $latestBackup.FullName | docker-compose -f docker-compose.prod.yml exec -T db psql -U ringo_user ringo_prod
```

---

## 🧹 Очистка

### Удаление неиспользуемых образов
```powershell
docker image prune -a -f --filter "until=168h"
```

### Удаление старых бэкапов (старше 30 дней)
```powershell
Get-ChildItem -Path backups -Filter "db_backup_*.sql" | Where-Object { $_.LastWriteTime -lt (Get-Date).AddDays(-30) } | Remove-Item -Force
```

### Полная очистка Docker
```powershell
docker system prune -a -f --volumes
```

---

## ⚠️ Важные замечания для PowerShell

1. **Перенаправление вывода:** Используйте `| Out-File` вместо `>`
2. **Переменные:** Используйте `$variable` вместо `${variable}`
3. **Дата:** Используйте `Get-Date -Format "yyyyMMdd_HHmmss"` вместо `date +%Y%m%d_%H%M%S`
4. **Создание директорий:** Используйте `New-Item -ItemType Directory -Force`
5. **Флаги Docker:** Используйте `-T` для `exec` чтобы избежать проблем с TTY

---

## ✅ Готовый скрипт для быстрого бэкапа

Создайте файл `backup-db.ps1`:

```powershell
# backup-db.ps1
New-Item -ItemType Directory -Force -Path backups | Out-Null
$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
docker-compose -f docker-compose.prod.yml exec -T db pg_dump -U ringo_user ringo_prod | Out-File -FilePath "backups/db_backup_$timestamp.sql" -Encoding UTF8
Write-Host "Бэкап создан: backups/db_backup_$timestamp.sql" -ForegroundColor Green
```

Использование:
```powershell
.\backup-db.ps1
```


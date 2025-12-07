# Backup & Disaster Recovery для Ringo Uchet

Комплексная система резервного копирования и восстановления.

## Компоненты

### 1. Автоматические бэкапы БД

**Полные бэкапы:**
- Ежедневно в 2:00 UTC
- Хранение: 30 дней локально, 365 дней в S3
- Формат: PostgreSQL dump (сжатый gzip)

**WAL архивирование:**
- Continuous archiving включен
- WAL файлы архивируются автоматически
- Хранение: 7 дней локально, затем в S3

**Тестирование восстановления:**
- Еженедельно в воскресенье в 3:00 UTC
- Автоматическая проверка целостности бэкапов

### 2. Версионирование S3

**Бэкапы:**
- Версионирование включено
- Lifecycle policy:
  - Переход в Glacier через 30 дней
  - Переход в Deep Archive через 90 дней
  - Удаление старых версий через 365 дней

**Медиафайлы:**
- Версионирование включено
- Lifecycle policy:
  - Удаление старых версий через 90 дней
  - Переход в Glacier через 60 дней

### 3. Runbooks

Документация по действиям в аварийных ситуациях:
- Недоступность БД
- Потеря данных
- Недоступность API
- Переполнение диска
- Утечка секретов
- Потеря S3 данных

## Быстрый старт

### Локальный запуск

```bash
cd infra/backup
docker-compose -f docker-compose.backup.yml up -d
```

### Настройка переменных окружения

Создайте `.env` файл:

```env
# Database
DB_HOST=localhost
DB_PORT=5432
DB_NAME=ringo
DB_USER=ringo
DB_PASSWORD=your-password
POSTGRES_USER=postgres
POSTGRES_PASSWORD=postgres-password

# S3 для бэкапов
S3_BACKUP_BUCKET=ringo-backups
S3_ENDPOINT_URL=https://nyc1.digitaloceanspaces.com
S3_REGION=nyc1
AWS_ACCESS_KEY_ID=your-access-key
AWS_SECRET_ACCESS_KEY=your-secret-key

# Retention
RETENTION_DAYS=30
```

### Ручной бэкап

```bash
# Полный бэкап
./scripts/backup-postgres.sh full

# Проверка WAL архивирования
./scripts/backup-postgres.sh wal
```

### Восстановление из бэкапа

```bash
# Восстановить из файла
./scripts/restore-postgres.sh /backups/postgres/postgres_ringo_20240115_020000.sql.gz

# Восстановить из S3
aws s3 cp s3://ringo-backups/postgres/full/ringo_20240115_020000.sql.gz /tmp/restore.sql.gz
./scripts/restore-postgres.sh /tmp/restore.sql.gz
```

### Тестирование восстановления

```bash
# Тест последнего бэкапа
./scripts/test-restore.sh latest

# Тест конкретного файла
./scripts/test-restore.sh /backups/postgres/postgres_ringo_20240115_020000.sql.gz
```

## Terraform конфигурация

### S3 бэкапы

```bash
cd infra/backup/terraform
terraform init
terraform plan
terraform apply
```

Создает:
- S3 bucket для бэкапов с версионированием
- Lifecycle policy для автоматического управления
- IAM policy для доступа

### S3 медиафайлы

Аналогично настраивается bucket для медиафайлов с версионированием.

## Мониторинг

### Проверка статуса бэкапов

```bash
# Проверить последние бэкапы
ls -lth /backups/postgres/postgres_*.sql.gz | head -5

# Проверить логи
tail -f /backups/postgres/backup.log

# Проверить бэкапы в S3
aws s3 ls s3://ringo-backups/postgres/full/ --recursive | tail -10
```

### Алерты

Настроены Prometheus алерты:
- `BackupFailed` - бэкап не выполнен
- `BackupTooOld` - последний бэкап старше 25 часов
- `RestoreTestFailed` - тест восстановления не прошел

## RTO/RPO

- **RTO (Recovery Time Objective)**: 4 часа
- **RPO (Recovery Point Objective)**: 
  - Критические данные: 1 час (через WAL)
  - Обычные данные: 24 часа (через daily backups)

## Troubleshooting

### Бэкап не выполняется

1. Проверьте cron job:
   ```bash
   docker logs backup-cron
   ```

2. Проверьте права доступа:
   ```bash
   ls -la /backups/postgres/
   ```

3. Проверьте подключение к БД:
   ```bash
   psql -h $DB_HOST -U $DB_USER -d $DB_NAME -c "SELECT 1;"
   ```

### Восстановление не работает

1. Проверьте формат файла:
   ```bash
   file /backups/postgres/postgres_ringo_*.sql.gz
   ```

2. Проверьте целостность:
   ```bash
   gunzip -t /backups/postgres/postgres_ringo_*.sql.gz
   ```

3. Запустите тест восстановления:
   ```bash
   ./scripts/test-restore.sh /backups/postgres/postgres_ringo_*.sql.gz
   ```

### S3 версионирование не работает

1. Проверьте настройки bucket:
   ```bash
   aws s3api get-bucket-versioning --bucket ringo-backups
   ```

2. Проверьте lifecycle policy:
   ```bash
   aws s3api get-bucket-lifecycle-configuration --bucket ringo-backups
   ```

## Дополнительные ресурсы

- [Runbooks для аварийных ситуаций](../docs/RUNBOOKS.md)
- [PostgreSQL Backup Documentation](https://www.postgresql.org/docs/current/backup.html)
- [AWS S3 Versioning](https://docs.aws.amazon.com/AmazonS3/latest/userguide/Versioning.html)


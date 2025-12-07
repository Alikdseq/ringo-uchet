#!/bin/bash
# Скрипт для восстановления PostgreSQL базы данных из бэкапа
# Использование: ./restore-postgres.sh <backup_file> [target_db_name]

set -e

BACKUP_FILE=$1
TARGET_DB=${2:-ringo}

if [ -z "$BACKUP_FILE" ]; then
    echo "ERROR: Backup file not specified"
    echo "Usage: $0 <backup_file> [target_db_name]"
    exit 1
fi

if [ ! -f "$BACKUP_FILE" ] && [ ! -f "${BACKUP_FILE}.gz" ]; then
    echo "ERROR: Backup file not found: $BACKUP_FILE"
    exit 1
fi

# Переменные окружения для подключения к БД
DB_HOST=${DB_HOST:-localhost}
DB_PORT=${DB_PORT:-5432}
DB_USER=${DB_USER:-ringo}
DB_PASSWORD=${DB_PASSWORD}
POSTGRES_USER=${POSTGRES_USER:-postgres}
POSTGRES_PASSWORD=${POSTGRES_PASSWORD}

# Функция для логирования
log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1"
}

log "Starting database restoration from: $BACKUP_FILE"
log "Target database: $TARGET_DB"

# Определяем, сжат ли файл
if [ -f "${BACKUP_FILE}.gz" ]; then
    ACTUAL_BACKUP="${BACKUP_FILE}.gz"
    USE_GUNZIP=true
elif [[ "$BACKUP_FILE" == *.gz ]]; then
    ACTUAL_BACKUP="$BACKUP_FILE"
    USE_GUNZIP=true
else
    ACTUAL_BACKUP="$BACKUP_FILE"
    USE_GUNZIP=false
fi

# Подтверждение перед восстановлением
read -p "WARNING: This will DROP and recreate database '$TARGET_DB'. Continue? (yes/no): " CONFIRM
if [ "$CONFIRM" != "yes" ]; then
    log "Restoration cancelled"
    exit 0
fi

log "Terminating active connections to database..."
export PGPASSWORD="${POSTGRES_PASSWORD}"
psql -h "${DB_HOST}" -p "${DB_PORT}" -U "${POSTGRES_USER}" -d postgres \
    -c "SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname = '${TARGET_DB}' AND pid <> pg_backend_pid();" || true

log "Dropping existing database..."
psql -h "${DB_HOST}" -p "${DB_PORT}" -U "${POSTGRES_USER}" -d postgres \
    -c "DROP DATABASE IF EXISTS ${TARGET_DB};" || true

log "Restoring database from backup..."

if [ "$USE_GUNZIP" = true ]; then
    log "Decompressing backup file..."
    export PGPASSWORD="${DB_PASSWORD}"
    gunzip -c "${ACTUAL_BACKUP}" | psql -h "${DB_HOST}" -p "${DB_PORT}" -U "${DB_USER}" -d postgres
else
    export PGPASSWORD="${DB_PASSWORD}"
    psql -h "${DB_HOST}" -p "${DB_PORT}" -U "${DB_USER}" -d postgres < "${ACTUAL_BACKUP}"
fi

log "Running ANALYZE to update statistics..."
export PGPASSWORD="${DB_PASSWORD}"
psql -h "${DB_HOST}" -p "${DB_PORT}" -U "${DB_USER}" -d "${TARGET_DB}" -c "ANALYZE;"

log "Database restoration completed successfully"
log "Database '$TARGET_DB' has been restored from '$BACKUP_FILE'"


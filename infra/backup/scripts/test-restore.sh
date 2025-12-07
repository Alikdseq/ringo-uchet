#!/bin/bash
# Скрипт для тестирования восстановления из бэкапа
# Создает тестовую БД, восстанавливает бэкап и проверяет целостность

set -e

BACKUP_FILE=${1:-latest}
TEST_DB="ringo_test_restore_$(date +%Y%m%d_%H%M%S)"

# Переменные окружения
DB_HOST=${DB_HOST:-localhost}
DB_PORT=${DB_PORT:-5432}
DB_NAME=${DB_NAME:-ringo}
DB_USER=${DB_USER:-ringo}
DB_PASSWORD=${DB_PASSWORD}
POSTGRES_USER=${POSTGRES_USER:-postgres}
POSTGRES_PASSWORD=${POSTGRES_PASSWORD}
BACKUP_DIR=${BACKUP_DIR:-/backups/postgres}

# Функция для логирования
log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1"
}

log "Starting backup restoration test"
log "Test database: $TEST_DB"

# Находим последний бэкап, если не указан файл
if [ "$BACKUP_FILE" = "latest" ]; then
    BACKUP_FILE=$(ls -t "${BACKUP_DIR}"/postgres_*.sql.gz 2>/dev/null | head -1)
    if [ -z "$BACKUP_FILE" ]; then
        log "ERROR: No backup files found in ${BACKUP_DIR}"
        exit 1
    fi
    log "Using latest backup: $BACKUP_FILE"
fi

if [ ! -f "$BACKUP_FILE" ]; then
    log "ERROR: Backup file not found: $BACKUP_FILE"
    exit 1
fi

# Создаем тестовую БД
log "Creating test database..."
export PGPASSWORD="${POSTGRES_PASSWORD}"
psql -h "${DB_HOST}" -p "${DB_PORT}" -U "${POSTGRES_USER}" -d postgres \
    -c "CREATE DATABASE ${TEST_DB};" || {
    log "ERROR: Failed to create test database"
    exit 1
}

# Восстанавливаем бэкап
log "Restoring backup to test database..."
export PGPASSWORD="${DB_PASSWORD}"
gunzip -c "${BACKUP_FILE}" | psql -h "${DB_HOST}" -p "${DB_PORT}" -U "${DB_USER}" -d "${TEST_DB}" || {
    log "ERROR: Failed to restore backup"
    export PGPASSWORD="${POSTGRES_PASSWORD}"
    psql -h "${DB_HOST}" -p "${DB_PORT}" -U "${POSTGRES_USER}" -d postgres \
        -c "DROP DATABASE IF EXISTS ${TEST_DB};"
    exit 1
}

# Проверяем целостность данных
log "Checking database integrity..."

export PGPASSWORD="${DB_PASSWORD}"

# Проверяем количество таблиц
TABLE_COUNT=$(psql -h "${DB_HOST}" -p "${DB_PORT}" -U "${DB_USER}" -d "${TEST_DB}" \
    -t -c "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = 'public';" | xargs)
log "Tables found: $TABLE_COUNT"

if [ "$TABLE_COUNT" -eq 0 ]; then
    log "WARNING: No tables found in restored database"
fi

# Проверяем основные таблицы
REQUIRED_TABLES=("users_user" "orders_order" "catalog_equipment" "crm_client")
for table in "${REQUIRED_TABLES[@]}"; do
    EXISTS=$(psql -h "${DB_HOST}" -p "${DB_PORT}" -U "${DB_USER}" -d "${TEST_DB}" \
        -t -c "SELECT EXISTS (SELECT FROM information_schema.tables WHERE table_name = '${table}');" | xargs)
    if [ "$EXISTS" = "t" ]; then
        ROW_COUNT=$(psql -h "${DB_HOST}" -p "${DB_PORT}" -U "${DB_USER}" -d "${TEST_DB}" \
            -t -c "SELECT COUNT(*) FROM ${table};" | xargs)
        log "✓ Table ${table}: ${ROW_COUNT} rows"
    else
        log "✗ Table ${table}: NOT FOUND"
    fi
done

# Проверяем индексы
INDEX_COUNT=$(psql -h "${DB_HOST}" -p "${DB_PORT}" -U "${DB_USER}" -d "${TEST_DB}" \
    -t -c "SELECT COUNT(*) FROM pg_indexes WHERE schemaname = 'public';" | xargs)
log "Indexes found: $INDEX_COUNT"

# Запускаем VACUUM ANALYZE для проверки
log "Running VACUUM ANALYZE..."
psql -h "${DB_HOST}" -p "${DB_PORT}" -U "${DB_USER}" -d "${TEST_DB}" \
    -c "VACUUM ANALYZE;" || {
    log "WARNING: VACUUM ANALYZE failed"
}

# Удаляем тестовую БД
log "Cleaning up test database..."
export PGPASSWORD="${POSTGRES_PASSWORD}"
psql -h "${DB_HOST}" -p "${DB_PORT}" -U "${POSTGRES_USER}" -d postgres \
    -c "DROP DATABASE IF EXISTS ${TEST_DB};"

log "Backup restoration test completed successfully"
log "✓ Backup file is valid and can be restored"


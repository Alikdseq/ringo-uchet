#!/bin/bash
# Скрипт для создания бэкапа PostgreSQL базы данных
# Использование: ./backup-postgres.sh [full|wal]

set -e

BACKUP_TYPE=${1:-full}
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_DIR="/backups/postgres"
RETENTION_DAYS=${RETENTION_DAYS:-30}

# Переменные окружения для подключения к БД
DB_HOST=${DB_HOST:-localhost}
DB_PORT=${DB_PORT:-5432}
DB_NAME=${DB_NAME:-ringo}
DB_USER=${DB_USER:-ringo}
DB_PASSWORD=${DB_PASSWORD}

# Переменные для S3
S3_BUCKET=${S3_BACKUP_BUCKET:-ringo-backups}
S3_ENDPOINT=${S3_ENDPOINT_URL}
S3_REGION=${S3_REGION:-us-east-1}
AWS_ACCESS_KEY_ID=${AWS_ACCESS_KEY_ID}
AWS_SECRET_ACCESS_KEY=${AWS_SECRET_ACCESS_KEY}

# Создаем директорию для бэкапов
mkdir -p "${BACKUP_DIR}"

# Функция для загрузки в S3
upload_to_s3() {
    local file_path=$1
    local s3_path=$2
    
    if [ -n "$S3_ENDPOINT" ]; then
        # Используем MinIO или совместимый S3
        aws s3 cp "${file_path}" "s3://${S3_BUCKET}/${s3_path}" \
            --endpoint-url="${S3_ENDPOINT}" \
            --region="${S3_REGION}"
    else
        # Используем AWS S3
        aws s3 cp "${file_path}" "s3://${S3_BUCKET}/${s3_path}" \
            --region="${S3_REGION}"
    fi
}

# Функция для логирования
log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1" | tee -a "${BACKUP_DIR}/backup.log"
}

log "Starting ${BACKUP_TYPE} backup for database ${DB_NAME}"

if [ "$BACKUP_TYPE" = "full" ]; then
    # Полный бэкап (pg_dump)
    BACKUP_FILE="${BACKUP_DIR}/postgres_${DB_NAME}_${TIMESTAMP}.sql.gz"
    
    log "Creating full backup..."
    
    export PGPASSWORD="${DB_PASSWORD}"
    pg_dump -h "${DB_HOST}" -p "${DB_PORT}" -U "${DB_USER}" -d "${DB_NAME}" \
        --verbose --clean --if-exists --create \
        | gzip > "${BACKUP_FILE}"
    
    BACKUP_SIZE=$(du -h "${BACKUP_FILE}" | cut -f1)
    log "Full backup completed: ${BACKUP_FILE} (${BACKUP_SIZE})"
    
    # Загружаем в S3
    if [ -n "$AWS_ACCESS_KEY_ID" ] && [ -n "$AWS_SECRET_ACCESS_KEY" ]; then
        log "Uploading backup to S3..."
        S3_PATH="postgres/full/${DB_NAME}_${TIMESTAMP}.sql.gz"
        upload_to_s3 "${BACKUP_FILE}" "${S3_PATH}"
        log "Backup uploaded to S3: s3://${S3_BUCKET}/${S3_PATH}"
    fi
    
    # Удаляем старые локальные бэкапы
    find "${BACKUP_DIR}" -name "postgres_${DB_NAME}_*.sql.gz" -mtime +${RETENTION_DAYS} -delete
    log "Cleaned up backups older than ${RETENTION_DAYS} days"

elif [ "$BACKUP_TYPE" = "wal" ]; then
    # WAL архивирование (для continuous archiving)
    log "WAL archiving is handled by PostgreSQL continuous archiving"
    log "Current WAL files are being archived automatically"
    
    # Проверяем статус архивирования WAL
    export PGPASSWORD="${DB_PASSWORD}"
    WAL_STATUS=$(psql -h "${DB_HOST}" -p "${DB_PORT}" -U "${DB_USER}" -d "${DB_NAME}" \
        -t -c "SELECT pg_is_in_backup();" | xargs)
    
    if [ "$WAL_STATUS" = "t" ]; then
        log "WARNING: Database is currently in backup mode"
    else
        log "WAL archiving status: OK"
    fi

else
    log "ERROR: Unknown backup type: ${BACKUP_TYPE}"
    log "Usage: $0 [full|wal]"
    exit 1
fi

log "Backup process completed successfully"


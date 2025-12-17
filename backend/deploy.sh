#!/bin/bash
# 🚀 Профессиональный скрипт деплоя бэкенда Ringo Uchet
# Использование: ./deploy.sh [environment]
# environment: dev, staging, prod (по умолчанию: prod)

set -euo pipefail  # Строгий режим: остановка при ошибках

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Переменные
ENVIRONMENT="${1:-prod}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_NAME="ringo-backend"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_DIR="${SCRIPT_DIR}/backups"
LOG_FILE="${SCRIPT_DIR}/deploy_${TIMESTAMP}.log"

# Функции логирования
log_info() {
    echo -e "${BLUE}[INFO]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

# Проверка зависимостей
check_dependencies() {
    log_info "Проверка зависимостей..."
    
    local missing_deps=()
    
    command -v docker >/dev/null 2>&1 || missing_deps+=("docker")
    command -v docker-compose >/dev/null 2>&1 || missing_deps+=("docker-compose")
    command -v git >/dev/null 2>&1 || missing_deps+=("git")
    
    if [ ${#missing_deps[@]} -ne 0 ]; then
        log_error "Отсутствуют зависимости: ${missing_deps[*]}"
        exit 1
    fi
    
    log_success "Все зависимости установлены"
}

# Проверка окружения
check_environment() {
    log_info "Проверка окружения: $ENVIRONMENT"
    
    if [ ! -f "${SCRIPT_DIR}/.env" ]; then
        log_error "Файл .env не найден!"
        exit 1
    fi
    
    # Проверка обязательных переменных
    source "${SCRIPT_DIR}/.env"
    
    local required_vars=("DJANGO_SECRET_KEY" "POSTGRES_PASSWORD" "DB_PASSWORD")
    for var in "${required_vars[@]}"; do
        if [ -z "${!var:-}" ]; then
            log_error "Переменная окружения $var не установлена!"
            exit 1
        fi
    done
    
    log_success "Окружение проверено"
}

# Создание бэкапа базы данных
backup_database() {
    log_info "Создание бэкапа базы данных..."
    
    mkdir -p "$BACKUP_DIR"
    
    local backup_file="${BACKUP_DIR}/db_backup_${TIMESTAMP}.sql"
    
    docker-compose -f docker-compose.prod.yml exec -T db pg_dump -U "${POSTGRES_USER:-ringo_user}" "${POSTGRES_DB:-ringo_prod}" > "$backup_file" 2>/dev/null || {
        log_warning "Не удалось создать бэкап БД (возможно, контейнер не запущен)"
        return 0
    }
    
    # Сжатие бэкапа
    gzip -f "$backup_file"
    log_success "Бэкап создан: ${backup_file}.gz"
}

# Остановка сервисов
stop_services() {
    log_info "Остановка сервисов..."
    
    docker-compose -f docker-compose.prod.yml down --timeout 30 || {
        log_warning "Ошибка при остановке сервисов"
    }
    
    log_success "Сервисы остановлены"
}

# Получение последних изменений из Git
pull_latest_changes() {
    log_info "Получение последних изменений из Git..."
    
    cd "$SCRIPT_DIR"
    
    # Проверка статуса Git
    if [ -d ".git" ]; then
        git fetch origin || log_warning "Не удалось получить изменения из Git"
        git pull origin master || log_warning "Не удалось обновить код"
        log_success "Код обновлен"
    else
        log_warning "Не найден репозиторий Git, пропускаем обновление"
    fi
}

# Сборка Docker образов
build_images() {
    log_info "Сборка Docker образов..."
    
    cd "$SCRIPT_DIR"
    
    docker-compose -f docker-compose.prod.yml build --no-cache --parallel || {
        log_error "Ошибка при сборке образов"
        exit 1
    }
    
    log_success "Образы собраны"
}

# Запуск сервисов
start_services() {
    log_info "Запуск сервисов..."
    
    cd "$SCRIPT_DIR"
    
    # Запуск зависимостей (БД, Redis, MinIO)
    docker-compose -f docker-compose.prod.yml up -d db redis minio || {
        log_error "Ошибка при запуске зависимостей"
        exit 1
    }
    
    # Ожидание готовности БД
    log_info "Ожидание готовности базы данных..."
    sleep 10
    
    local max_attempts=30
    local attempt=0
    while [ $attempt -lt $max_attempts ]; do
        if docker-compose -f docker-compose.prod.yml exec -T db pg_isready -U "${POSTGRES_USER:-ringo_user}" >/dev/null 2>&1; then
            log_success "База данных готова"
            break
        fi
        attempt=$((attempt + 1))
        sleep 2
    done
    
    if [ $attempt -eq $max_attempts ]; then
        log_error "База данных не готова после $max_attempts попыток"
        exit 1
    fi
    
    # Запуск API
    docker-compose -f docker-compose.prod.yml up -d api || {
        log_error "Ошибка при запуске API"
        exit 1
    }
    
    # Запуск Celery
    docker-compose -f docker-compose.prod.yml up -d celery-worker celery-beat || {
        log_error "Ошибка при запуске Celery"
        exit 1
    }
    
    log_success "Сервисы запущены"
}

# Выполнение миграций
run_migrations() {
    log_info "Выполнение миграций базы данных..."
    
    cd "$SCRIPT_DIR"
    
    docker-compose -f docker-compose.prod.yml exec -T api python manage.py migrate --noinput || {
        log_error "Ошибка при выполнении миграций"
        exit 1
    }
    
    log_success "Миграции выполнены"
}

# Сборка статических файлов
collect_static() {
    log_info "Сборка статических файлов..."
    
    cd "$SCRIPT_DIR"
    
    docker-compose -f docker-compose.prod.yml exec -T api python manage.py collectstatic --noinput --clear || {
        log_error "Ошибка при сборке статических файлов"
        exit 1
    }
    
    log_success "Статические файлы собраны"
}

# Проверка здоровья сервисов
health_check() {
    log_info "Проверка здоровья сервисов..."
    
    local max_attempts=30
    local attempt=0
    
    while [ $attempt -lt $max_attempts ]; do
        if curl -f -s http://localhost:8001/api/health/ >/dev/null 2>&1; then
            log_success "API здоров"
            return 0
        fi
        attempt=$((attempt + 1))
        sleep 2
    done
    
    log_error "API не отвечает после $max_attempts попыток"
    return 1
}

# Откат к предыдущей версии
rollback() {
    log_error "ОТКАТ: Возврат к предыдущей версии..."
    
    cd "$SCRIPT_DIR"
    
    # Остановка текущих сервисов
    docker-compose -f docker-compose.prod.yml down
    
    # Восстановление из бэкапа (если есть)
    local latest_backup=$(ls -t "${BACKUP_DIR}/db_backup_"*.sql.gz 2>/dev/null | head -1)
    if [ -n "$latest_backup" ]; then
        log_info "Восстановление базы данных из бэкапа..."
        gunzip -c "$latest_backup" | docker-compose -f docker-compose.prod.yml exec -T db psql -U "${POSTGRES_USER:-ringo_user}" "${POSTGRES_DB:-ringo_prod}"
    fi
    
    log_warning "Откат выполнен. Проверьте логи: $LOG_FILE"
}

# Очистка старых образов и контейнеров
cleanup() {
    log_info "Очистка старых образов..."
    
    # Удаление неиспользуемых образов (старше 7 дней)
    docker image prune -a -f --filter "until=168h" || true
    
    # Удаление старых бэкапов (старше 30 дней)
    find "$BACKUP_DIR" -name "db_backup_*.sql.gz" -mtime +30 -delete 2>/dev/null || true
    
    log_success "Очистка завершена"
}

# Главная функция
main() {
    log_info "=========================================="
    log_info "🚀 Начало деплоя бэкенда Ringo Uchet"
    log_info "Окружение: $ENVIRONMENT"
    log_info "Время: $(date)"
    log_info "=========================================="
    
    # Установка обработчика ошибок для отката
    trap 'rollback; exit 1' ERR
    
    # Выполнение шагов деплоя
    check_dependencies
    check_environment
    backup_database
    pull_latest_changes
    stop_services
    build_images
    start_services
    run_migrations
    collect_static
    
    # Проверка здоровья
    if health_check; then
        log_success "=========================================="
        log_success "✅ Деплой успешно завершен!"
        log_success "API доступен: http://localhost:8001/api/health/"
        log_success "Логи: $LOG_FILE"
        log_success "=========================================="
    else
        log_error "Деплой завершился с ошибками"
        rollback
        exit 1
    fi
    
    # Очистка (в фоне)
    cleanup &
    
    # Снятие обработчика ошибок
    trap - ERR
}

# Запуск
main "$@"


# Мониторинг и логирование Ringo Uchet

Комплексная система мониторинга и логирования для проекта.

## Компоненты

### 1. Sentry - Отслеживание ошибок

**Backend:**
- Настроен в `backend/ringo_backend/settings/base.py`
- Переменные окружения:
  - `SENTRY_DSN` - DSN для Sentry проекта
  - `SENTRY_ENVIRONMENT` - Окружение (staging/production)
  - `SENTRY_RELEASE` - Версия релиза (автоматически из CI/CD)
  - `SENTRY_TRACES_SAMPLE_RATE` - Процент трейсов (по умолчанию 0.1)
  - `SENTRY_SEND_DEFAULT_PII` - Отправка PII данных (false по умолчанию)

**Mobile:**
- Настроен через `sentry_flutter` пакет
- См. `mobile/lib/core/config/sentry_config.dart`

**Frontend:**
- Настроен через `@sentry/nextjs`
- См. `frontend/sentry.client.config.ts` и `frontend/sentry.server.config.ts`

### 2. Prometheus - Сбор метрик

**Экспортеры:**
- Django API метрики: `/metrics` endpoint
- Gunicorn метрики: через `gunicorn-prometheus`
- Celery метрики: через signals в `celery_signals.py`
- PostgreSQL метрики: через `postgres_exporter`
- Redis метрики: через `redis_exporter`
- Node метрики: через `node_exporter`

**Конфигурация:**
- `prometheus/prometheus.yml` - основная конфигурация
- `prometheus/alerts/` - правила алертов

### 3. Grafana - Визуализация метрик

**Dashboards:**
- API Metrics (`grafana/dashboards/api-dashboard.json`)
- Celery Metrics (`grafana/dashboards/celery-dashboard.json`)
- Database Metrics (можно добавить)
- System Metrics (можно добавить)

**Доступ:**
- URL: http://localhost:3000
- Логин: admin (по умолчанию)
- Пароль: admin (изменить при первом входе)

### 4. Alertmanager - Управление алертами

**Каналы уведомлений:**
- Slack: через webhook
- Telegram: через бота

**Конфигурация:**
- `alertmanager/alertmanager.yml` - маршрутизация алертов
- Переменные окружения:
  - `SLACK_WEBHOOK_URL` - Slack webhook URL
  - `TELEGRAM_BOT_TOKEN` - Telegram bot token
  - `TELEGRAM_CHAT_ID` - Telegram chat ID

### 5. Vector + OpenSearch - Централизованное логирование

**Vector:**
- Сбор логов из Docker контейнеров
- Обработка и фильтрация PII данных
- Роутинг по уровням логов

**OpenSearch:**
- Хранение логов
- Retention: 90 дней (настраивается через index lifecycle management)
- Поиск и анализ логов

**OpenSearch Dashboards:**
- Визуализация логов
- URL: http://localhost:5601

## Быстрый старт

### Локальный запуск

```bash
cd infra/monitoring
docker-compose -f docker-compose.monitoring.yml up -d
```

### Настройка переменных окружения

Создайте `.env` файл:

```env
# Database для postgres-exporter
DB_HOST=localhost
DB_PORT=5432
DB_NAME=ringo
DB_USER=ringo
DB_PASSWORD=ringo

# Redis для redis-exporter
REDIS_HOST=localhost
REDIS_PORT=6379
REDIS_PASSWORD=

# Grafana
GRAFANA_ADMIN_USER=admin
GRAFANA_ADMIN_PASSWORD=your-secure-password

# Alertmanager
SLACK_WEBHOOK_URL=https://hooks.slack.com/services/YOUR/WEBHOOK/URL
TELEGRAM_BOT_TOKEN=your-telegram-bot-token
TELEGRAM_CHAT_ID=your-telegram-chat-id
```

### Импорт dashboards в Grafana

1. Откройте Grafana: http://localhost:3000
2. Перейдите в Configuration → Data Sources
3. Добавьте Prometheus data source: http://prometheus:9090
4. Перейдите в Dashboards → Import
5. Импортируйте JSON файлы из `grafana/dashboards/`

## Алерты

### Настроенные алерты

**API:**
- Высокая латентность (>200ms)
- Критическая латентность (>1s)
- Высокий процент ошибок (>5%)
- Критический процент ошибок (>10%)
- Недоступность API

**Celery:**
- Высокая глубина очереди (>1000 задач)
- Критическая глубина очереди (>5000 задач)
- Высокий процент неудачных задач (>10%)
- Долгие задачи (>5 минут)
- Отсутствие активных workers

**Database:**
- Высокое количество подключений (>80)
- Критическое количество подключений (>95)
- Медленные запросы (>1s)
- Недоступность БД
- Высокое использование диска (>85%)

**System:**
- Высокое использование CPU (>80%)
- Критическое использование CPU (>95%)
- Высокое использование памяти (>85%)
- Критическое использование памяти (>95%)
- Высокое использование диска (>85%)
- Недоступность сервера

## Retention Policy

**Логи:**
- OpenSearch: 90 дней
- S3 архив: бессрочно (для критических ошибок)

**Метрики:**
- Prometheus: 30 дней
- Долгосрочное хранение: можно настроить через Thanos или VictoriaMetrics

## Интеграция с CI/CD

Release tracking в Sentry автоматически работает через GitHub Actions:

```yaml
- name: Create Sentry Release
  uses: getsentry/action-release@v1
  env:
    SENTRY_AUTH_TOKEN: ${{ secrets.SENTRY_AUTH_TOKEN }}
    SENTRY_ORG: your-org
    SENTRY_PROJECT: ringo-backend
  with:
    environment: ${{ github.ref == 'refs/heads/main' && 'production' || 'staging' }}
    version: ${{ github.sha }}
```

## Troubleshooting

### Prometheus не собирает метрики

1. Проверьте доступность endpoints: `curl http://api:8000/metrics`
2. Проверьте конфигурацию в `prometheus.yml`
3. Проверьте логи Prometheus: `docker logs prometheus`

### Алерты не отправляются

1. Проверьте конфигурацию Alertmanager: `docker logs alertmanager`
2. Проверьте переменные окружения (Slack/Telegram)
3. Проверьте правила алертов в Prometheus

### Логи не попадают в OpenSearch

1. Проверьте статус Vector: `curl http://localhost:8686/health`
2. Проверьте подключение к OpenSearch: `curl http://localhost:9200`
3. Проверьте конфигурацию Vector: `docker logs vector`


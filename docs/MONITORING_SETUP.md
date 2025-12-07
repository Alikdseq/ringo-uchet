# Настройка мониторинга и логирования

Документация по настройке системы мониторинга и логирования для Ringo Uchet.

## Обзор

Реализована комплексная система мониторинга, включающая:

1. **Sentry** - отслеживание ошибок в backend, mobile и frontend
2. **Prometheus** - сбор метрик производительности
3. **Grafana** - визуализация метрик
4. **Alertmanager** - управление алертами
5. **Vector + OpenSearch** - централизованное логирование

## 1. Sentry

### Backend

Настроен в `backend/ringo_backend/settings/base.py`:

```python
SENTRY_DSN = os.environ.get("SENTRY_DSN", "")
SENTRY_ENVIRONMENT = os.environ.get("SENTRY_ENVIRONMENT", "development")
SENTRY_RELEASE = os.environ.get("SENTRY_RELEASE", None)
```

**Переменные окружения:**
- `SENTRY_DSN` - DSN проекта в Sentry
- `SENTRY_ENVIRONMENT` - staging/production
- `SENTRY_RELEASE` - версия релиза (автоматически из CI/CD)

**Интеграции:**
- Django integration
- Celery integration
- Redis integration
- Logging integration

### Mobile

Настроен в `mobile/lib/core/config/sentry_config.dart`:

```dart
await SentryConfig.init();
```

**Переменные окружения (при сборке):**
- `--dart-define=SENTRY_DSN=your-dsn`
- `--dart-define=SENTRY_ENVIRONMENT=production`

**Функции:**
- Автоматическое отслеживание ошибок
- Performance monitoring (10% трейсов)
- Фильтрация чувствительных данных
- Установка пользовательского контекста

### Frontend

Настроен в `frontend/sentry.client.config.ts` и `frontend/sentry.server.config.ts`:

**Переменные окружения:**
- `NEXT_PUBLIC_SENTRY_DSN` - для клиентской части
- `SENTRY_DSN` - для серверной части
- `NEXT_PUBLIC_SENTRY_ENVIRONMENT` - окружение
- `NEXT_PUBLIC_SENTRY_RELEASE` - версия релиза

**Функции:**
- Browser tracing
- Session Replay
- Performance monitoring
- Фильтрация PII данных

### Release Tracking

Автоматический release tracking через GitHub Actions (`.github/workflows/sentry-release.yml`):

- Создает release при каждом push в main/develop
- Привязывает коммиты к release
- Устанавливает окружение (staging/production)

## 2. Prometheus

### Метрики

**HTTP запросы:**
- `http_requests_total` - общее количество запросов
- `http_request_duration_seconds` - длительность запросов
- Endpoint: `/metrics`

**Celery задачи:**
- `celery_tasks_total` - количество задач по статусам
- `celery_task_duration_seconds` - длительность задач
- `celery_queue_length` - глубина очереди

**База данных:**
- `db_connections_active` - активные подключения
- `db_query_duration_seconds` - длительность запросов

**Бизнес-метрики:**
- `orders_created_total` - созданные заявки
- `orders_status_changes_total` - смены статусов
- `invoices_generated_total` - сгенерированные счета

### Экспортеры

- **Django API**: встроенный endpoint `/metrics`
- **Gunicorn**: через `gunicorn-prometheus` (порт 9091)
- **Celery**: через signals в `celery_signals.py`
- **PostgreSQL**: через `postgres_exporter` (порт 9187)
- **Redis**: через `redis_exporter` (порт 9121)
- **Node**: через `node_exporter` (порт 9100)

## 3. Grafana Dashboards

### API Dashboard

Метрики:
- HTTP Request Rate
- API Latency (95th percentile)
- Error Rate
- HTTP Status Codes

### Celery Dashboard

Метрики:
- Queue Depth
- Task Rate
- Task Duration (95th percentile)
- Task Success/Failure Rate

### Импорт dashboards

1. Откройте Grafana: http://localhost:3000
2. Configuration → Data Sources → Add Prometheus
3. URL: http://prometheus:9090
4. Dashboards → Import → загрузите JSON файлы из `infra/monitoring/grafana/dashboards/`

## 4. Alertmanager

### Каналы уведомлений

**Slack:**
- Webhook URL: `SLACK_WEBHOOK_URL`
- Каналы: `#ringo-alerts`, `#ringo-alerts-critical`

**Telegram:**
- Bot Token: `TELEGRAM_BOT_TOKEN`
- Chat ID: `TELEGRAM_CHAT_ID`

### Настроенные алерты

**API:**
- Высокая латентность (>200ms) - warning
- Критическая латентность (>1s) - critical
- Высокий процент ошибок (>5%) - warning
- Критический процент ошибок (>10%) - critical
- Недоступность API - critical

**Celery:**
- Высокая глубина очереди (>1000) - warning
- Критическая глубина очереди (>5000) - critical
- Высокий процент неудачных задач (>10%) - warning
- Долгие задачи (>5 минут) - warning
- Отсутствие активных workers - critical

**Database:**
- Высокое количество подключений (>80) - warning
- Критическое количество подключений (>95) - critical
- Медленные запросы (>1s) - warning
- Недоступность БД - critical

**System:**
- Высокое использование CPU (>80%) - warning
- Критическое использование CPU (>95%) - critical
- Высокое использование памяти (>85%) - warning
- Высокое использование диска (>85%) - warning

## 5. Centralized Logging

### Vector

**Источники:**
- Docker контейнеры (ringo-api, ringo-worker, ringo-celery)
- Системные логи (syslog)

**Обработка:**
- Парсинг JSON логов
- Добавление метаданных
- Фильтрация PII данных (пароли, токены, секреты)
- Роутинг по уровням логов

**Назначения:**
- OpenSearch для долгосрочного хранения
- S3 для архивного хранения (критические ошибки)

### OpenSearch

**Retention Policy:**
- Логи хранятся 90 дней
- Автоматическое удаление через index lifecycle management
- Архивные логи в S3 хранятся бессрочно

**Индексы:**
- Формат: `ringo-logs-YYYY.MM.DD`
- Компрессия: gzip
- Репликация: настраивается через OpenSearch

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

# Sentry (для backend)
SENTRY_DSN=your-sentry-dsn
SENTRY_ENVIRONMENT=staging
```

### Проверка работы

1. **Prometheus**: http://localhost:9090
2. **Grafana**: http://localhost:3000 (admin/admin)
3. **Alertmanager**: http://localhost:9093
4. **OpenSearch**: http://localhost:9200
5. **OpenSearch Dashboards**: http://localhost:5601
6. **Vector API**: http://localhost:8686

## Интеграция с CI/CD

### Sentry Release Tracking

Автоматически создается release при каждом деплое через `.github/workflows/sentry-release.yml`.

### Переменные GitHub Secrets

Добавьте в GitHub Secrets:
- `SENTRY_AUTH_TOKEN` - токен для Sentry API
- `SENTRY_ORG` - организация в Sentry
- `SENTRY_DSN` - DSN для backend
- `NEXT_PUBLIC_SENTRY_DSN` - DSN для frontend
- `SENTRY_DSN_MOBILE` - DSN для mobile (для сборки)

## Troubleshooting

### Prometheus не собирает метрики

1. Проверьте доступность endpoints: `curl http://api:8000/metrics`
2. Проверьте конфигурацию в `prometheus.yml`
3. Проверьте логи: `docker logs prometheus`

### Алерты не отправляются

1. Проверьте конфигурацию Alertmanager: `docker logs alertmanager`
2. Проверьте переменные окружения (Slack/Telegram)
3. Проверьте правила алертов в Prometheus

### Логи не попадают в OpenSearch

1. Проверьте статус Vector: `curl http://localhost:8686/health`
2. Проверьте подключение к OpenSearch: `curl http://localhost:9200`
3. Проверьте конфигурацию Vector: `docker logs vector`

### Sentry не получает ошибки

1. Проверьте DSN в переменных окружения
2. Проверьте release tracking в Sentry UI
3. Проверьте фильтры в `before_send` (могут блокировать события)

## Best Practices

1. **Не отправляйте PII данные** в Sentry/логи
2. **Используйте разные DSN** для staging и production
3. **Настройте retention policy** для логов (90 дней)
4. **Мониторьте алерты** и настраивайте threshold'ы
5. **Регулярно проверяйте dashboards** в Grafana
6. **Тестируйте алерты** перед production

## Дополнительные ресурсы

- [Sentry Documentation](https://docs.sentry.io/)
- [Prometheus Documentation](https://prometheus.io/docs/)
- [Grafana Documentation](https://grafana.com/docs/)
- [Vector Documentation](https://vector.dev/docs/)
- [OpenSearch Documentation](https://opensearch.org/docs/)


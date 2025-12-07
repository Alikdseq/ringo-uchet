# Инфраструктура Ringo Uchet

Документация по инфраструктуре проекта, включая Terraform, CI/CD, и управление секретами.

## Структура инфраструктуры

```
infra/
├── terraform/          # Terraform конфигурация для DigitalOcean/AWS
├── ansible/           # Ansible playbooks для настройки серверов
├── secrets/           # Управление секретами (SOPS)
└── nginx/             # Nginx конфигурация

.github/workflows/     # GitHub Actions CI/CD pipelines
```

## Terraform

См. [infra/terraform/README.md](../infra/terraform/README.md) для подробной документации.

### Быстрый старт

1. Установите Terraform >= 1.5.0
2. Настройте `terraform.tfvars`
3. Выполните:
   ```bash
   cd infra/terraform
   terraform init
   terraform plan
   terraform apply
   ```

## CI/CD Pipelines

### Backend Pipeline

Путь: `.github/workflows/backend.yml`

Этапы:
1. **Lint** - Проверка кода (flake8, black, isort, mypy)
2. **Test** - Запуск тестов с coverage
3. **Build** - Сборка Docker образа
4. **Deploy Staging** - Деплой на staging при push в `develop`
5. **Deploy Production** - Деплой на production при push в `main`

### Mobile Pipeline

Путь: `.github/workflows/mobile.yml`

Этапы:
1. **Analyze** - Анализ кода Flutter
2. **Test** - Unit, widget, integration тесты
3. **Build Android** - Сборка APK/AAB
4. **Build iOS** - Сборка IPA (только для main)
5. **Upload to Testers** - Загрузка в Firebase для тестирования (staging)

### Frontend Pipeline

Путь: `.github/workflows/frontend.yml`

Этапы:
1. **Lint** - ESLint и TypeScript проверка
2. **Test** - Unit тесты
3. **Build** - Сборка Next.js приложения
4. **Deploy Staging** - Деплой на Vercel staging
5. **Deploy Production** - Деплой на Vercel production

## Celery Autoscaling

Celery workers настроены на автоматическое масштабирование на основе нагрузки.

### Конфигурация

Переменные окружения:
- `CELERY_WORKER_CONCURRENCY` - Базовое количество worker процессов (по умолчанию: 4)
- `CELERY_WORKER_AUTOSCALER` - Включить/выключить autoscaling (true/false)
- `CELERY_WORKER_AUTOSCALER_MIN` - Минимальное количество workers (по умолчанию: 2)
- `CELERY_WORKER_AUTOSCALER_MAX` - Максимальное количество workers (по умолчанию: 10)

### Использование

В docker-compose.prod.yml autoscaling включен по умолчанию:
```yaml
command: >
  celery -A ringo_backend worker
  --autoscale=10,2
```

Для ручного управления:
```bash
celery -A ringo_backend worker --autoscale=10,2
```

## Secrets Management

См. [infra/secrets/README.md](../infra/secrets/README.md) для подробной документации.

### Методы

1. **GitHub Secrets** - Для CI/CD pipelines
2. **SOPS** - Для локального хранения зашифрованных файлов
3. **Vault** - Для enterprise окружений (опционально)

### Ротация секретов

Автоматическая ротация через GitHub Actions:
- Запускается каждый месяц
- Генерирует новые SECRET_KEY
- Создает issue для ручного обновления серверов

Ручная ротация через SOPS:
```bash
./infra/secrets/scripts/rotate-secrets.sh staging
```

## Мониторинг

После развертывания настройте мониторинг (см. этап 5.2):
- Sentry для ошибок
- Prometheus + Grafana для метрик
- Centralized logging (ELK/Vector)

## Backup & DR

Настройки backup (см. этап 5.3):
- Автоматические бэкапы БД (daily + WAL)
- Версионирование S3
- Runbooks для аварийных ситуаций

## Безопасность

Рекомендации по безопасности (см. этап 5.4):
- HTTPS (Let's Encrypt)
- WAF/firewall правила
- Pen-test чеклист
- Data privacy compliance

## Troubleshooting

### Проблемы с деплоем

1. Проверьте логи GitHub Actions
2. Проверьте SSH доступ к серверам
3. Проверьте переменные окружения
4. Проверьте Docker образы в registry

### Проблемы с Celery

1. Проверьте подключение к Redis
2. Проверьте логи workers: `docker logs ringo-worker`
3. Проверьте очередь задач: `celery -A ringo_backend inspect active`

### Проблемы с секретами

1. Проверьте, что секреты установлены в GitHub Secrets
2. Проверьте права доступа к секретам
3. Проверьте формат секретов (особенно многострочные)

## Масштабирование

### Горизонтальное масштабирование

1. Увеличьте `api_instance_count` в Terraform
2. Увеличьте `worker_instance_count` в Terraform
3. Примените изменения: `terraform apply`

### Вертикальное масштабирование

1. Измените размер инстансов в `terraform.tfvars`
2. Примените изменения: `terraform apply`
3. Перезапустите сервисы

### Автоматическое масштабирование Celery

Настройки autoscaling уже включены. Для изменения диапазона:
1. Обновите переменные окружения `CELERY_WORKER_AUTOSCALER_MIN/MAX`
2. Перезапустите workers


# Terraform Infrastructure для Ringo Uchet

Этот модуль содержит Terraform конфигурацию для развертывания инфраструктуры Ringo Uchet на DigitalOcean.

## Структура

- `main.tf` - Основные ресурсы (VPC, базы данных, droplets, load balancer)
- `variables.tf` - Переменные конфигурации
- `outputs.tf` - Выходные значения
- `terraform.tfvars.example` - Пример конфигурации
- `templates/` - Шаблоны для инициализации серверов

## Требования

1. Terraform >= 1.5.0
2. DigitalOcean API token
3. SSH ключи, добавленные в DigitalOcean

## Использование

1. Скопируйте пример конфигурации:
   ```bash
   cp terraform.tfvars.example terraform.tfvars
   ```

2. Отредактируйте `terraform.tfvars` и заполните все необходимые значения

3. Инициализируйте Terraform:
   ```bash
   terraform init
   ```

4. Просмотрите план изменений:
   ```bash
   terraform plan
   ```

5. Примените изменения:
   ```bash
   terraform apply
   ```

6. Для удаления инфраструктуры:
   ```bash
   terraform destroy
   ```

## Переменные

Основные переменные (см. `variables.tf` для полного списка):

- `do_token` - DigitalOcean API token (обязательно)
- `environment` - Окружение (staging/production)
- `region` - Регион DigitalOcean
- `api_instance_count` - Количество API инстансов
- `worker_instance_count` - Количество worker инстансов
- `celery_worker_concurrency` - Concurrency для Celery workers

## Outputs

После применения вы получите:

- `database_host` - Хост PostgreSQL
- `redis_host` - Хост Redis
- `spaces_endpoint` - Endpoint для Spaces (S3)
- `load_balancer_ip` - IP адрес load balancer
- `api_instances` - IP адреса API инстансов
- `worker_instances` - IP адреса worker инстансов

## Безопасность

⚠️ **ВАЖНО**: 

- Никогда не коммитьте `terraform.tfvars` в git
- Используйте remote backend для state файла в production
- Ограничьте `allowed_ssh_ips` до конкретных IP адресов
- Используйте секреты из GitHub Secrets или Vault для чувствительных данных

## Масштабирование

Для масштабирования измените переменные:

- `api_instance_count` - для увеличения API инстансов
- `worker_instance_count` - для увеличения worker инстансов
- `celery_worker_concurrency` - для изменения concurrency на worker

Затем выполните:
```bash
terraform apply
```

## Мониторинг

После развертывания настройте мониторинг (см. этап 5.2):
- Prometheus exporters
- Grafana dashboards
- Sentry для ошибок


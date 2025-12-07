# Инфраструктура Ringo Uchet

Этот каталог содержит всю инфраструктуру проекта для развертывания на DigitalOcean/AWS.

## Структура

```
infra/
├── terraform/          # Terraform конфигурация для создания инфраструктуры
│   ├── main.tf         # Основные ресурсы
│   ├── variables.tf    # Переменные
│   ├── outputs.tf     # Outputs
│   └── templates/      # Шаблоны для инициализации серверов
├── ansible/           # Ansible playbooks для настройки серверов
│   ├── playbook.yml   # Основной playbook
│   └── inventory.ini.example
├── secrets/           # Управление секретами
│   ├── .sops.yaml     # Конфигурация SOPS
│   ├── staging/       # Секреты для staging
│   └── production/    # Секреты для production
└── nginx/             # Nginx конфигурация
    └── default.conf
```

## Быстрый старт

### 1. Terraform

Создание инфраструктуры на DigitalOcean:

```bash
cd infra/terraform
cp terraform.tfvars.example terraform.tfvars
# Отредактируйте terraform.tfvars
terraform init
terraform plan
terraform apply
```

### 2. Ansible

Настройка серверов:

```bash
cd infra/ansible
cp inventory.ini.example inventory.ini
# Отредактируйте inventory.ini с IP адресами серверов
ansible-playbook -i inventory.ini playbook.yml
```

### 3. Secrets Management

Настройка секретов через GitHub Secrets (см. [secrets/README.md](secrets/README.md)):

1. Перейдите в GitHub → Settings → Secrets and variables → Actions
2. Добавьте все необходимые секреты (список в secrets/README.md)
3. Для production создайте отдельное окружение

Или используйте SOPS для локального хранения:

```bash
cd infra/secrets/staging
cp secrets.yaml.example secrets.yaml
# Заполните секреты
sops -e secrets.yaml > secrets.enc.yaml
rm secrets.yaml
```

## CI/CD

GitHub Actions workflows автоматически:
- Линтят и тестируют код
- Собирают Docker образы
- Деплоят на staging/production
- Загружают мобильные приложения в stores

См. `.github/workflows/` для деталей.

## Документация

- [Terraform README](terraform/README.md) - Детали Terraform конфигурации
- [Secrets README](secrets/README.md) - Управление секретами
- [Ansible README](ansible/README.md) - Ansible playbooks
- [Общая документация](../../docs/INFRASTRUCTURE.md) - Обзор инфраструктуры

## Поддержка

При возникновении проблем см. [docs/TROUBLESHOOTING.md](../../docs/TROUBLESHOOTING.md)


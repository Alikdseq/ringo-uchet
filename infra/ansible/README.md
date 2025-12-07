# Ansible Playbooks для Ringo Uchet

Ansible конфигурация для автоматизации настройки и управления серверами.

## Требования

- Ansible >= 2.9
- Python 3
- SSH доступ к серверам

## Использование

1. Скопируйте пример inventory:
   ```bash
   cp inventory.ini.example inventory.ini
   ```

2. Отредактируйте `inventory.ini` и укажите IP адреса ваших серверов

3. Запустите playbook:
   ```bash
   ansible-playbook -i inventory.ini playbook.yml
   ```

## Структура

- `playbook.yml` - Основной playbook для настройки серверов
- `inventory.ini.example` - Пример конфигурации inventory
- `roles/` - Ansible roles (если нужно расширить функциональность)

## Роли серверов

- `api_servers` - Серверы для API (Django)
- `worker_servers` - Серверы для Celery workers


#!/bin/bash
# Скрипт для настройки firewall правил (UFW)

set -e

echo "Configuring firewall rules..."

# Разрешаем SSH (важно сделать первым!)
ufw allow 22/tcp comment 'SSH'

# Разрешаем HTTP и HTTPS
ufw allow 80/tcp comment 'HTTP'
ufw allow 443/tcp comment 'HTTPS'

# Разрешаем PostgreSQL только из внутренней сети
ufw allow from 10.0.0.0/8 to any port 5432 comment 'PostgreSQL internal'

# Разрешаем Redis только из внутренней сети
ufw allow from 10.0.0.0/8 to any port 6379 comment 'Redis internal'

# Блокируем все остальные входящие соединения
ufw default deny incoming

# Разрешаем все исходящие соединения
ufw default allow outgoing

# Включаем firewall
ufw --force enable

# Показываем статус
ufw status verbose

echo "Firewall configured successfully!"


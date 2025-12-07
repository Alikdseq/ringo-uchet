#!/bin/bash
set -e

# Обновление системы
apt-get update
apt-get upgrade -y

# Установка Docker и Docker Compose
curl -fsSL https://get.docker.com -o get-docker.sh
sh get-docker.sh
rm get-docker.sh

# Установка Docker Compose
curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose

# Создание директории для приложения
mkdir -p /opt/ringo
cd /opt/ringo

# Создание docker-compose.worker.yml
cat > docker-compose.worker.yml << 'EOF'
version: '3.8'

services:
  celery-worker:
    image: ${DOCKER_REGISTRY}/ringo-backend:${IMAGE_TAG}
    restart: unless-stopped
    environment:
      - DJANGO_SETTINGS_MODULE=ringo_backend.settings.prod
      - POSTGRES_HOST=${DB_HOST}
      - POSTGRES_PORT=${DB_PORT}
      - POSTGRES_DB=${DB_NAME}
      - POSTGRES_USER=${DB_USER}
      - POSTGRES_PASSWORD=${DB_PASSWORD}
      - CELERY_BROKER_URL=${CELERY_BROKER_URL}
      - CELERY_RESULT_BACKEND=${CELERY_RESULT_BACKEND}
      - AWS_S3_ENDPOINT_URL=${AWS_S3_ENDPOINT_URL}
      - AWS_ACCESS_KEY_ID=${AWS_ACCESS_KEY_ID}
      - AWS_SECRET_ACCESS_KEY=${AWS_SECRET_ACCESS_KEY}
      - AWS_BUCKET=${AWS_BUCKET}
    command: celery -A ringo_backend worker --loglevel=info --concurrency=${WORKER_CONCURRENCY} --max-tasks-per-child=1000
    healthcheck:
      test: ["CMD", "celery", "-A", "ringo_backend", "inspect", "ping"]
      interval: 30s
      timeout: 10s
      retries: 3
    networks:
      - ringo-net

  celery-beat:
    image: ${DOCKER_REGISTRY}/ringo-backend:${IMAGE_TAG}
    restart: unless-stopped
    environment:
      - DJANGO_SETTINGS_MODULE=ringo_backend.settings.prod
      - POSTGRES_HOST=${DB_HOST}
      - POSTGRES_PORT=${DB_PORT}
      - POSTGRES_DB=${DB_NAME}
      - POSTGRES_USER=${DB_USER}
      - POSTGRES_PASSWORD=${DB_PASSWORD}
      - CELERY_BROKER_URL=${CELERY_BROKER_URL}
      - CELERY_RESULT_BACKEND=${CELERY_RESULT_BACKEND}
    command: celery -A ringo_backend beat --loglevel=info
    networks:
      - ringo-net

networks:
  ringo-net:
    driver: bridge
EOF

# Создание systemd service для автоматического запуска
cat > /etc/systemd/system/ringo-worker.service << 'EOF'
[Unit]
Description=Ringo Celery Worker Service
After=docker.service
Requires=docker.service

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=/opt/ringo
ExecStart=/usr/local/bin/docker-compose -f docker-compose.worker.yml up -d
ExecStop=/usr/local/bin/docker-compose -f docker-compose.worker.yml down
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable ringo-worker.service

# Настройка логирования
mkdir -p /var/log/ringo
chmod 755 /var/log/ringo

# Настройка firewall (UFW)
ufw allow 22/tcp
ufw --force enable

echo "Worker server initialization completed. Worker concurrency: ${WORKER_CONCURRENCY}"


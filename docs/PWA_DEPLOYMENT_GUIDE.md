# 🚀 ПОЛНЫЙ ПЛАН РАЗВЕРТЫВАНИЯ PWA ПРИЛОЖЕНИЯ RINGO UCHET

**Версия:** 1.0  
**Дата:** 2024  
**Автор:** Профессиональный DevOps специалист

---

## 📋 ОГЛАВЛЕНИЕ

1. [Предварительные требования](#1-предварительные-требования)
2. [Подготовка сервера](#2-подготовка-сервера)
3. [Настройка домена и DNS](#3-настройка-домена-и-dns)
4. [Установка необходимого ПО](#4-установка-необходимого-по)
5. [Подготовка Backend (Django)](#5-подготовка-backend-django)
6. [Сборка Flutter Web приложения](#6-сборка-flutter-web-приложения)
7. [Настройка PWA манифеста и иконок](#7-настройка-pwa-манифеста-и-иконок)
8. [Настройка Nginx](#8-настройка-nginx)
9. [Настройка HTTPS (SSL)](#9-настройка-https-ssl)
10. [Настройка Docker Compose для Production](#10-настройка-docker-compose-для-production)
11. [Запуск и тестирование](#11-запуск-и-тестирование)
12. [Мониторинг и обслуживание](#12-мониторинг-и-обслуживание)

---

## 1. ПРЕДВАРИТЕЛЬНЫЕ ТРЕБОВАНИЯ

### 1.1 Что вам понадобится:

- ✅ **VPS сервер** (рекомендуется):
  - Минимум: 2 CPU, 4GB RAM, 20GB SSD
  - Рекомендуется: 4 CPU, 8GB RAM, 50GB SSD
  - ОС: Ubuntu 22.04 LTS или Debian 12
  - Доступ: SSH с root или sudo правами

- ✅ **Домен** (обязательно для HTTPS):
  - Зарегистрированный домен (например: `ringo-uchet.ru`)
  - Доступ к панели управления DNS

- ✅ **Локальный компьютер** с установленным:
  - Flutter SDK (версия 3.0+)
  - Git
  - Docker и Docker Compose (для локальной разработки)

---

## 2. ПОДГОТОВКА СЕРВЕРА

### Шаг 2.1: Подключение к серверу

```bash
# Подключитесь к серверу по SSH
ssh root@YOUR_SERVER_IP
# или
ssh your_user@YOUR_SERVER_IP
```

### Шаг 2.2: Обновление системы

```bash
# Обновляем список пакетов
sudo apt update && sudo apt upgrade -y

# Устанавливаем базовые утилиты
sudo apt install -y curl wget git vim ufw htop
```

### Шаг 2.3: Настройка файрвола

```bash
# Разрешаем SSH (важно сделать ПЕРВЫМ!)
sudo ufw allow 22/tcp

# Разрешаем HTTP и HTTPS
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp

# Включаем файрвол
sudo ufw enable

# Проверяем статус
sudo ufw status
```

### Шаг 2.4: Создание пользователя для приложения (опционально, но рекомендуется)

```bash
# Создаем пользователя
sudo adduser ringo
sudo usermod -aG sudo ringo

# Переключаемся на нового пользователя
su - ringo
```

---

## 3. НАСТРОЙКА ДОМЕНА И DNS

### Шаг 3.1: Настройка DNS записей

В панели управления вашего домена создайте следующие записи:

**Тип A записи:**
```
Имя: @ (или пустое)
Значение: YOUR_SERVER_IP
TTL: 3600 (или Auto)
```

**Тип A записи для поддомена API (опционально):**
```
Имя: api
Значение: YOUR_SERVER_IP
TTL: 3600
```

**Тип A записи для поддомена WWW (опционально):**
```
Имя: www
Значение: YOUR_SERVER_IP
TTL: 3600
```

### Шаг 3.2: Проверка DNS

```bash
# Проверяем, что DNS записи применились (может занять до 24 часов)
dig your-domain.com
nslookup your-domain.com
```

**Важно:** Дождитесь, пока DNS записи распространятся (обычно 5-30 минут, но может быть до 24 часов).

---

## 4. УСТАНОВКА НЕОБХОДИМОГО ПО

### Шаг 4.1: Установка Docker

```bash
# Удаляем старые версии (если есть)
sudo apt remove -y docker docker-engine docker.io containerd runc

# Устанавливаем зависимости
sudo apt install -y \
    ca-certificates \
    curl \
    gnupg \
    lsb-release

# Добавляем официальный GPG ключ Docker
sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg

# Настраиваем репозиторий
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# Устанавливаем Docker
sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# Проверяем установку
sudo docker --version
sudo docker compose version

# Добавляем текущего пользователя в группу docker (чтобы не использовать sudo)
sudo usermod -aG docker $USER

# Выходим и заходим снова, чтобы изменения вступили в силу
exit
# (затем снова подключитесь по SSH)
```

### Шаг 4.2: Установка Nginx

```bash
# Устанавливаем Nginx
sudo apt install -y nginx

# Проверяем статус
sudo systemctl status nginx

# Включаем автозапуск
sudo systemctl enable nginx
```

### Шаг 4.3: Установка Certbot (для SSL сертификатов)

```bash
# Устанавливаем Certbot
sudo apt install -y certbot python3-certbot-nginx

# Проверяем установку
certbot --version
```

---

## 5. ПОДГОТОВКА BACKEND (DJANGO)

### Шаг 5.1: Клонирование проекта на сервер

```bash
# Переходим в домашнюю директорию
cd ~

# Клонируем проект (замените на ваш репозиторий)
git clone https://github.com/your-username/ringo-uchet.git
# или
git clone https://gitlab.com/your-username/ringo-uchet.git

# Переходим в директорию проекта
cd ringo-uchet
```

### Шаг 5.2: Настройка переменных окружения для Production

```bash
# Переходим в директорию backend
cd backend

# Создаем файл .env для production
nano .env
```

**Содержимое файла `backend/.env`:**

```env
# Django Production Settings
DJANGO_SETTINGS_MODULE=ringo_backend.settings.production
DJANGO_SECRET_KEY=ВАШ_СЕКРЕТНЫЙ_КЛЮЧ_СГЕНЕРИРУЙТЕ_НОВЫЙ
DJANGO_DEBUG=False
DJANGO_ALLOWED_HOSTS=your-domain.com,www.your-domain.com,api.your-domain.com,YOUR_SERVER_IP

# CORS - разрешаем только ваш домен
CORS_ALLOWED_ORIGINS=https://your-domain.com,https://www.your-domain.com
CORS_ALLOW_CREDENTIALS=True

# Database
POSTGRES_DB=ringo_prod
POSTGRES_USER=ringo_user
POSTGRES_PASSWORD=ВАШ_СИЛЬНЫЙ_ПАРОЛЬ_БД
POSTGRES_HOST=db
POSTGRES_PORT=5432

# Redis
REDIS_URL=redis://redis:6379/0
CELERY_BROKER_URL=redis://redis:6379/0
CELERY_RESULT_BACKEND=redis://redis:6379/0

# Email (настройте свой SMTP)
EMAIL_HOST=smtp.gmail.com
EMAIL_PORT=587
EMAIL_USE_TLS=True
EMAIL_HOST_USER=your-email@gmail.com
EMAIL_HOST_PASSWORD=your-app-password

# S3/MinIO (для production используйте реальный S3 или настройте MinIO)
AWS_ACCESS_KEY_ID=your-access-key
AWS_SECRET_ACCESS_KEY=your-secret-key
AWS_BUCKET=ringo-media-prod
AWS_S3_ENDPOINT_URL=http://minio:9000
AWS_S3_REGION_NAME=us-east-1

# MinIO
MINIO_ROOT_USER=minioadmin
MINIO_ROOT_PASSWORD=ВАШ_СИЛЬНЫЙ_ПАРОЛЬ_MINIO

# Encryption (сгенерируйте новый ключ)
ENCRYPTION_KEY=ВАШ_КЛЮЧ_ШИФРОВАНИЯ

# JWT
JWT_ACCESS_MINUTES=30
JWT_REFRESH_DAYS=7

# Notifications (опционально)
FCM_SERVER_KEY=
TELEGRAM_BOT_TOKEN=
SMS_API_KEY=
SMS_API_URL=
```

**Важно:** 
- Сгенерируйте `DJANGO_SECRET_KEY`: `python -c "from django.core.management.utils import get_random_secret_key; print(get_random_secret_key())"`
- Сгенерируйте `ENCRYPTION_KEY`: `python -c "from cryptography.fernet import Fernet; print(Fernet.generate_key().decode())"`

### Шаг 5.3: Создание production docker-compose файла

```bash
# Возвращаемся в корень проекта
cd ~/ringo-uchet

# Создаем production docker-compose файл
nano docker-compose.prod.yml
```

**Содержимое `docker-compose.prod.yml`:**

```yaml
version: '3.8'

services:
  django-api:
    build:
      context: ./backend
      dockerfile: Dockerfile
    command: gunicorn ringo_backend.wsgi:application --bind 0.0.0.0:8000 --workers 4 --timeout 120
    env_file:
      - backend/.env
    volumes:
      - ./backend:/app
      - static_volume:/app/staticfiles
      - media_volume:/app/media
    depends_on:
      - db
      - redis
      - minio
    networks:
      - ringo-net
    restart: unless-stopped

  celery:
    build:
      context: ./backend
      dockerfile: Dockerfile
    command: celery -A ringo_backend worker --loglevel=info --concurrency=4
    env_file:
      - backend/.env
    volumes:
      - ./backend:/app
    depends_on:
      - django-api
      - redis
    networks:
      - ringo-net
    restart: unless-stopped

  celery-beat:
    build:
      context: ./backend
      dockerfile: Dockerfile
    command: celery -A ringo_backend beat --loglevel=info
    env_file:
      - backend/.env
    volumes:
      - ./backend:/app
    depends_on:
      - django-api
      - redis
    networks:
      - ringo-net
    restart: unless-stopped

  db:
    image: postgres:15-alpine
    environment:
      POSTGRES_DB: ${POSTGRES_DB}
      POSTGRES_USER: ${POSTGRES_USER}
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD}
    volumes:
      - postgres_data:/var/lib/postgresql/data
    networks:
      - ringo-net
    restart: unless-stopped
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U ${POSTGRES_USER}"]
      interval: 10s
      timeout: 5s
      retries: 5

  redis:
    image: redis:7-alpine
    volumes:
      - redis_data:/data
    networks:
      - ringo-net
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 10s
      timeout: 5s
      retries: 5

  minio:
    image: minio/minio:latest
    command: server /data --console-address ":9001"
    environment:
      MINIO_ROOT_USER: ${MINIO_ROOT_USER}
      MINIO_ROOT_PASSWORD: ${MINIO_ROOT_PASSWORD}
    volumes:
      - minio_data:/data
    ports:
      - "9000:9000"
      - "9001:9001"
    networks:
      - ringo-net
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:9000/minio/health/live"]
      interval: 30s
      timeout: 20s
      retries: 3

volumes:
  postgres_data:
  redis_data:
  minio_data:
  static_volume:
  media_volume:

networks:
  ringo-net:
    driver: bridge
```

---

## 6. СБОРКА FLUTTER WEB ПРИЛОЖЕНИЯ

### Шаг 6.1: Подготовка на локальном компьютере

```bash
# На вашем локальном компьютере перейдите в директорию mobile
cd mobile

# Убедитесь, что Flutter установлен
flutter --version

# Обновите зависимости
flutter pub get

# Проверьте, что web поддержка включена
flutter config --enable-web
```

### Шаг 6.2: Настройка конфигурации для Production

Откройте файл `mobile/lib/core/config/app_config.dart` и убедитесь, что production конфигурация указывает на ваш домен:

```dart
static AppConfig get prod => const AppConfig(
  flavor: AppFlavor.prod,
  apiBaseUrl: 'https://your-domain.com',  // ИЗМЕНИТЕ НА ВАШ ДОМЕН
  apiVersion: 'v1',
  enableLogging: false,
  enableCrashlytics: true,
  appName: 'Ringo Uchet',
  packageName: 'com.ringo.prod',
);
```

### Шаг 6.3: Сборка Flutter Web приложения

```bash
# Очистка предыдущих сборок
flutter clean

# Сборка для production
flutter build web --release --base-href / --dart-define=FLUTTER_WEB_USE_SKIA=true

# Проверяем, что сборка прошла успешно
ls -la build/web/
```

**Результат:** В директории `mobile/build/web/` должны появиться файлы:
- `index.html`
- `main.dart.js`
- `flutter.js`
- `manifest.json`
- и другие файлы

### Шаг 6.4: Копирование собранных файлов на сервер

```bash
# Создаем архив со сборкой
cd mobile/build
tar -czf web-build.tar.gz web/

# Копируем на сервер (замените на ваши данные)
scp web-build.tar.gz ringo@YOUR_SERVER_IP:~/

# На сервере распаковываем
ssh ringo@YOUR_SERVER_IP
cd ~
mkdir -p /var/www/ringo-uchet
tar -xzf web-build.tar.gz -C /var/www/ringo-uchet --strip-components=1
```

**Альтернативный способ (через Git):**

```bash
# На локальном компьютере
cd mobile/build
git init
git add web/
git commit -m "Web build"
git remote add production ringo@YOUR_SERVER_IP:/var/www/ringo-uchet.git
git push production main

# На сервере
cd /var/www/ringo-uchet
git clone ~/ringo-uchet.git .
```

---

## 7. НАСТРОЙКА PWA МАНИФЕСТА И ИКОНОК

### Шаг 7.1: Обновление manifest.json

```bash
# На сервере
nano /var/www/ringo-uchet/manifest.json
```

**Обновленный `manifest.json`:**

```json
{
    "name": "Ringo Uchet - Учет аренды спецтехники",
    "short_name": "Ringo Uchet",
    "start_url": "/",
    "display": "standalone",
    "background_color": "#ffffff",
    "theme_color": "#0175C2",
    "description": "Профессиональное приложение для управления арендой спецтехники",
    "orientation": "any",
    "prefer_related_applications": false,
    "scope": "/",
    "icons": [
        {
            "src": "icons/Icon-192.png",
            "sizes": "192x192",
            "type": "image/png",
            "purpose": "any"
        },
        {
            "src": "icons/Icon-512.png",
            "sizes": "512x512",
            "type": "image/png",
            "purpose": "any"
        },
        {
            "src": "icons/Icon-maskable-192.png",
            "sizes": "192x192",
            "type": "image/png",
            "purpose": "maskable"
        },
        {
            "src": "icons/Icon-maskable-512.png",
            "sizes": "512x512",
            "type": "image/png",
            "purpose": "maskable"
        }
    ],
    "screenshots": [],
    "categories": ["business", "productivity"],
    "shortcuts": [
        {
            "name": "Новая заявка",
            "short_name": "Заявка",
            "description": "Создать новую заявку",
            "url": "/orders/create",
            "icons": [
                {
                    "src": "icons/Icon-192.png",
                    "sizes": "192x192"
                }
            ]
        }
    ]
}
```

### Шаг 7.2: Обновление index.html

```bash
nano /var/www/ringo-uchet/index.html
```

**Обновленный `index.html` (важные части):**

```html
<!DOCTYPE html>
<html>
<head>
  <base href="/">
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
  <meta name="description" content="Ringo Uchet - Профессиональное приложение для управления арендой спецтехники">
  <meta name="theme-color" content="#0175C2">
  
  <!-- iOS meta tags -->
  <meta name="mobile-web-app-capable" content="yes">
  <meta name="apple-mobile-web-app-capable" content="yes">
  <meta name="apple-mobile-web-app-status-bar-style" content="black-translucent">
  <meta name="apple-mobile-web-app-title" content="Ringo Uchet">
  <link rel="apple-touch-icon" href="icons/Icon-192.png">
  
  <!-- Favicon -->
  <link rel="icon" type="image/png" href="favicon.png"/>
  
  <title>Ringo Uchet - Учет аренды спецтехники</title>
  <link rel="manifest" href="manifest.json">
</head>
<body>
  <script>
    // Service Worker регистрация (если используется)
    if ('serviceWorker' in navigator) {
      window.addEventListener('load', () => {
        navigator.serviceWorker.register('/flutter_service_worker.js')
          .then((registration) => {
            console.log('Service Worker registered:', registration);
          })
          .catch((error) => {
            console.log('Service Worker registration failed:', error);
          });
      });
    }
  </script>
  <script src="flutter_bootstrap.js" async></script>
</body>
</html>
```

### Шаг 7.3: Проверка иконок

Убедитесь, что все иконки присутствуют:

```bash
ls -la /var/www/ringo-uchet/icons/
# Должны быть:
# - Icon-192.png
# - Icon-512.png
# - Icon-maskable-192.png
# - Icon-maskable-512.png
```

Если иконок нет, скопируйте их из `mobile/web/icons/` или создайте новые.

---

## 8. НАСТРОЙКА NGINX

### Шаг 8.1: Создание конфигурации Nginx

```bash
sudo nano /etc/nginx/sites-available/ringo-uchet
```

**Содержимое конфигурации:**

```nginx
# HTTP сервер - редирект на HTTPS
server {
    listen 80;
    listen [::]:80;
    server_name your-domain.com www.your-domain.com;

    # Редирект на HTTPS
    return 301 https://$server_name$request_uri;
}

# HTTPS сервер
server {
    listen 443 ssl http2;
    listen [::]:443 ssl http2;
    server_name your-domain.com www.your-domain.com;

    # SSL сертификаты (будут настроены Certbot)
    ssl_certificate /etc/letsencrypt/live/your-domain.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/your-domain.com/privkey.pem;
    
    # SSL настройки
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;
    ssl_prefer_server_ciphers on;
    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 10m;

    # Логи
    access_log /var/log/nginx/ringo-uchet-access.log;
    error_log /var/log/nginx/ringo-uchet-error.log;

    # Максимальный размер загружаемых файлов
    client_max_body_size 100M;

    # Статические файлы Flutter Web приложения
    location / {
        root /var/www/ringo-uchet;
        index index.html;
        try_files $uri $uri/ /index.html;
        
        # Кэширование статических файлов
        location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg|woff|woff2|ttf|eot)$ {
            expires 1y;
            add_header Cache-Control "public, immutable";
        }
        
        # Без кэширования для HTML
        location ~* \.html$ {
            expires -1;
            add_header Cache-Control "no-store, no-cache, must-revalidate, proxy-revalidate";
        }
    }

    # API проксирование к Django
    location /api/ {
        proxy_pass http://127.0.0.1:8001;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_set_header X-Forwarded-Host $server_name;
        
        # Таймауты
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
        
        # WebSocket поддержка (если используется)
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
    }

    # Статические файлы Django (CSS, JS, изображения)
    location /static/ {
        alias /var/www/ringo-uchet/staticfiles/;
        expires 1y;
        add_header Cache-Control "public, immutable";
    }

    # Медиа файлы Django (загруженные пользователями)
    location /media/ {
        alias /var/www/ringo-uchet/media/;
        expires 1y;
        add_header Cache-Control "public";
    }

    # Безопасность заголовков
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header Referrer-Policy "no-referrer-when-downgrade" always;
    
    # PWA поддержка
    add_header Service-Worker-Allowed "/" always;
}

# Опционально: поддомен для API
server {
    listen 443 ssl http2;
    listen [::]:443 ssl http2;
    server_name api.your-domain.com;

    ssl_certificate /etc/letsencrypt/live/your-domain.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/your-domain.com/privkey.pem;

    access_log /var/log/nginx/ringo-api-access.log;
    error_log /var/log/nginx/ringo-api-error.log;

    client_max_body_size 100M;

    location / {
        proxy_pass http://127.0.0.1:8001;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
    }
}
```

### Шаг 8.2: Активация конфигурации

```bash
# Создаем символическую ссылку
sudo ln -s /etc/nginx/sites-available/ringo-uchet /etc/nginx/sites-enabled/

# Удаляем дефолтную конфигурацию (если не нужна)
sudo rm /etc/nginx/sites-enabled/default

# Проверяем конфигурацию на ошибки
sudo nginx -t

# Если все ОК, перезагружаем Nginx
sudo systemctl reload nginx
```

---

## 9. НАСТРОЙКА HTTPS (SSL)

### Шаг 9.1: Получение SSL сертификата через Let's Encrypt

```bash
# Останавливаем Nginx временно (Certbot запустит свой веб-сервер)
sudo systemctl stop nginx

# Получаем сертификат
sudo certbot certonly --standalone -d your-domain.com -d www.your-domain.com

# Если нужен поддомен для API:
sudo certbot certonly --standalone -d api.your-domain.com

# Запускаем Nginx обратно
sudo systemctl start nginx
```

**Важно:** Перед выполнением команды убедитесь, что:
- Домен указывает на ваш сервер (проверьте: `dig your-domain.com`)
- Порт 80 открыт в файрволе

### Шаг 9.2: Обновление конфигурации Nginx с SSL

Конфигурация уже содержит SSL настройки (см. Шаг 8.1), просто убедитесь, что пути к сертификатам правильные.

### Шаг 9.3: Настройка автоматического обновления сертификата

```bash
# Проверяем, что автообновление настроено
sudo certbot renew --dry-run

# Настраиваем cron для автоматического обновления
sudo crontab -e
# Добавьте строку:
0 0 * * * certbot renew --quiet --post-hook "systemctl reload nginx"
```

---

## 10. НАСТРОЙКА DOCKER COMPOSE ДЛЯ PRODUCTION

### Шаг 10.1: Запуск Backend сервисов

```bash
# Переходим в директорию проекта
cd ~/ringo-uchet

# Запускаем сервисы
docker compose -f docker-compose.prod.yml up -d

# Проверяем статус
docker compose -f docker-compose.prod.yml ps

# Смотрим логи
docker compose -f docker-compose.prod.yml logs -f
```

### Шаг 10.2: Применение миграций

```bash
# Применяем миграции
docker compose -f docker-compose.prod.yml exec django-api python manage.py migrate

# Собираем статические файлы
docker compose -f docker-compose.prod.yml exec django-api python manage.py collectstatic --noinput
```

### Шаг 10.3: Создание суперпользователя

```bash
# Входим в Django shell
docker compose -f docker-compose.prod.yml exec django-api python manage.py shell

# В Python shell:
from users.models import User
User.objects.create_superuser(
    phone='+79991234567',
    email='admin@your-domain.com',
    password='ВАШ_СИЛЬНЫЙ_ПАРОЛЬ',
    role='admin',
    first_name='Admin',
    last_name='User'
)
exit()
```

### Шаг 10.4: Настройка прав доступа для статических файлов

```bash
# Копируем статические файлы из контейнера
docker compose -f docker-compose.prod.yml exec django-api python manage.py collectstatic --noinput

# Настраиваем права
sudo chown -R www-data:www-data /var/www/ringo-uchet
sudo chmod -R 755 /var/www/ringo-uchet
```

---

## 11. ЗАПУСК И ТЕСТИРОВАНИЕ

### Шаг 11.1: Проверка работы Backend API

```bash
# Проверяем, что API отвечает
curl https://your-domain.com/api/health/
# или
curl https://api.your-domain.com/api/health/
```

### Шаг 11.2: Проверка работы Frontend

1. Откройте в браузере: `https://your-domain.com`
2. Должна загрузиться главная страница приложения
3. Проверьте консоль браузера (F12) на наличие ошибок

### Шаг 11.3: Тестирование PWA функций

1. **Установка на устройство:**
   - На Android: Chrome → меню → "Добавить на главный экран"
   - На iOS: Safari → Поделиться → "На экран «Домой»"

2. **Проверка оффлайн режима:**
   - Отключите интернет
   - Приложение должно работать (если настроен Service Worker)

3. **Проверка манифеста:**
   - Откройте: `https://your-domain.com/manifest.json`
   - Должен отображаться JSON манифест

### Шаг 11.4: Тестирование API

```bash
# Тест авторизации
curl -X POST https://your-domain.com/api/token/ \
  -H "Content-Type: application/json" \
  -d '{"phone": "+79991234567", "password": "your-password"}'

# Должен вернуть access и refresh токены
```

---

## 12. МОНИТОРИНГ И ОБСЛУЖИВАНИЕ

### Шаг 12.1: Настройка логирования

```bash
# Просмотр логов Nginx
sudo tail -f /var/log/nginx/ringo-uchet-access.log
sudo tail -f /var/log/nginx/ringo-uchet-error.log

# Просмотр логов Docker
docker compose -f docker-compose.prod.yml logs -f django-api
docker compose -f docker-compose.prod.yml logs -f celery
```

### Шаг 12.2: Настройка автоматических бэкапов

```bash
# Создаем скрипт бэкапа
nano ~/backup-ringo.sh
```

**Содержимое скрипта:**

```bash
#!/bin/bash
BACKUP_DIR="/var/backups/ringo-uchet"
DATE=$(date +%Y%m%d_%H%M%S)

mkdir -p $BACKUP_DIR

# Бэкап базы данных
docker compose -f ~/ringo-uchet/docker-compose.prod.yml exec -T db pg_dump -U ringo_user ringo_prod > $BACKUP_DIR/db_$DATE.sql

# Бэкап медиа файлов
tar -czf $BACKUP_DIR/media_$DATE.tar.gz /var/www/ringo-uchet/media/

# Удаляем старые бэкапы (старше 30 дней)
find $BACKUP_DIR -name "*.sql" -mtime +30 -delete
find $BACKUP_DIR -name "*.tar.gz" -mtime +30 -delete

echo "Backup completed: $DATE"
```

```bash
# Делаем скрипт исполняемым
chmod +x ~/backup-ringo.sh

# Настраиваем cron (ежедневно в 2:00)
crontab -e
# Добавьте:
0 2 * * * /home/ringo/backup-ringo.sh >> /var/log/ringo-backup.log 2>&1
```

### Шаг 12.3: Мониторинг ресурсов

```bash
# Установка утилит мониторинга
sudo apt install -y htop iotop nethogs

# Проверка использования диска
df -h

# Проверка использования памяти
free -h

# Проверка процессов
htop
```

### Шаг 12.4: Обновление приложения

```bash
# Обновление кода
cd ~/ringo-uchet
git pull origin main

# Пересборка и перезапуск
docker compose -f docker-compose.prod.yml down
docker compose -f docker-compose.prod.yml build --no-cache
docker compose -f docker-compose.prod.yml up -d

# Применение миграций (если есть новые)
docker compose -f docker-compose.prod.yml exec django-api python manage.py migrate

# Обновление статических файлов
docker compose -f docker-compose.prod.yml exec django-api python manage.py collectstatic --noinput
```

### Шаг 12.5: Обновление Flutter Web приложения

```bash
# На локальном компьютере
cd mobile
flutter clean
flutter pub get
flutter build web --release --base-href /

# Копирование на сервер
scp -r build/web/* ringo@YOUR_SERVER_IP:/var/www/ringo-uchet/

# На сервере - обновление прав
sudo chown -R www-data:www-data /var/www/ringo-uchet
```

---

## ✅ ЧЕКЛИСТ ГОТОВНОСТИ

Перед тем как считать развертывание завершенным, проверьте:

- [ ] Домен настроен и указывает на сервер
- [ ] SSL сертификат установлен и работает
- [ ] Backend API отвечает на запросы
- [ ] Frontend приложение загружается
- [ ] PWA манифест доступен
- [ ] Иконки отображаются корректно
- [ ] Авторизация работает
- [ ] API запросы проходят через HTTPS
- [ ] Статические файлы загружаются
- [ ] Бэкапы настроены
- [ ] Логирование работает
- [ ] Мониторинг настроен

---

## 🆘 РЕШЕНИЕ ПРОБЛЕМ

### Проблема: Приложение не загружается

**Решение:**
1. Проверьте логи Nginx: `sudo tail -f /var/log/nginx/ringo-uchet-error.log`
2. Проверьте права доступа: `sudo ls -la /var/www/ringo-uchet`
3. Проверьте конфигурацию Nginx: `sudo nginx -t`

### Проблема: API не отвечает

**Решение:**
1. Проверьте статус контейнеров: `docker compose -f docker-compose.prod.yml ps`
2. Проверьте логи Django: `docker compose -f docker-compose.prod.yml logs django-api`
3. Проверьте, что порт 8001 открыт: `netstat -tulpn | grep 8001`

### Проблема: SSL сертификат не работает

**Решение:**
1. Проверьте DNS: `dig your-domain.com`
2. Проверьте сертификат: `sudo certbot certificates`
3. Обновите сертификат: `sudo certbot renew`

### Проблема: PWA не устанавливается

**Решение:**
1. Проверьте манифест: `https://your-domain.com/manifest.json`
2. Убедитесь, что используется HTTPS
3. Проверьте иконки: они должны быть доступны по указанным путям

---

## 📞 ПОДДЕРЖКА

Если возникли проблемы:
1. Проверьте логи (см. раздел 12.1)
2. Проверьте статус сервисов: `docker compose -f docker-compose.prod.yml ps`
3. Проверьте конфигурацию: `sudo nginx -t`
4. Проверьте файрвол: `sudo ufw status`

---

**Успешного развертывания! 🚀**


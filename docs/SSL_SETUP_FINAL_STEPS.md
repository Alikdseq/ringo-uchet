# ✅ ФИНАЛЬНАЯ НАСТРОЙКА SSL ДЛЯ ringoouchet.ru

## 🎯 ЦЕЛЬ
Настроить HTTPS с Let's Encrypt сертификатом.

---

## 📋 ШАГ 1: ОБНОВИТЬ NGINX ДЛЯ ПОЛУЧЕНИЯ SSL

### 1.1 Открыть конфигурацию Nginx

```bash
sudo nano /etc/nginx/sites-available/ringo-uchet
```

### 1.2 Обновить конфигурацию

**Замените содержимое на:**

```nginx
# HTTP сервер - для получения сертификата
server {
    listen 80;
    listen [::]:80;
    server_name ringoouchet.ru www.ringoouchet.ru 91.229.90.72;

    # Для Certbot - получение SSL сертификата
    location /.well-known/acme-challenge/ {
        root /var/www/certbot;
    }

    # Статические файлы Flutter Web приложения
    location / {
        root /var/www/ringo-uchet;
        index index.html;
        try_files $uri $uri/ /index.html;
        
        location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg|woff|woff2|ttf|eot|wasm)$ {
            expires 1y;
            add_header Cache-Control "public, immutable";
        }
        
        location ~* \.html$ {
            expires -1;
            add_header Cache-Control "no-store, no-cache, must-revalidate";
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
        
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
        
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
    }

    # Безопасность заголовков
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header Referrer-Policy "no-referrer-when-downgrade" always;
    add_header Service-Worker-Allowed "/" always;
}

# HTTPS сервер (будет активен после получения сертификата)
server {
    listen 443 ssl http2;
    listen [::]:443 ssl http2;
    server_name ringoouchet.ru www.ringoouchet.ru;

    # SSL сертификаты (будут созданы Certbot)
    ssl_certificate /etc/letsencrypt/live/ringoouchet.ru/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/ringoouchet.ru/privkey.pem;
    
    # SSL настройки
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;
    ssl_prefer_server_ciphers on;
    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 10m;

    # Логи
    access_log /var/log/nginx/ringo-uchet-access.log;
    error_log /var/log/nginx/ringo-uchet-error.log;

    client_max_body_size 100M;

    # Статические файлы Flutter Web приложения
    location / {
        root /var/www/ringo-uchet;
        index index.html;
        try_files $uri $uri/ /index.html;
        
        location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg|woff|woff2|ttf|eot|wasm)$ {
            expires 1y;
            add_header Cache-Control "public, immutable";
        }
        
        location ~* \.html$ {
            expires -1;
            add_header Cache-Control "no-store, no-cache, must-revalidate";
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
        
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
        
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
    }

    # Безопасность заголовков
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header Referrer-Policy "no-referrer-when-downgrade" always;
    add_header Service-Worker-Allowed "/" always;
    
    # HSTS
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
}
```

**Сохраните:** `Ctrl + O`, `Enter`, `Ctrl + X`

---

## 📋 ШАГ 2: СОЗДАТЬ ДИРЕКТОРИЮ ДЛЯ CERTBOT

```bash
sudo mkdir -p /var/www/certbot
sudo chown -R www-data:www-data /var/www/certbot
sudo chmod -R 755 /var/www/certbot
```

---

## 📋 ШАГ 3: ПРОВЕРИТЬ И ПЕРЕЗАГРУЗИТЬ NGINX

```bash
sudo nginx -t
```

**Если все хорошо, перезагрузите:**

```bash
sudo systemctl reload nginx
```

---

## 📋 ШАГ 4: ПОЛУЧИТЬ SSL СЕРТИФИКАТ

```bash
sudo certbot certonly --webroot -w /var/www/certbot -d ringoouchet.ru -d www.ringoouchet.ru
```

**Следуйте инструкциям:**
- Введите email (для уведомлений)
- Согласитесь с условиями
- Согласитесь на подписку (можно отказаться)

**Должно показать:** `Congratulations!`

---

## 📋 ШАГ 5: ВКЛЮЧИТЬ HTTPS РЕДИРЕКТ

### 5.1 Обновить Nginx конфигурацию

```bash
sudo nano /etc/nginx/sites-available/ringo-uchet
```

**В HTTP блоке (после `location /.well-known/acme-challenge/`) добавьте редирект:**

```nginx
    # Редирект всех остальных запросов на HTTPS
    location / {
        return 301 https://$server_name$request_uri;
    }
```

**Но оставьте блок для Certbot:**

```nginx
    location /.well-known/acme-challenge/ {
        root /var/www/certbot;
    }
    
    location / {
        return 301 https://$server_name$request_uri;
    }
```

**Сохраните:** `Ctrl + O`, `Enter`, `Ctrl + X`

### 5.2 Проверить и перезагрузить

```bash
sudo nginx -t
sudo systemctl reload nginx
```

---

## 📋 ШАГ 6: ВКЛЮЧИТЬ SSL РЕДИРЕКТ В DJANGO

```bash
cd ~/ringo-uchet/backend
docker compose -f docker-compose.prod.yml exec api sed -i 's/SECURE_SSL_REDIRECT = False/SECURE_SSL_REDIRECT = True/' ringo_backend/settings/prod.py
docker compose -f docker-compose.prod.yml restart api
```

---

## 📋 ШАГ 7: ОБНОВИТЬ FLUTTER КОНФИГУРАЦИЮ НА HTTPS

**На вашем компьютере откройте:**

`mobile/lib/core/config/app_config.dart`

**Измените:**

```dart
apiBaseUrl: 'https://ringoouchet.ru',
```

**Пересоберите и загрузите на сервер.**

---

## 📋 ШАГ 8: ПРОВЕРКА HTTPS

```bash
curl https://ringoouchet.ru/api/health/
```

**Должен вернуть JSON по HTTPS!**

---

**Готовы начать? Начнем с шага 1!**


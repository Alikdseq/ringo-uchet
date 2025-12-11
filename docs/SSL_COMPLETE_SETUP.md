# ✅ SSL СЕРТИФИКАТ ПОЛУЧЕН - ЗАВЕРШАЕМ НАСТРОЙКУ

## ✅ СЕРТИФИКАТ ПОЛУЧЕН

```
Successfully received certificate.
Certificate is saved at: /etc/letsencrypt/live/ringoouchet.ru/fullchain.pem
Key is saved at:         /etc/letsencrypt/live/ringoouchet.ru/privkey.pem
This certificate expires on 2026-03-07.
```

**Отлично!** ✅

---

## 📋 ШАГ 1: ДОБАВИТЬ HTTPS БЛОК В NGINX

### 1.1 Открыть конфигурацию

```bash
sudo nano /etc/nginx/sites-available/ringo-uchet
```

### 1.2 Добавить HTTPS блок в КОНЦЕ файла

**После закрывающей скобки HTTP блока добавьте:**

```nginx
# HTTPS сервер
server {
    listen 443 ssl http2;
    listen [::]:443 ssl http2;
    server_name ringoouchet.ru www.ringoouchet.ru;

    # SSL сертификаты
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

## 📋 ШАГ 2: ПРОВЕРИТЬ И ПЕРЕЗАГРУЗИТЬ NGINX

```bash
sudo nginx -t
```

**Если все хорошо:**

```bash
sudo systemctl reload nginx
```

---

## 📋 ШАГ 3: ВКЛЮЧИТЬ HTTPS РЕДИРЕКТ

### 3.1 Обновить HTTP блок

```bash
sudo nano /etc/nginx/sites-available/ringo-uchet
```

**В HTTP блоке замените `location / {` на редирект:**

```nginx
    # Редирект на HTTPS (кроме Certbot)
    location /.well-known/acme-challenge/ {
        root /var/www/certbot;
    }
    
    location / {
        return 301 https://$server_name$request_uri;
    }
```

**Сохраните:** `Ctrl + O`, `Enter`, `Ctrl + X`

### 3.2 Проверить и перезагрузить

```bash
sudo nginx -t
sudo systemctl reload nginx
```

---

## 📋 ШАГ 4: ВКЛЮЧИТЬ SSL РЕДИРЕКТ В DJANGO

```bash
cd ~/ringo-uchet/backend
docker compose -f docker-compose.prod.yml exec api sed -i 's/SECURE_SSL_REDIRECT = False/SECURE_SSL_REDIRECT = True/' ringo_backend/settings/prod.py
docker compose -f docker-compose.prod.yml restart api
```

---

## 📋 ШАГ 5: ПРОВЕРКА HTTPS

```bash
curl https://ringoouchet.ru/api/health/
```

**Должен вернуть JSON по HTTPS!**

---

**Выполните шаги по порядку!**


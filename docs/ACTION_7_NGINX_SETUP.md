# ✅ ДЕЙСТВИЕ 7: НАСТРОЙКА NGINX ДЛЯ FRONTEND И API

## 🎯 ЦЕЛЬ
Настроить Nginx для раздачи Flutter Web приложения и проксирования запросов к API.

---

## 📋 ШАГ 1: ПРОВЕРКА И НАСТРОЙКА ПРАВ ДОСТУПА

```bash
sudo chown -R www-data:www-data /var/www/ringo-uchet
sudo chmod -R 755 /var/www/ringo-uchet
ls -la /var/www/ringo-uchet/ | head -10
```

**Должны быть файлы:** `index.html`, `main.dart.js`, `manifest.json`

---

## 📋 ШАГ 2: СОЗДАНИЕ КОНФИГУРАЦИИ NGINX

### 2.1 Создание файла конфигурации

```bash
sudo nano /etc/nginx/sites-available/ringo-uchet
```

### 2.2 Вставьте конфигурацию

**ВНИМАНИЕ:** Замените `ВАШ_IP` на реальный IP вашего сервера!

```nginx
# HTTP сервер (пока без SSL)
server {
    listen 80;
    listen [::]:80;
    server_name ВАШ_IP;

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
        location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg|woff|woff2|ttf|eot|wasm)$ {
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
        
        # WebSocket поддержка
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
```

**Сохраните:** `Ctrl + O`, `Enter`, `Ctrl + X`

---

## 📋 ШАГ 3: АКТИВАЦИЯ КОНФИГУРАЦИИ

### 3.1 Создание символической ссылки

```bash
sudo ln -s /etc/nginx/sites-available/ringo-uchet /etc/nginx/sites-enabled/
```

### 3.2 Удаление дефолтной конфигурации (если не нужна)

```bash
sudo rm -f /etc/nginx/sites-enabled/default
```

### 3.3 Проверка конфигурации

```bash
sudo nginx -t
```

**Должно показать:** `syntax is ok` и `test is successful`

### 3.4 Перезагрузка Nginx

```bash
sudo systemctl reload nginx
```

---

## 📋 ШАГ 4: ПРОВЕРКА РАБОТЫ

### 4.1 Проверка статуса Nginx

```bash
sudo systemctl status nginx
```

**Должен быть:** `active (running)`

### 4.2 Проверка в браузере

**Откройте в браузере:**
```
http://ВАШ_IP
```

**Должна загрузиться главная страница Flutter приложения.**

### 4.3 Проверка API через Nginx

```bash
curl http://ВАШ_IP/api/health/
```

**Должен вернуть ответ (даже если 301 - это нормально).**

---

## ⚠️ ЕСЛИ ЧТО-ТО НЕ РАБОТАЕТ

### Проблема: Nginx не запускается

```bash
sudo nginx -t
sudo systemctl status nginx
sudo journalctl -u nginx -n 50
```

### Проблема: 502 Bad Gateway

**Проверьте, что API запущен:**
```bash
docker compose -f ~/ringo-uchet/backend/docker-compose.prod.yml ps
curl http://127.0.0.1:8001/api/health/
```

### Проблема: 404 Not Found

**Проверьте путь к файлам:**
```bash
ls -la /var/www/ringo-uchet/index.html
```

---

## ✅ ПРОВЕРКА

1. ✅ Nginx запущен: `sudo systemctl status nginx`
2. ✅ Конфигурация валидна: `sudo nginx -t`
3. ✅ Приложение открывается: `http://ВАШ_IP`
4. ✅ API доступен: `curl http://ВАШ_IP/api/health/`

---

## ⏭️ СЛЕДУЮЩИЙ ШАГ

**После проверки напишите:**
- ✅ **"Готово, Nginx настроен и приложение доступно"** - перейдем к финальной проверке

---

**Статус:** ⏳ Настройка Nginx

**Время выполнения:** 5-10 минут


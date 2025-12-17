# 🚀 Деплой веб-версии с максимальной оптимизацией размера

## 📋 Быстрый старт (Windows PowerShell)

### 1. Собрать оптимизированную версию:

```powershell
cd mobile
.\scripts\build-web-optimized.ps1
```

### 2. Очистка выполняется автоматически

Скрипт `build-web-optimized.ps1` автоматически:
- Удаляет canvaskit (используется HTML рендерер, экономия ~26 МБ)
- Удаляет debug символы (*.symbols)
- Удаляет NOTICES файлы

**Внимание:** Если хотите использовать Skia рендерер (canvaskit) для лучшей производительности, закомментируйте удаление canvaskit в скрипте. HTML рендерер меньше (~4 МБ), но может иметь ограничения.

Проверить размер:
```powershell
cd mobile\build\web
$size = (Get-ChildItem -Recurse -File | Measure-Object -Property Length -Sum).Sum
Write-Host "Final size: $([math]::Round($size / 1MB, 2)) MB" -ForegroundColor Green
```

### 3. Создать оптимизированный архив:

```powershell
cd mobile\build

# Создать архив с максимальным сжатием
$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
Compress-Archive -Path web\* -DestinationPath "web-optimized-$timestamp.zip" -CompressionLevel Optimal

Write-Host "Archive created: web-optimized-$timestamp.zip" -ForegroundColor Green
```

### 4. Загрузить на сервер (SCP):

```powershell
# Настройте эти переменные
$SERVER_USER = "root"  # или ваш пользователь
$SERVER_IP = "91.229.90.72"  # ваш IP сервера
$WEB_DIR = "/var/www/ringo-uchet"  # директория на сервере

# Найти последний архив
$archive = Get-ChildItem web-optimized-*.zip | Sort-Object Name -Descending | Select-Object -First 1

# Загрузить на сервер
scp $archive.FullName ${SERVER_USER}@${SERVER_IP}:/tmp/web-latest.zip

Write-Host "Archive uploaded to server" -ForegroundColor Green
```

### 5. Развернуть на сервере (SSH):

```bash
# Подключиться к серверу
ssh root@91.229.90.72

# Создать резервную копию текущей версии
sudo mkdir -p /var/www/ringo-uchet-backup-$(date +%Y%m%d-%H%M%S)
sudo cp -r /var/www/ringo-uchet/* /var/www/ringo-uchet-backup-$(date +%Y%m%d-%H%M%S)/ 2>/dev/null || true

# Распаковать новую версию
sudo mkdir -p /var/www/ringo-uchet
sudo unzip -o /tmp/web-latest.zip -d /var/www/ringo-uchet/
sudo chown -R www-data:www-data /var/www/ringo-uchet
sudo chmod -R 755 /var/www/ringo-uchet

# Удалить временный файл
rm /tmp/web-latest.zip

echo "✅ Deployment completed!"
```

### 6. Настроить Nginx с gzip/brotli (на сервере):

```bash
# Создать конфигурацию Nginx
sudo nano /etc/nginx/sites-available/ringo-uchet
```

**Содержимое файла (замените your-domain.com на ваш домен):**

```nginx
server {
    listen 80;
    server_name your-domain.com;
    
    # Редирект на HTTPS
    return 301 https://$server_name$request_uri;
}

server {
    listen 443 ssl http2;
    server_name your-domain.com;
    
    root /var/www/ringo-uchet;
    index index.html;
    
    # SSL сертификаты (Let's Encrypt)
    ssl_certificate /etc/letsencrypt/live/your-domain.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/your-domain.com/privkey.pem;
    
    # SSL настройки
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;
    ssl_prefer_server_ciphers on;
    
    # Gzip сжатие (максимальное)
    gzip on;
    gzip_vary on;
    gzip_proxied any;
    gzip_comp_level 9;  # Максимальный уровень сжатия
    gzip_min_length 1000;
    gzip_types
        text/plain
        text/css
        text/xml
        text/javascript
        application/json
        application/javascript
        application/xml+rss
        application/wasm
        font/woff2
        image/svg+xml;
    gzip_disable "MSIE [1-6]\.";
    
    # Brotli сжатие (если модуль установлен)
    # Установка: sudo apt install nginx-module-brotli
    # Раскомментируйте если установлен:
    # brotli on;
    # brotli_comp_level 6;
    # brotli_types text/plain text/css text/xml text/javascript application/json application/javascript application/wasm;
    
    # Кэширование статических файлов
    location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg|woff|woff2|ttf|eot)$ {
        expires 1y;
        add_header Cache-Control "public, immutable";
        access_log off;
    }
    
    # Кэширование HTML (короче, т.к. может меняться)
    location ~* \.html$ {
        expires 1h;
        add_header Cache-Control "public, must-revalidate";
    }
    
    # Основная локация
    location / {
        try_files $uri $uri/ /index.html;
        add_header X-Content-Type-Options "nosniff";
        add_header X-Frame-Options "DENY";
        add_header X-XSS-Protection "1; mode=block";
    }
    
    # Отключить логи для favicon
    location = /favicon.ico {
        log_not_found off;
        access_log off;
    }
    
    # Отключить логи для robots.txt
    location = /robots.txt {
        log_not_found off;
        access_log off;
    }
}
```

### 7. Активировать конфигурацию и перезагрузить Nginx:

```bash
# Активировать сайт
sudo ln -sf /etc/nginx/sites-available/ringo-uchet /etc/nginx/sites-enabled/

# Удалить дефолтный сайт (опционально)
sudo rm -f /etc/nginx/sites-enabled/default

# Проверить конфигурацию
sudo nginx -t

# Перезагрузить Nginx
sudo systemctl reload nginx

echo "✅ Nginx configured and reloaded!"
```

### 8. Проверить размер с учетом сжатия:

```bash
# Проверить реальный размер при передаче (с gzip)
curl -H "Accept-Encoding: gzip" -I https://your-domain.com 2>&1 | grep -i "content-length\|content-encoding"

# Или использовать онлайн инструмент:
# https://www.giftofspeed.com/gzip-test/
# https://tools.pingdom.com/
```

## 📊 Ожидаемые результаты

**Без сжатия на сервере:**
- Размер сборки: ~5-6 МБ

**С gzip сжатием (уровень 9):**
- Передаваемый размер: ~1.5-2.5 МБ (уменьшение на 60-70%)

**С brotli сжатием (если установлен):**
- Передаваемый размер: ~1-1.5 МБ (уменьшение на 70-80%)

## 🔧 Установка Brotli (опционально, для максимальной оптимизации)

```bash
# Установить модуль Brotli для Nginx
sudo apt update
sudo apt install nginx-module-brotli

# Обновить конфигурацию Nginx
sudo nano /etc/nginx/nginx.conf

# Добавить в начало файла (после user www-data;):
load_module modules/ngx_http_brotli_filter_module.so;
load_module modules/ngx_http_brotli_static_module.so;

# Перезагрузить Nginx
sudo systemctl reload nginx
```

## ✅ Чек-лист после деплоя

- [ ] Приложение открывается по HTTPS
- [ ] Все ресурсы загружаются корректно
- [ ] Gzip сжатие работает (проверить в DevTools → Network → Response Headers)
- [ ] Размер передаваемых файлов уменьшен
- [ ] Кэширование работает (проверить заголовки Cache-Control)
- [ ] Service Worker регистрируется (если используется)

## 🐛 Решение проблем

### Если размер все еще большой:

```bash
# Проверить что gzip включен
curl -H "Accept-Encoding: gzip" -I https://your-domain.com | grep -i "content-encoding"

# Должно быть: content-encoding: gzip

# Проверить размер файлов на диске
du -sh /var/www/ringo-uchet/*
```

### Если gzip не работает:

```bash
# Проверить логи Nginx
sudo tail -f /var/log/nginx/error.log

# Проверить что модуль gzip включен
nginx -V 2>&1 | grep -o with-http_gzip_module
```


# ⚡ Быстрый деплой с минимальным размером

## 🚀 Один скрипт для всего (Windows PowerShell)

```powershell
cd mobile
.\scripts\deploy-optimized.ps1 -ServerUser root -ServerIP 91.229.90.72
```

**Или с параметрами:**

```powershell
.\scripts\deploy-optimized.ps1 `
    -ServerUser root `
    -ServerIP 91.229.90.72 `
    -WebDir /var/www/ringo-uchet
```

---

## 📝 Пошагово (если нужен контроль)

### 1. Собрать и очистить:

```powershell
cd mobile
.\scripts\build-web-optimized.ps1

# Очистить лишние файлы
cd build\web
Get-ChildItem -Recurse -Filter "*.map" | Remove-Item -Force
Get-ChildItem -Recurse -Filter "NOTICES*" | Remove-Item -Force
```

### 2. Создать архив:

```powershell
cd ..\..
Compress-Archive -Path build\web\* -DestinationPath "build\web-optimized.zip" -CompressionLevel Optimal
```

### 3. Загрузить на сервер:

```powershell
scp build\web-optimized.zip root@91.229.90.72:/tmp/web-latest.zip
```

### 4. Развернуть на сервере:

```bash
ssh root@91.229.90.72

# Резервная копия
sudo mkdir -p /var/www/ringo-uchet-backup-$(date +%Y%m%d-%H%M%S)
sudo cp -r /var/www/ringo-uchet/* /var/www/ringo-uchet-backup-$(date +%Y%m%d-%H%M%S)/ 2>/dev/null || true

# Распаковка
sudo mkdir -p /var/www/ringo-uchet
sudo unzip -o /tmp/web-latest.zip -d /var/www/ringo-uchet/
sudo chown -R www-data:www-data /var/www/ringo-uchet
sudo chmod -R 755 /var/www/ringo-uchet
rm /tmp/web-latest.zip
```

### 5. Настроить Nginx (один раз):

```bash
# Скопировать конфигурацию
sudo cp /path/to/infra/nginx/web-optimized.conf /etc/nginx/sites-available/ringo-uchet

# Редактировать (заменить your-domain.com)
sudo nano /etc/nginx/sites-available/ringo-uchet

# Активировать
sudo ln -sf /etc/nginx/sites-available/ringo-uchet /etc/nginx/sites-enabled/
sudo nginx -t
sudo systemctl reload nginx
```

---

## 🎯 Ожидаемый результат

- **Размер сборки:** ~5-6 МБ (без сжатия)
- **С gzip:** ~1.5-2.5 МБ (передаваемый размер) ✅
- **С brotli:** ~1-1.5 МБ (передаваемый размер) ✅✅

---

## ✅ Проверка после деплоя

```bash
# Проверить что сайт работает
curl -I https://your-domain.com

# Проверить gzip сжатие
curl -H "Accept-Encoding: gzip" -I https://your-domain.com | grep -i "content-encoding"

# Должно быть: content-encoding: gzip
```

---

## 📚 Подробная документация

См. `DEPLOY_OPTIMIZED.md` для полной документации и конфигурации Nginx.


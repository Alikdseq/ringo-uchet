# 🔍 Проверка gzip на сервере

## Способ 1: Проверить конфигурацию Nginx (на сервере)

```bash
# Подключиться к серверу
ssh root@91.229.90.72

# Проверить основную конфигурацию
grep -i "gzip" /etc/nginx/nginx.conf

# Проверить конфигурацию сайта
grep -i "gzip" /etc/nginx/sites-enabled/ringo-uchet
# или
grep -i "gzip" /etc/nginx/conf.d/*.conf
```

**Что искать:**
- `gzip on;` - должно быть
- `gzip_types` - список типов файлов для сжатия
- `gzip_comp_level` - уровень сжатия (1-9)

---

## Способ 2: Проверить через браузер (DevTools)

1. Откройте сайт в браузере
2. Нажмите `F12` (DevTools)
3. Перейдите на вкладку **Network**
4. Обновите страницу (`Ctrl+R` или `F5`)
5. Кликните на файл `main.dart.js`
6. Посмотрите на **Response Headers**:
   - ✅ Должна быть строка: `content-encoding: gzip`
   - ✅ Размер в заголовке `content-length` должен быть меньше реального размера файла

**Пример:**
```
content-encoding: gzip
content-length: 1456789  (меньше чем 4.1 MB)
```

---

## Способ 3: Проверить через curl (с локального компьютера)

### Windows PowerShell:

```powershell
# Без gzip (показывает оригинальный размер)
curl.exe -I https://ringoouchet.ru/main.dart.js | Select-String "content-length"

# С gzip (показывает сжатый размер)
curl.exe -H "Accept-Encoding: gzip" -I https://ringoouchet.ru/main.dart.js | Select-String "content-length|content-encoding"
```

**Ожидаемый результат с gzip:**
```
content-encoding: gzip
content-length: 1456789  (меньше чем без gzip)
```

**Если gzip НЕ работает:**
```
content-length: 4163446  (оригинальный размер, gzip не применен)
```

---

## Способ 4: Быстрая проверка одной командой

```bash
# На сервере или локально (замените домен)
curl -H "Accept-Encoding: gzip" -I https://ringoouchet.ru/main.dart.js 2>&1 | grep -i "content-encoding"
```

**Результат:**
- ✅ `content-encoding: gzip` - gzip работает
- ❌ Нет такой строки - gzip не работает

---

## Если gzip НЕ включен - как включить

### Вариант 1: Проверить текущую конфигурацию сайта

```bash
# На сервере
cat /etc/nginx/sites-enabled/ringo-uchet
# или
cat /etc/nginx/conf.d/ringo-uchet.conf
```

### Вариант 2: Добавить gzip в конфигурацию

Откройте конфигурацию сайта:

```bash
sudo nano /etc/nginx/sites-enabled/ringo-uchet
```

Добавьте в блок `server { ... }` (после `index index.html;`):

```nginx
# Gzip сжатие
gzip on;
gzip_vary on;
gzip_proxied any;
gzip_comp_level 9;  # Максимальный уровень (1-9)
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
```

Или скопируйте готовую конфигурацию из `infra/nginx/web-optimized.conf`.

### Вариант 3: Применить изменения

```bash
# Проверить конфигурацию
sudo nginx -t

# Если проверка успешна - перезагрузить
sudo systemctl reload nginx

# Проверить что работает
curl -H "Accept-Encoding: gzip" -I https://ringoouchet.ru/main.dart.js | grep -i "content-encoding"
```

---

## Ожидаемые результаты

### С gzip:
- `main.dart.js`: ~4.1 MB → ~1.2-1.5 MB (уменьшение на ~65-70%)
- Общий размер страницы: ~4.1 MB → ~1.2-1.5 MB

### Без gzip:
- Все файлы передаются в оригинальном размере

---

## 📊 Пример проверки

```bash
# Размер без gzip
$ curl -I https://ringoouchet.ru/main.dart.js | grep content-length
content-length: 4163446

# Размер с gzip
$ curl -H "Accept-Encoding: gzip" -I https://ringoouchet.ru/main.dart.js | grep content-length
content-length: 1456789

# Проверка что gzip применен
$ curl -H "Accept-Encoding: gzip" -I https://ringoouchet.ru/main.dart.js | grep content-encoding
content-encoding: gzip
```

✅ Если видите `content-encoding: gzip` и размер меньше - gzip работает!


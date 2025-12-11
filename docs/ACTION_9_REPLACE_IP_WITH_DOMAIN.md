# ✅ ДЕЙСТВИЕ 9: ЗАМЕНА IP НА ДОМЕН В КОНФИГУРАЦИЯХ

## 🎯 ДАННЫЕ
- **Домен:** `ringoouchet.ru`
- **IP сервера:** `91.229.90.72`
- **DNS работает:** ✅ (проверено)

---

## 📋 ШАГ 1: ЗАМЕНА В BACKEND .ENV ФАЙЛЕ

### 1.1 Открыть .env файл

```bash
cd ~/ringo-uchet/backend
nano .env
```

### 1.2 Найти и заменить ALLOWED_HOSTS

**Найдите строку с `DJANGO_ALLOWED_HOSTS` или `ALLOWED_HOSTS`**

**Было:**
```env
DJANGO_ALLOWED_HOSTS=91.229.90.72
# или
ALLOWED_HOSTS=91.229.90.72
```

**Стало:**
```env
DJANGO_ALLOWED_HOSTS=ringoouchet.ru,www.ringoouchet.ru,91.229.90.72
# или
ALLOWED_HOSTS=ringoouchet.ru,www.ringoouchet.ru,91.229.90.72
```

**Важно:** Оставьте IP тоже (на случай временных проблем).

### 1.3 Проверить CORS_ALLOWED_ORIGINS (если есть)

**Если есть строка `CORS_ALLOWED_ORIGINS`, измените:**

**Было:**
```env
CORS_ALLOWED_ORIGINS=http://91.229.90.72
```

**Стало:**
```env
CORS_ALLOWED_ORIGINS=http://ringoouchet.ru,http://www.ringoouchet.ru,http://91.229.90.72
```

**Сохраните:** `Ctrl + O`, `Enter`, `Ctrl + X`

### 1.4 Перезапустить API

```bash
docker compose -f docker-compose.prod.yml restart api
```

---

## 📋 ШАГ 2: ЗАМЕНА В FLUTTER КОНФИГУРАЦИИ

### 2.1 На вашем компьютере откройте файл

`mobile/lib/core/config/app_config.dart`

### 2.2 Найти и изменить apiBaseUrl

**Найдите метод `static AppConfig get prod`:**

**Было (с IP):**
```dart
static AppConfig get prod => const AppConfig(
  flavor: AppFlavor.prod,
  apiBaseUrl: 'http://91.229.90.72:8001',
  // ...
);
```

**Стало (с доменом, пока HTTP, потом HTTPS):**
```dart
static AppConfig get prod => const AppConfig(
  flavor: AppFlavor.prod,
  apiBaseUrl: 'http://ringoouchet.ru',
  // ...
);
```

**Сохраните файл.**

### 2.3 Пересобрать Flutter Web

**На вашем компьютере в PowerShell:**

```powershell
cd C:\ringo-uchet\mobile
flutter clean
flutter build web --release --base-href /
```

### 2.4 Скопировать на сервер

```powershell
cd build
Compress-Archive -Path web\* -DestinationPath web-build.zip
scp web-build.zip root@91.229.90.72:~/web-build.zip
```

### 2.5 На сервере распаковать

```bash
cd ~
unzip -o web-build.zip -d /var/www/ringo-uchet/
sudo chown -R www-data:www-data /var/www/ringo-uchet
```

---

## 📋 ШАГ 3: ОБНОВЛЕНИЕ NGINX КОНФИГУРАЦИИ

### 3.1 Открыть конфигурацию

```bash
sudo nano /etc/nginx/sites-available/ringo-uchet
```

### 3.2 Заменить server_name

**Найдите строку:**
```nginx
server_name 91.229.90.72;
```

**Или если там IP, замените на:**
```nginx
server_name ringoouchet.ru www.ringoouchet.ru 91.229.90.72;
```

**Сохраните:** `Ctrl + O`, `Enter`, `Ctrl + X`

### 3.3 Проверить и перезагрузить

```bash
sudo nginx -t
sudo systemctl reload nginx
```

---

## 📋 ШАГ 4: ПРОВЕРКА РАБОТЫ С ДОМЕНОМ

### 4.1 Проверка фронтенда

```bash
curl http://ringoouchet.ru/
```

**Должен вернуть HTML код.**

**Или откройте в браузере:**
```
http://ringoouchet.ru
```

### 4.2 Проверка API

```bash
curl http://ringoouchet.ru/api/health/
```

**Должен вернуть ответ (даже если 301 - это нормально).**

---

## ✅ ЧЕКЛИСТ

- [ ] Backend .env обновлен (ALLOWED_HOSTS с доменом)
- [ ] Backend перезапущен
- [ ] Flutter конфигурация обновлена (apiBaseUrl с доменом)
- [ ] Flutter пересобран
- [ ] Flutter загружен на сервер
- [ ] Nginx конфигурация обновлена (server_name с доменом)
- [ ] Nginx перезагружен
- [ ] Фронтенд работает: `http://ringoouchet.ru`
- [ ] API работает: `http://ringoouchet.ru/api/health/`

---

## ⏭️ СЛЕДУЮЩИЙ ШАГ

**После выполнения всех шагов напишите:**
- ✅ **"Готово, IP заменен на домен"** - перейдем к настройке SSL

---

**Статус:** ⏳ Замена IP на домен

**Время выполнения:** 10-15 минут


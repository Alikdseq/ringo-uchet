# 🔧 ИСПРАВЛЕНИЕ: Flutter Web использует DEV вместо PROD

## ❌ ПРОБЛЕМА

**В `main_web.dart` используется `AppConfig.dev` (localhost:8001)!**

**Поэтому на телефоне запросы идут на `localhost`, который недоступен!**

---

## ✅ РЕШЕНИЕ

### ШАГ 1: Изменить `main_web.dart` на PROD

**Откройте файл:** `mobile/lib/main_web.dart`

**Измените строку 31:**
```dart
// БЫЛО:
appConfigProvider.overrideWithValue(AppConfig.dev),

// ДОЛЖНО БЫТЬ:
appConfigProvider.overrideWithValue(AppConfig.prod),
```

---

### ШАГ 2: Пересобрать Flutter Web

**На вашем компьютере (PowerShell):**

```powershell
cd C:\ringo-uchet\mobile
flutter clean
flutter build web --release --base-href /
```

⏱️ **Займет 3-5 минут**

---

### ШАГ 3: Создать архив и загрузить на сервер

**На вашем компьютере:**

```powershell
cd C:\ringo-uchet\mobile\build
Compress-Archive -Path web\* -DestinationPath web-build.zip -Force
scp web-build.zip root@91.229.90.72:~/web-build.zip
```

---

### ШАГ 4: На сервере - обновить файлы

**На сервере:**

```bash
cd ~
rm -rf /var/www/ringo-uchet/*
unzip -o web-build.zip -d /var/www/ringo-uchet/
mv /var/www/ringo-uchet/web/* /var/www/ringo-uchet/
rm -rf /var/www/ringo-uchet/web
sudo chown -R www-data:www-data /var/www/ringo-uchet
sudo chmod -R 755 /var/www/ringo-uchet
ls -la /var/www/ringo-uchet/index.html
```

---

### ШАГ 5: Очистить кеш на телефоне

**На телефоне:**
1. Откройте настройки браузера
2. Очистите данные сайта для `ringoouchet.ru`
3. Перезагрузите страницу

---

**Начнем с ШАГА 1 - изменим файл!**


# ✅ SSL РАБОТАЕТ! ФИНАЛЬНЫЕ ШАГИ

## ✅ HTTPS РАБОТАЕТ!

```
curl https://ringoouchet.ru/api/health/
```

**API отвечает по HTTPS!** ✅

---

## 📋 ФИНАЛЬНЫЙ ШАГ: ОБНОВИТЬ FLUTTER КОНФИГУРАЦИЮ

### ШАГ 1: Обновить apiBaseUrl на HTTPS

**На вашем компьютере откройте:**

`mobile/lib/core/config/app_config.dart`

**Найдите и измените:**

**Было:**
```dart
apiBaseUrl: 'http://ringoouchet.ru',
```

**Стало:**
```dart
apiBaseUrl: 'https://ringoouchet.ru',
```

**Сохраните файл.**

---

### ШАГ 2: Пересобрать Flutter Web

**На вашем компьютере в PowerShell:**

```powershell
cd C:\ringo-uchet\mobile
flutter clean
flutter build web --release --base-href /
```

---

### ШАГ 3: Скопировать на сервер

```powershell
cd build
Compress-Archive -Path web\* -DestinationPath web-build.zip
scp web-build.zip root@91.229.90.72:~/web-build.zip
```

---

### ШАГ 4: На сервере распаковать

```bash
cd ~
unzip -o web-build.zip -d /var/www/ringo-uchet/
sudo chown -R www-data:www-data /var/www/ringo-uchet
```

---

## ✅ ПРОВЕРКА

**Откройте в браузере:**
```
https://ringoouchet.ru
```

**Должно открываться с зеленым замочком!** 🔒

---

## 🎉 ГОТОВО!

**Приложение полностью развернуто с HTTPS!**

---

**Выполните шаги 1-4, затем проверьте в браузере!**


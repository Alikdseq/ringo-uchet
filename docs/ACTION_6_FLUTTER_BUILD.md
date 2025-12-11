# ✅ ДЕЙСТВИЕ 6: СБОРКА FLUTTER WEB ПРИЛОЖЕНИЯ

## 🎯 ЦЕЛЬ
Собрать Flutter Web приложение и загрузить на сервер.

---

## 📋 ШАГ 1: ПОДГОТОВКА НА ВАШЕМ КОМПЬЮТЕРЕ (Windows)

### 1.1 Переход в директорию mobile

**В PowerShell на вашем компьютере:**

```powershell
cd C:\ringo-uchet\mobile
```

### 1.2 Проверка Flutter

```powershell
flutter --version
```

**Должно показать версию Flutter (3.0+)**

### 1.3 Обновление зависимостей

```powershell
flutter pub get
```

### 1.4 Включение Web поддержки

```powershell
flutter config --enable-web
```

---

## 📋 ШАГ 2: НАСТРОЙКА API URL ДЛЯ PRODUCTION

### 2.1 Открыть файл конфигурации

Откройте в редакторе:
`mobile/lib/core/config/app_config.dart`

### 2.2 Найти production конфигурацию

Найдите метод `static AppConfig get prod` и измените `apiBaseUrl` на IP вашего сервера:

**Пример:**

```dart
static AppConfig get prod => const AppConfig(
  flavor: AppFlavor.prod,
  apiBaseUrl: 'http://ВАШ_IP:8001',  // ЗАМЕНИТЕ ВАШ_IP на реальный IP
  apiVersion: 'v1',
  enableLogging: false,
  enableCrashlytics: true,
  appName: 'Ringo Uchet',
  packageName: 'com.ringo.prod',
);
```

**Важно:** Используйте `http://` пока SSL не настроен. После настройки SSL измените на `https://`.

**Где взять IP?** Из панели Beget или командой на сервере: `hostname -I`

---

## 📋 ШАГ 3: СБОРКА FLUTTER WEB

### 3.1 Очистка предыдущих сборок

```powershell
flutter clean
```

### 3.2 Сборка для production

```powershell
flutter build web --release --base-href / --dart-define=FLUTTER_WEB_USE_SKIA=true
```

⏱️ **Займет 3-5 минут**

### 3.3 Проверка сборки

```powershell
ls build/web/
```

**Должны быть файлы:**
- `index.html`
- `main.dart.js`
- `flutter.js`
- `manifest.json`
- папка `assets/`

---

## 📋 ШАГ 4: КОПИРОВАНИЕ НА СЕРВЕР

### 4.1 Создание архива (на вашем компьютере)

```powershell
cd C:\ringo-uchet\mobile\build
tar -czf web-build.tar.gz web/
```

**Если tar не работает в PowerShell, используйте альтернативу:**

```powershell
# Установите 7-Zip или используйте встроенный Compress-Archive
Compress-Archive -Path web\* -DestinationPath web-build.zip
```

### 4.2 Копирование на сервер

**Узнайте IP вашего сервера из панели Beget, затем:**

```powershell
# Если использовали tar:
scp web-build.tar.gz root@ВАШ_IP:~/web-build.tar.gz

# Если использовали zip:
scp web-build.zip root@ВАШ_IP:~/web-build.zip
```

**Введите пароль root, когда попросит.**

---

## 📋 ШАГ 5: РАСПАКОВКА НА СЕРВЕРЕ

### 5.1 Подключитесь к серверу

```bash
ssh root@ВАШ_IP
```

### 5.2 Создайте директорию для фронтенда

```bash
sudo mkdir -p /var/www/ringo-uchet
```

### 5.3 Распакуйте архив

**Если tar.gz:**
```bash
cd ~
tar -xzf web-build.tar.gz -C /var/www/ringo-uchet --strip-components=1
```

**Если zip:**
```bash
cd ~
unzip web-build.zip -d /var/www/ringo-uchet
# Затем переместите содержимое
mv /var/www/ringo-uchet/web/* /var/www/ringo-uchet/
rm -rf /var/www/ringo-uchet/web
```

### 5.4 Настройка прав доступа

```bash
sudo chown -R www-data:www-data /var/www/ringo-uchet
sudo chmod -R 755 /var/www/ringo-uchet
```

---

## ✅ ПРОВЕРКА

```bash
ls -la /var/www/ringo-uchet/
```

**Должны быть файлы:**
- `index.html`
- `main.dart.js`
- `manifest.json`
- и другие

---

## ⏭️ СЛЕДУЮЩИЙ ШАГ

**После выполнения напишите:**
- ✅ **"Готово, Flutter Web собран и загружен на сервер"** - перейдем к настройке Nginx

---

**Статус:** ⏳ Сборка Flutter Web приложения

**Время выполнения:** 10-15 минут


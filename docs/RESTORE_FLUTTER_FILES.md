# 🔧 ВОССТАНОВЛЕНИЕ: Файлы Flutter Web удалены!

## ❌ ПРОБЛЕМА

**Файлы Flutter Web удалены - нужно восстановить!**

---

## ✅ РЕШЕНИЕ - ДВА ВАРИАНТА

---

## 🎯 ВАРИАНТ 1: Если архив еще есть на сервере

### ШАГ 1: Проверить есть ли архив

```bash
ls -la ~/*.zip ~/*.tar.gz
```

**Если видите `web-build.zip` или `web-build.tar.gz` - используйте вариант 1!**

---

### ШАГ 2: Распаковать архив

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

## 🎯 ВАРИАНТ 2: Пересобрать и загрузить заново

### ШАГ 1: На вашем компьютере - Пересобрать Flutter

**В PowerShell:**

```powershell
cd C:\ringo-uchet\mobile
flutter clean
flutter build web --release --base-href /
```

⏱️ **Займет 3-5 минут**

---

### ШАГ 2: Создать архив

```powershell
cd C:\ringo-uchet\mobile\build
Compress-Archive -Path web\* -DestinationPath web-build.zip -Force
```

---

### ШАГ 3: Загрузить на сервер

```powershell
scp web-build.zip root@91.229.90.72:~/web-build.zip
```

**Введите пароль root.**

---

### ШАГ 4: На сервере - Распаковать

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

## ✅ ПРОВЕРКА

```bash
ls -la /var/www/ringo-uchet/
```

**Должны быть:**
- ✅ `index.html`
- ✅ `main.dart.js`
- ✅ `manifest.json`
- ✅ `flutter_service_worker.js`

---

**Сначала проверьте вариант 1 - может архив еще есть!**


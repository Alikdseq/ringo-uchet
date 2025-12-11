# 🔧 ИСПРАВЛЕНИЕ: Файлы Flutter Web удалены!

## ❌ ПРОБЛЕМА

**Файлы Flutter Web удалены из `/var/www/ringo-uchet/`!**

**В логах:**
```
directory index of "/var/www/ringo-uchet/" is forbidden
index.html: No such file or directory
```

---

## ✅ БЫСТРОЕ РЕШЕНИЕ

### ШАГ 1: Проверить что осталось

```bash
ls -la /var/www/ringo-uchet/
```

**Что там есть?**

---

### ШАГ 2: Проверить есть ли архив на сервере

```bash
ls -la ~/*.zip
```

**Есть ли `web-build.zip` или другой архив?**

---

### ШАГ 3: Распаковать архив (если есть)

```bash
cd ~
unzip -o web-build.zip -d /var/www/ringo-uchet/
sudo chown -R www-data:www-data /var/www/ringo-uchet
```

---

### ШАГ 4: Если архива нет - загрузить заново

**На вашем компьютере пересоберите и загрузите:**

```powershell
cd C:\ringo-uchet\mobile
flutter clean
flutter build web --release --base-href /
cd build
Compress-Archive -Path web\* -DestinationPath web-build.zip
scp web-build.zip root@91.229.90.72:~/web-build.zip
```

**На сервере:**

```bash
cd ~
rm -rf /var/www/ringo-uchet/*
unzip -o web-build.zip -d /var/www/ringo-uchet/
sudo chown -R www-data:www-data /var/www/ringo-uchet
ls -la /var/www/ringo-uchet/index.html
```

---

**Выполните шаги 1-2 сначала - может архив еще есть!**


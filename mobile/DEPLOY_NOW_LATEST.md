# 🚀 Команды для деплоя фронтенда (актуальная сборка)

## ✅ Текущая сборка

- **Архив:** `web-optimized-20251217-163803.zip`
- **Размер архива:** 1.17 MB
- **Размер сборки:** 4.1 MB (несжатый)
- **Расположение:** `C:\ringo-uchet\mobile\build\web-optimized-20251217-163803.zip`

---

## 📤 ШАГ 1: Загрузить архив на сервер

**На вашем компьютере (PowerShell):**

```powershell
# Вариант 1: Абсолютный путь (работает из любой директории) - РЕКОМЕНДУЕТСЯ
scp C:\ringo-uchet\mobile\build\web-optimized-20251217-163803.zip root@91.229.90.72:~/web-build-latest.zip

# Вариант 2: Если вы в директории mobile\build
cd C:\ringo-uchet\mobile\build
scp web-optimized-20251217-163803.zip root@91.229.90.72:~/web-build-latest.zip
```

Введите пароль от сервера.

---

## 📋 ШАГ 2: Команды для выполнения на сервере

**Подключитесь к серверу:**
```powershell
ssh root@91.229.90.72
```

**Затем выполните эти команды на сервере:**

```bash
# 1. Создать резервную копию текущей версии
sudo mkdir -p /var/www/ringo-uchet-backup-$(date +%Y%m%d-%H%M%S)
sudo cp -r /var/www/ringo-uchet/* /var/www/ringo-uchet-backup-$(date +%Y%m%d-%H%M%S)/ 2>/dev/null || true

# 2. Распаковать новую версию
sudo mkdir -p /var/www/ringo-uchet
sudo unzip -o ~/web-build-latest.zip -d /var/www/ringo-uchet/

# 3. Установить правильные права
sudo chown -R www-data:www-data /var/www/ringo-uchet
sudo chmod -R 755 /var/www/ringo-uchet

# 4. Проверить конфигурацию Nginx и перезагрузить
sudo nginx -t && sudo systemctl reload nginx

# 5. Проверить что всё работает
curl -I https://ringoouchet.ru
```

---

## ⚡ Все команды на сервере одной строкой (для копирования)

```bash
sudo mkdir -p /var/www/ringo-uchet-backup-$(date +%Y%m%d-%H%M%S) && sudo cp -r /var/www/ringo-uchet/* /var/www/ringo-uchet-backup-$(date +%Y%m%d-%H%M%S)/ 2>/dev/null || true && sudo mkdir -p /var/www/ringo-uchet && sudo unzip -o ~/web-build-latest.zip -d /var/www/ringo-uchet/ && sudo chown -R www-data:www-data /var/www/ringo-uchet && sudo chmod -R 755 /var/www/ringo-uchet && sudo nginx -t && sudo systemctl reload nginx && curl -I https://ringoouchet.ru
```

---

## 🔍 Опционально: Проверка после деплоя

**На сервере:**

```bash
# Проверить что файлы распаковались
ls -lh /var/www/ringo-uchet/ | head -20

# Проверить размер
du -sh /var/www/ringo-uchet/

# Проверить что сайт работает
curl -I https://ringoouchet.ru

# Проверить gzip сжатие
curl -I -H "Accept-Encoding: gzip" https://ringoouchet.ru/main.dart.js
```

---

## ✅ Чеклист деплоя

- [ ] Архив загружен на сервер (`~/web-build-latest.zip`)
- [ ] Резервная копия создана
- [ ] Архив распакован в `/var/www/ringo-uchet/`
- [ ] Права установлены (www-data:www-data, 755)
- [ ] Nginx перезагружен
- [ ] Сайт работает (проверено через curl)
- [ ] Сайт открывается в браузере без ошибок

---

## 🎯 Быстрый деплой (если всё готово)

**1. На компьютере:**
```powershell
scp C:\ringo-uchet\mobile\build\web-optimized-20251217-163803.zip root@91.229.90.72:~/web-build-latest.zip
```

**2. На сервере:**
```bash
ssh root@91.229.90.72
```

**3. На сервере (одной командой):**
```bash
sudo mkdir -p /var/www/ringo-uchet-backup-$(date +%Y%m%d-%H%M%S) && sudo cp -r /var/www/ringo-uchet/* /var/www/ringo-uchet-backup-$(date +%Y%m%d-%H%M%S)/ 2>/dev/null || true && sudo mkdir -p /var/www/ringo-uchet && sudo unzip -o ~/web-build-latest.zip -d /var/www/ringo-uchet/ && sudo chown -R www-data:www-data /var/www/ringo-uchet && sudo chmod -R 755 /var/www/ringo-uchet && sudo nginx -t && sudo systemctl reload nginx
```

Готово! 🚀


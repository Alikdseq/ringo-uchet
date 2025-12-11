# 🚀 ПОЛНАЯ ИНСТРУКЦИЯ ПО ДЕПЛОЮ БЭКЕНДА И ФРОНТЕНДА

## 📋 СОДЕРЖАНИЕ

1. [Подготовка на локальном компьютере](#подготовка)
2. [Деплой бэкенда на сервер](#деплой-бэкенда)
3. [Деплой фронтенда на сервер](#деплой-фронтенда)
4. [Проверка работы](#проверка)
5. [Решение проблем](#решение-проблем)

---

## 🎯 ПОДГОТОВКА НА ЛОКАЛЬНОМ КОМПЬЮТЕРЕ

### ШАГ 1: Убедиться что все изменения закоммичены

**На вашем компьютере (PowerShell):**

```powershell
cd C:\ringo-uchet\backend
git status
```

Должно быть: `nothing to commit, working tree clean`

Если есть незакоммиченные изменения:
```powershell
git add .
git commit -m "Описание изменений"
git push origin master
```

---

### ШАГ 2: Собрать Flutter Web

**На вашем компьютере (PowerShell):**

```powershell
cd C:\ringo-uchet\mobile

# Обновить зависимости
flutter pub get

# Очистить старую сборку
flutter clean

# Собрать для production
flutter build web --release --base-href /
```

**Это займет 3-5 минут.**

---

### ШАГ 3: Очистить сборку от ненужных файлов

**На вашем компьютере (PowerShell):**

```powershell
cd C:\ringo-uchet\mobile\build\web

# Удалить debug символы
Get-ChildItem -Recurse -Filter "*.symbols" | Remove-Item -Force

# Удалить NOTICES файлы
Get-ChildItem -Recurse -Filter "NOTICES" | Remove-Item -Force

# Проверить размер (должен быть ~6-7 MB)
Get-ChildItem -Recurse -File | Measure-Object -Property Length -Sum | Select-Object @{Name="TotalSize(MB)";Expression={[math]::Round($_.Sum/1MB,2)}}
```

---

### ШАГ 4: Создать архив

**На вашем компьютере (PowerShell):**

```powershell
cd C:\ringo-uchet\mobile\build

# Создать архив
$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
Compress-Archive -Path web\* -DestinationPath "web-build-$timestamp.zip" -Force

# Найти последний архив
$latestArchive = Get-ChildItem web-build-*.zip | Sort-Object Name -Descending | Select-Object -First 1
Write-Host "Архив создан: $($latestArchive.Name)"
```

---

### ШАГ 5: Загрузить архив на сервер

**На вашем компьютере (PowerShell):**

```powershell
# Найти последний архив
$latestArchive = Get-ChildItem C:\ringo-uchet\mobile\build\web-build-*.zip | Sort-Object Name -Descending | Select-Object -First 1

# Загрузить на сервер
scp $latestArchive.FullName root@91.229.90.72:~/web-build-latest.zip
```

Введите пароль от сервера.

---

## 🎯 ДЕПЛОЙ БЭКЕНДА НА СЕРВЕР

### ШАГ 1: Подключиться к серверу

**На вашем компьютере (PowerShell):**

```powershell
ssh root@91.229.90.72
```

---

### ШАГ 2: Обновить код на сервере

**На сервере:**

```bash
cd ~/ringo-uchet/backend

# Обновить код из репозитория
git pull origin master

# Проверить что код обновлен
git log --oneline -3
```

---

### ШАГ 3: Создать резервную копию БД

**На сервере:**

```bash
cd ~/ringo-uchet/backend

# Создать резервную копию БД
docker compose -f docker-compose.prod.yml exec db pg_dump -U ringo_user ringo_prod > /root/backup-$(date +%Y%m%d-%H%M%S).sql

# Проверить что бэкап создан
ls -lh /root/backup-*.sql | tail -1
```

---

### ШАГ 4: Пересобрать и запустить контейнеры

**На сервере:**

```bash
cd ~/ringo-uchet/backend

# Остановить все контейнеры
docker compose -f docker-compose.prod.yml down

# Собрать образы
docker compose -f docker-compose.prod.yml build --no-cache

# Запустить контейнеры
docker compose -f docker-compose.prod.yml up -d

# Подождать запуска
sleep 20

# Проверить статус
docker compose -f docker-compose.prod.yml ps
```

**Должны быть запущены все 6 контейнеров:**
- `backend-db-1` - Up (healthy)
- `backend-redis-1` - Up (healthy)
- `backend-minio-1` - Up (healthy)
- `backend-api-1` - Up
- `backend-celery-worker-1` - Up
- `backend-celery-beat-1` - Up

---

### ШАГ 5: Применить миграции

**На сервере:**

```bash
cd ~/ringo-uchet/backend

# Применить миграции
docker compose -f docker-compose.prod.yml exec api python manage.py migrate

# Собрать статические файлы
docker compose -f docker-compose.prod.yml exec api python manage.py collectstatic --noinput
```

---

### ШАГ 6: Проверить что API работает

**На сервере:**

```bash
# Проверить health endpoint
curl http://localhost:8001/api/health/

# Должен вернуть: {"status": "ok"} или {"status": "healthy"}

# Проверить логи если нужно
docker compose -f docker-compose.prod.yml logs api --tail 30
```

---

## 🎯 ДЕПЛОЙ ФРОНТЕНДА НА СЕРВЕР

### ШАГ 1: Создать резервную копию текущей версии

**На сервере:**

```bash
# Создать резервную копию
sudo mkdir -p /var/www/ringo-uchet-backup-$(date +%Y%m%d-%H%M%S)
sudo cp -r /var/www/ringo-uchet/* /var/www/ringo-uchet-backup-$(date +%Y%m%d-%H%M%S)/ 2>/dev/null || true

echo "✅ Резервная копия создана"
```

---

### ШАГ 2: Распаковать новую версию

**На сервере:**

```bash
cd ~

# Проверить что архив загружен
ls -lh web-build-latest.zip

# Распаковать во временную директорию
unzip -o web-build-latest.zip -d /tmp/flutter-web-new/

# Проверить что файлы распакованы
ls -la /tmp/flutter-web-new/ | head -20
```

---

### ШАГ 3: Обновить файлы на сервере

**На сервере:**

```bash
# Очистить старые файлы
sudo rm -rf /var/www/ringo-uchet/*

# Переместить новые файлы
sudo mv /tmp/flutter-web-new/web/* /var/www/ringo-uchet/ 2>/dev/null || sudo mv /tmp/flutter-web-new/* /var/www/ringo-uchet/

# Установить правильные права
sudo chown -R www-data:www-data /var/www/ringo-uchet
sudo chmod -R 755 /var/www/ringo-uchet

# Проверить что файлы на месте
ls -la /var/www/ringo-uchet/ | head -20
```

---

### ШАГ 4: Проверить service-worker.js

**На сервере:**

```bash
# Проверить наличие файла
ls -la /var/www/ringo-uchet/service-worker.js

# Проверить права доступа
sudo chmod 644 /var/www/ringo-uchet/service-worker.js
sudo chown www-data:www-data /var/www/ringo-uchet/service-worker.js
```

---

### ШАГ 5: Перезагрузить Nginx

**На сервере:**

```bash
# Проверить конфигурацию Nginx
sudo nginx -t

# Если все ОК, перезагрузить
sudo systemctl reload nginx

# Очистить кэш Nginx
sudo rm -rf /var/cache/nginx/*
sudo systemctl reload nginx

echo "✅ Nginx перезагружен"
```

---

## ✅ ПРОВЕРКА РАБОТЫ

### ШАГ 1: Проверить Backend API

**На сервере:**

```bash
# Проверить health endpoint локально
curl http://localhost:8001/api/health/

# Проверить через Nginx
curl https://ringoouchet.ru/api/health/

# Должен вернуть: {"status": "ok"} или {"status": "healthy"}
```

---

### ШАГ 2: Проверить Frontend

**На вашем компьютере:**

1. Откройте браузер
2. Перейдите на `https://ringoouchet.ru`
3. Откройте DevTools (F12)
4. Проверьте:
   - ✅ Нет ошибок в консоли
   - ✅ Service Worker зарегистрирован
   - ✅ API запросы успешны (200 OK)
   - ✅ Нет ошибок 502 Bad Gateway

---

### ШАГ 3: Функциональное тестирование

1. **Аутентификация:**
   - Войти в систему
   - Проверить что токен сохраняется
   - Проверить что запросы авторизованы

2. **Заявки:**
   - Создать заявку
   - Редактировать заявку (для админа)
   - Изменить статус заявки
   - Удалить заявку (для админа/менеджера)

3. **Каталог:**
   - Просмотреть каталог техники
   - Просмотреть услуги
   - Просмотреть материалы

---

## 🚀 БЫСТРАЯ КОМАНДА (ВСЕ СРАЗУ)

### На вашем компьютере:

```powershell
# 1. Запушить изменения
cd C:\ringo-uchet\backend
git push origin master

# 2. Собрать Flutter Web
cd C:\ringo-uchet\mobile
flutter clean
flutter build web --release --base-href /

# 3. Очистить сборку
cd build\web
Get-ChildItem -Recurse -Filter "*.symbols" | Remove-Item -Force
Get-ChildItem -Recurse -Filter "NOTICES" | Remove-Item -Force

# 4. Создать архив
cd ..
$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
Compress-Archive -Path web\* -DestinationPath "web-build-$timestamp.zip" -Force

# 5. Загрузить на сервер
$latestArchive = Get-ChildItem web-build-*.zip | Sort-Object Name -Descending | Select-Object -First 1
scp $latestArchive.FullName root@91.229.90.72:~/web-build-latest.zip
```

### На сервере:

```bash
# 1. Обновить код бэкенда
cd ~/ringo-uchet/backend
git pull origin master

# 2. Создать бэкап БД
docker compose -f docker-compose.prod.yml exec db pg_dump -U ringo_user ringo_prod > /root/backup-$(date +%Y%m%d-%H%M%S).sql

# 3. Пересобрать и запустить контейнеры
docker compose -f docker-compose.prod.yml down
docker compose -f docker-compose.prod.yml build --no-cache
docker compose -f docker-compose.prod.yml up -d
sleep 20

# 4. Применить миграции
docker compose -f docker-compose.prod.yml exec api python manage.py migrate
docker compose -f docker-compose.prod.yml exec api python manage.py collectstatic --noinput

# 5. Обновить фронтенд
sudo mkdir -p /var/www/ringo-uchet-backup-$(date +%Y%m%d-%H%M%S)
sudo cp -r /var/www/ringo-uchet/* /var/www/ringo-uchet-backup-$(date +%Y%m%d-%H%M%S)/ 2>/dev/null || true
unzip -o ~/web-build-latest.zip -d /tmp/flutter-web-new/
sudo rm -rf /var/www/ringo-uchet/*
sudo mv /tmp/flutter-web-new/web/* /var/www/ringo-uchet/ 2>/dev/null || sudo mv /tmp/flutter-web-new/* /var/www/ringo-uchet/
sudo chown -R www-data:www-data /var/www/ringo-uchet
sudo chmod -R 755 /var/www/ringo-uchet

# 6. Перезагрузить Nginx
sudo nginx -t && sudo systemctl reload nginx
sudo rm -rf /var/cache/nginx/*

# 7. Проверить работу
curl http://localhost:8001/api/health/
curl https://ringoouchet.ru/api/health/
docker compose -f docker-compose.prod.yml ps
```

---

## 🔧 РЕШЕНИЕ ПРОБЛЕМ

### Проблема: Контейнеры не запускаются

```bash
cd ~/ringo-uchet/backend
docker compose -f docker-compose.prod.yml logs
docker compose -f docker-compose.prod.yml ps
```

### Проблема: API не отвечает (502 Bad Gateway)

```bash
# Проверить что контейнеры запущены
docker compose -f docker-compose.prod.yml ps api

# Проверить логи
docker compose -f docker-compose.prod.yml logs api --tail 50

# Проверить что API работает локально
curl http://localhost:8001/api/health/

# Проверить конфигурацию Nginx
sudo nginx -t
sudo tail -50 /var/log/nginx/error.log
```

### Проблема: Frontend не загружается

```bash
# Проверить что файлы на месте
ls -la /var/www/ringo-uchet/

# Проверить права
sudo chown -R www-data:www-data /var/www/ringo-uchet
sudo chmod -R 755 /var/www/ringo-uchet

# Проверить Nginx
sudo nginx -t
sudo systemctl status nginx
sudo tail -f /var/log/nginx/error.log
```

---

## 📋 КОНТРОЛЬНЫЙ СПИСОК ДЕПЛОЯ

### Перед деплоем:
- [ ] Все изменения закоммичены и запушены
- [ ] Flutter Web пересобран
- [ ] Сборка очищена от ненужных файлов
- [ ] Архив создан и загружен на сервер

### На сервере:
- [ ] Код бэкенда обновлен
- [ ] Резервная копия БД создана
- [ ] Docker образы собраны
- [ ] Контейнеры запущены (все 6)
- [ ] Миграции применены
- [ ] Frontend файлы обновлены
- [ ] Nginx перезагружен

### После деплоя:
- [ ] API отвечает на запросы
- [ ] Frontend загружается
- [ ] Нет ошибок в логах
- [ ] Все функции работают
- [ ] Нет ошибок 502 Bad Gateway

---

**Начните с подготовки на локальном компьютере!** 🚀


# 🚀 ПОЛНЫЙ ДЕПЛОЙ БЭКЕНДА И ФРОНТЕНДА

## 📋 ЧТО БУДЕТ ЗАДЕПЛОЕНО

1. **Backend (Django)** - API сервер
2. **Frontend (Flutter Web)** - Веб-приложение

---

## 🎯 ЭТАП 1: ПОДГОТОВКА НА ЛОКАЛЬНОМ КОМПЬЮТЕРЕ

### ШАГ 1.1: Убедиться что все изменения закоммичены

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
```

### ШАГ 1.2: Запушить изменения в репозиторий

```powershell
cd C:\ringo-uchet\backend
git push origin master
```

Если будет ошибка с паролем - используйте Personal Access Token вместо пароля.

---

## 🎯 ЭТАП 2: ДЕПЛОЙ БЭКЕНДА НА СЕРВЕР

### ШАГ 2.1: Подключиться к серверу

**На вашем компьютере (PowerShell):**

```powershell
ssh root@91.229.90.72
```

Введите пароль от сервера.

### ШАГ 2.2: Обновить код на сервере

**На сервере:**

```bash
cd ~/ringo-uchet/backend

# Обновить код из репозитория
git pull origin master

# Проверить что код обновлен
git log --oneline -3
```

### ШАГ 2.3: Создать резервную копию БД

**На сервере:**

```bash
cd ~/ringo-uchet/backend

# Создать резервную копию БД
docker compose -f docker-compose.prod.yml exec db pg_dump -U ringo_user ringo_prod > /root/backup-$(date +%Y%m%d-%H%M%S).sql

# Проверить что бэкап создан
ls -lh /root/backup-*.sql | tail -1
```

### ШАГ 2.4: Проверить переменные окружения

**На сервере:**

```bash
cd ~/ringo-uchet/backend

# Проверить что .env файл существует
ls -la .env

# Проверить основные переменные
cat .env | grep -E "DB_|CELERY_|DJANGO_|MINIO_"
```

**Если .env файла нет, создайте его:**

```bash
cd ~/ringo-uchet/backend

# Создать .env файл (замените значения на свои)
cat > .env << 'EOF'
# Database
DB_HOST=db
DB_PORT=5432
DB_NAME=ringo_prod
DB_USER=ringo_user
DB_PASSWORD=ваш_пароль_бд

# Celery
CELERY_BROKER_URL=redis://redis:6379/0
CELERY_RESULT_BACKEND=redis://redis:6379/0

# MinIO/S3
AWS_S3_ENDPOINT_URL=http://minio:9000
AWS_ACCESS_KEY_ID=minioadmin
AWS_SECRET_ACCESS_KEY=minioadmin
AWS_BUCKET=ringo-media
MINIO_ROOT_USER=minioadmin
MINIO_ROOT_PASSWORD=minioadmin

# Django
DJANGO_SECRET_KEY=ваш_секретный_ключ_django
EOF
```

### ШАГ 2.5: Остановить старые контейнеры

**На сервере:**

```bash
cd ~/ringo-uchet/backend

# Остановить все контейнеры
docker compose -f docker-compose.prod.yml down

# Проверить что все остановлено
docker compose -f docker-compose.prod.yml ps
```

### ШАГ 2.6: Собрать Docker образы

**На сервере:**

```bash
cd ~/ringo-uchet/backend

# Собрать образы
docker compose -f docker-compose.prod.yml build --no-cache

# Это займет 3-5 минут, подождите завершения
```

### ШАГ 2.7: Запустить контейнеры

**На сервере:**

```bash
cd ~/ringo-uchet/backend

# Запустить все сервисы
docker compose -f docker-compose.prod.yml up -d

# Подождать 15 секунд для запуска
sleep 15

# Проверить статус
docker compose -f docker-compose.prod.yml ps
```

**Должны быть запущены:**
- `backend-db-1` - Up (healthy)
- `backend-redis-1` - Up (healthy)
- `backend-minio-1` - Up (healthy)
- `backend-api-1` - Up
- `backend-celery-worker-1` - Up
- `backend-celery-beat-1` - Up

### ШАГ 2.8: Проверить логи API

**На сервере:**

```bash
cd ~/ringo-uchet/backend

# Проверить логи API
docker compose -f docker-compose.prod.yml logs api --tail 50
```

**Должно быть:**
- Нет критических ошибок
- Видны строки "Starting gunicorn"
- Видны строки "Booting worker"

### ШАГ 2.9: Применить миграции БД

**На сервере:**

```bash
cd ~/ringo-uchet/backend

# Проверить статус миграций
docker compose -f docker-compose.prod.yml exec api python manage.py showmigrations

# Применить миграции (если есть непримененные)
docker compose -f docker-compose.prod.yml exec api python manage.py migrate

# Собрать статические файлы
docker compose -f docker-compose.prod.yml exec api python manage.py collectstatic --noinput
```

### ШАГ 2.10: Проверить что API работает

**На сервере:**

```bash
# Проверить health endpoint
curl http://localhost:8001/api/health/

# Должен вернуть: {"status": "ok"}
```

---

## 🎯 ЭТАП 3: ДЕПЛОЙ ФРОНТЕНДА (FLUTTER WEB)

### ШАГ 3.1: Собрать Flutter Web на вашем компьютере

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

### ШАГ 3.2: Очистить сборку от ненужных файлов

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

### ШАГ 3.3: Создать архив

**На вашем компьютере (PowerShell):**

```powershell
cd C:\ringo-uchet\mobile\build

# Создать архив
$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
Compress-Archive -Path web\* -DestinationPath "web-build-$timestamp.zip" -Force

# Проверить размер архива
Get-Item "web-build-$timestamp.zip" | Select-Object Name, @{Name="Size(MB)";Expression={[math]::Round($_.Length/1MB,2)}}
```

### ШАГ 3.4: Загрузить архив на сервер

**На вашем компьютере (PowerShell):**

```powershell
# Найти последний созданный архив
$latestArchive = Get-ChildItem C:\ringo-uchet\mobile\build\web-build-*.zip | Sort-Object Name -Descending | Select-Object -First 1

# Загрузить на сервер
scp $latestArchive.FullName root@91.229.90.72:~/web-build-latest.zip
```

Введите пароль от сервера.

---

## 🎯 ЭТАП 4: УСТАНОВКА ФРОНТЕНДА НА СЕРВЕР

### ШАГ 4.1: Подключиться к серверу

**На вашем компьютере (PowerShell):**

```powershell
ssh root@91.229.90.72
```

### ШАГ 4.2: Создать резервную копию текущей версии

**На сервере:**

```bash
# Создать резервную копию
sudo mkdir -p /var/www/ringo-uchet-backup-$(date +%Y%m%d-%H%M%S)
sudo cp -r /var/www/ringo-uchet/* /var/www/ringo-uchet-backup-$(date +%Y%m%d-%H%M%S)/ 2>/dev/null || true

echo "✅ Резервная копия создана"
```

### ШАГ 4.3: Распаковать новую версию

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

### ШАГ 4.4: Обновить файлы на сервере

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

### ШАГ 4.5: Проверить service-worker.js

**На сервере:**

```bash
# Проверить наличие файла
ls -la /var/www/ringo-uchet/service-worker.js

# Проверить права доступа
sudo chmod 644 /var/www/ringo-uchet/service-worker.js
sudo chown www-data:www-data /var/www/ringo-uchet/service-worker.js
```

### ШАГ 4.6: Перезагрузить Nginx

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

## 🎯 ЭТАП 5: ПРОВЕРКА РАБОТЫ

### ШАГ 5.1: Проверить Backend API

**На сервере:**

```bash
# Проверить health endpoint
curl http://localhost:8001/api/health/

# Должен вернуть: {"status": "ok"}

# Проверить что API доступен извне
curl https://ringoouchet.ru/api/health/
```

### ШАГ 5.2: Проверить Frontend

**На вашем компьютере:**

1. Откройте браузер
2. Перейдите на `https://ringoouchet.ru`
3. Откройте DevTools (F12)
4. Проверьте:
   - Нет ошибок в консоли
   - Service Worker зарегистрирован
   - API запросы успешны (200 OK)

### ШАГ 5.3: Проверить логи

**На сервере:**

```bash
cd ~/ringo-uchet/backend

# Проверить логи API
docker compose -f docker-compose.prod.yml logs api --tail 30

# Проверить логи Nginx
sudo tail -f /var/log/nginx/error.log
```

---

## 📋 БЫСТРАЯ КОМАНДА (ВСЕ СРАЗУ)

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
sleep 15

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
docker compose -f docker-compose.prod.yml ps
```

---

## ✅ КОНТРОЛЬНЫЙ СПИСОК

### Перед деплоем:
- [ ] Все изменения закоммичены
- [ ] Изменения запушены в репозиторий
- [ ] Flutter Web пересобран
- [ ] Сборка очищена от ненужных файлов
- [ ] Архив создан

### На сервере:
- [ ] Код бэкенда обновлен
- [ ] Резервная копия БД создана
- [ ] Docker образы собраны
- [ ] Контейнеры запущены
- [ ] Миграции применены
- [ ] Frontend файлы обновлены
- [ ] Nginx перезагружен

### После деплоя:
- [ ] API отвечает на запросы
- [ ] Frontend загружается
- [ ] Нет ошибок в логах
- [ ] Все функции работают

---

## 🔧 ЕСЛИ ЧТО-ТО ПОШЛО НЕ ТАК

### Проблема: Контейнеры не запускаются

```bash
cd ~/ringo-uchet/backend
docker compose -f docker-compose.prod.yml logs
docker compose -f docker-compose.prod.yml ps
```

### Проблема: API не отвечает

```bash
curl http://localhost:8001/api/health/
docker compose -f docker-compose.prod.yml logs api --tail 50
```

### Проблема: Frontend не загружается

```bash
ls -la /var/www/ringo-uchet/
sudo nginx -t
sudo tail -f /var/log/nginx/error.log
```

---

**Начните с ЭТАПА 1 - подготовка на локальном компьютере!** 🚀


# 🔍 ПОЛНЫЙ ПЛАН ПРОВЕРКИ И ДЕПЛОЯ ПРОЕКТА RINGO UCHET

## 📋 СОДЕРЖАНИЕ

1. [Анализ проблем из терминала](#анализ-проблем)
2. [Проверка кода на профессиональность](#проверка-кода)
3. [Проверка совместимости компонентов](#проверка-совместимости)
4. [Проверка работы БД и API](#проверка-бд-и-api)
5. [Проверка связи фронтенда и бэкенда](#проверка-связи)
6. [Исправление найденных проблем](#исправление-проблем)
7. [Полная инструкция по деплою](#инструкция-по-деплою)

---

## 🔴 АНАЛИЗ ПРОБЛЕМ ИЗ ТЕРМИНАЛА

### Проблема 1: Docker Registry Error - "invalid repository name"

**Ошибка:**
```
Error response from daemon: error from registry: invalid repository name
```

**Причина:**
- В `docker-compose.prod.yml` используется `image: ${DOCKER_REGISTRY:-ghcr.io}/${IMAGE_NAME:-ringo-backend}:${IMAGE_TAG:-latest}`
- Образ `ghcr.io/ringo-backend:latest` не существует в GitHub Container Registry
- Переменные окружения `DOCKER_REGISTRY`, `IMAGE_NAME`, `IMAGE_TAG` не установлены

**Решение:**
1. **Вариант A (Рекомендуется):** Использовать локальную сборку образа
2. **Вариант B:** Собрать и загрузить образ в registry
3. **Вариант C:** Использовать существующий локальный образ

### Проблема 2: Many-to-Many Field Error

**Ошибка:**
```
TypeError: Direct assignment to the forward side of a many-to-many set is prohibited. Use operators.set() instead.
```

**Причина:**
- В логах видна ошибка на строке 318 в `orders/serializers.py`
- В текущем коде уже исправлено (используется `.set()` на строке 350)
- **Проблема:** В контейнере запущена старая версия кода

**Решение:**
- Перезапустить контейнеры с обновленным кодом
- Убедиться что volumes монтируют актуальный код

### Проблема 3: Отсутствие сервиса БД в docker-compose.prod.yml

**Проблема:**
- В `docker-compose.prod.yml` нет определения сервиса `db`
- Используются переменные `${DB_HOST}`, `${DB_PORT}`, `${DB_NAME}`, `${DB_USER}`, `${DB_PASSWORD}`
- БД должна быть определена отдельно или использоваться внешняя

**Решение:**
- Добавить сервис `db` в `docker-compose.prod.yml` или использовать внешнюю БД

### Проблема 4: Git Authentication Failed

**Ошибка:**
```
remote: Invalid username or token. Password authentication is not supported for Git operations.
```

**Причина:**
- Использование пароля вместо токена для GitHub
- GitHub не поддерживает пароли с 2021 года

**Решение:**
- Использовать Personal Access Token (PAT) вместо пароля
- Настроить SSH ключи для Git

---

## ✅ ПРОВЕРКА КОДА НА ПРОФЕССИОНАЛЬНОСТЬ

### 1. Backend (Django)

#### ✅ Архитектура
- ✅ Правильная структура проекта (apps разделены по доменам)
- ✅ Использование Django REST Framework
- ✅ Настройки разделены по окружениям (base, local, prod)
- ✅ Использование миграций
- ✅ Правильная работа с Many-to-Many полями (исправлено)

#### ✅ Безопасность
- ✅ JWT аутентификация
- ✅ CORS настройки
- ✅ CSRF защита
- ✅ RBAC (Role-Based Access Control)
- ✅ Audit logging
- ✅ Middleware для безопасности (SQL injection, XSS, SSRF protection)

#### ✅ Производительность
- ✅ Использование select_related и prefetch_related
- ✅ Индексы в БД
- ✅ Celery для фоновых задач
- ✅ Кэширование через Redis

#### ⚠️ Найденные проблемы:
1. **Docker образ не собирается локально** - нужно добавить `build` секцию
2. **Отсутствует сервис БД** в production compose файле
3. **Workers в gunicorn:** 4 workers могут быть избыточны для небольшого проекта

### 2. Frontend (Flutter)

#### ✅ Архитектура
- ✅ Использование Riverpod для state management
- ✅ Разделение на features
- ✅ Правильная структура проекта
- ✅ Настройки для разных окружений (dev, stage, prod)

#### ✅ Сетевое взаимодействие
- ✅ Dio клиент с interceptors
- ✅ Retry логика
- ✅ Обработка ошибок
- ✅ Offline поддержка

#### ✅ UI/UX
- ✅ Material Design
- ✅ Локализация (RU)
- ✅ Адаптивность

#### ⚠️ Найденные проблемы:
1. **API Base URL:** Использует `https://ringoouchet.ru/api/v1` - нужно убедиться что путь правильный
2. **Service Worker:** Нужно проверить что v2 правильно работает

---

## 🔗 ПРОВЕРКА СОВМЕСТИМОСТИ КОМПОНЕНТОВ

### Backend ↔ Frontend

#### API Endpoints
- ✅ `/api/v1/token/` - JWT аутентификация
- ✅ `/api/v1/orders/` - CRUD операции с заявками
- ✅ `/api/v1/orders/{id}/delete/` - Удаление заявок
- ✅ `/api/v1/equipment/` - Каталог техники
- ✅ `/api/v1/clients/` - Клиенты
- ✅ `/api/v1/reports/` - Отчеты

#### CORS настройки
- ✅ `CORS_ALLOW_ALL_ORIGINS=true` в production (временно)
- ✅ Регулярные выражения для localhost в dev
- ✅ Правильные `CSRF_TRUSTED_ORIGINS`

#### Версионирование API
- ✅ Используется `/api/v1/` - правильно

### База данных

#### PostgreSQL
- ✅ Версия: 15-alpine
- ✅ Правильные настройки подключения
- ✅ Использование DATABASE_URL для обхода проблем с Unicode

#### Миграции
- ✅ Миграции созданы для всех моделей
- ⚠️ Нужно проверить что все миграции применены в production

### Docker

#### Сервисы
- ✅ API (Django)
- ✅ Celery Worker
- ✅ Celery Beat
- ⚠️ **Отсутствует:** DB, Redis, MinIO в production compose

---

## 🗄️ ПРОВЕРКА РАБОТЫ БД И API

### Проверка БД

#### Команды для проверки:

```bash
# На сервере
cd ~/ringo-uchet/backend

# Проверить подключение к БД
docker compose -f docker-compose.prod.yml exec db psql -U ringo_user -d ringo_prod -c "SELECT version();"

# Проверить таблицы
docker compose -f docker-compose.prod.yml exec db psql -U ringo_user -d ringo_prod -c "\dt"

# Проверить миграции Django
docker compose -f docker-compose.prod.yml exec api python manage.py showmigrations

# Применить миграции (если нужно)
docker compose -f docker-compose.prod.yml exec api python manage.py migrate
```

### Проверка API

#### Health Check

```bash
# Проверить health endpoint
curl https://ringoouchet.ru/api/health/

# Должен вернуть: {"status": "ok"}
```

#### Проверка аутентификации

```bash
# Получить токен
curl -X POST https://ringoouchet.ru/api/v1/token/ \
  -H "Content-Type: application/json" \
  -d '{"phone": "+79991234567", "password": "password"}'

# Использовать токен
curl https://ringoouchet.ru/api/v1/orders/ \
  -H "Authorization: Bearer YOUR_ACCESS_TOKEN"
```

#### Проверка endpoints

```bash
# Список заявок
curl https://ringoouchet.ru/api/v1/orders/ \
  -H "Authorization: Bearer YOUR_TOKEN"

# Детали заявки
curl https://ringoouchet.ru/api/v1/orders/{id}/ \
  -H "Authorization: Bearer YOUR_TOKEN"

# Удаление заявки
curl -X POST https://ringoouchet.ru/api/v1/orders/{id}/delete/ \
  -H "Authorization: Bearer YOUR_TOKEN"
```

---

## 🌐 ПРОВЕРКА СВЯЗИ ФРОНТЕНДА И БЭКЕНДА

### Конфигурация API

#### Frontend (Flutter)
- **Production URL:** `https://ringoouchet.ru/api/v1`
- **Dev URL:** `http://localhost:8001/api/v1`

#### Backend (Django)
- **Production:** `https://ringoouchet.ru`
- **API Path:** `/api/v1/`

### Проверка CORS

```bash
# Проверить CORS headers
curl -I -X OPTIONS https://ringoouchet.ru/api/v1/orders/ \
  -H "Origin: https://ringoouchet.ru" \
  -H "Access-Control-Request-Method: GET"

# Должны быть headers:
# Access-Control-Allow-Origin: *
# Access-Control-Allow-Methods: GET, POST, PUT, PATCH, DELETE, OPTIONS
```

### Проверка работы фронтенда

1. **Открыть сайт:** `https://ringoouchet.ru`
2. **Проверить консоль браузера (F12):**
   - Нет ошибок CORS
   - API запросы успешны (200 OK)
   - Токены сохраняются и используются

3. **Проверить Network tab:**
   - Все запросы к `/api/v1/` успешны
   - Правильные headers (Authorization, Content-Type)

---

## 🔧 ИСПРАВЛЕНИЕ НАЙДЕННЫХ ПРОБЛЕМ

### Исправление 1: Docker Compose для Production

**Файл:** `backend/docker-compose.prod.yml`

**Проблема:** Отсутствует сервис БД и используется несуществующий образ

**Решение:** Добавить сервисы БД, Redis, MinIO и использовать локальную сборку

```yaml
version: '3.8'

services:
  db:
    image: postgres:15-alpine
    restart: unless-stopped
    environment:
      POSTGRES_DB: ${DB_NAME:-ringo_prod}
      POSTGRES_USER: ${DB_USER:-ringo_user}
      POSTGRES_PASSWORD: ${DB_PASSWORD}
    volumes:
      - postgres_data:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U ${DB_USER:-ringo_user}"]
      interval: 10s
      timeout: 5s
      retries: 5
    networks:
      - ringo-net

  redis:
    image: redis:7-alpine
    restart: unless-stopped
    command: redis-server --save 20 1 --loglevel warning
    volumes:
      - redis_data:/data
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 10s
      timeout: 5s
      retries: 5
    networks:
      - ringo-net

  minio:
    image: quay.io/minio/minio:latest
    restart: unless-stopped
    command: server /data --console-address ":9001"
    environment:
      MINIO_ROOT_USER: ${MINIO_ROOT_USER:-minioadmin}
      MINIO_ROOT_PASSWORD: ${MINIO_ROOT_PASSWORD:-minioadmin}
    volumes:
      - minio_data:/data
    ports:
      - "9000:9000"
      - "9001:9001"
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:9000/minio/health/live"]
      interval: 30s
      timeout: 20s
      retries: 3
    networks:
      - ringo-net

  api:
    build:
      context: .
      dockerfile: Dockerfile
    image: backend-api:latest
    restart: unless-stopped
    volumes:
      - ./orders:/app/orders:ro
      - ./ringo_backend:/app/ringo_backend:ro
      - ./staticfiles:/app/staticfiles
      - ./media:/app/media
    environment:
      - DJANGO_SETTINGS_MODULE=ringo_backend.settings.prod
      - POSTGRES_HOST=db
      - POSTGRES_PORT=5432
      - POSTGRES_DB=${DB_NAME:-ringo_prod}
      - POSTGRES_USER=${DB_USER:-ringo_user}
      - POSTGRES_PASSWORD=${DB_PASSWORD}
      - CELERY_BROKER_URL=redis://redis:6379/0
      - CELERY_RESULT_BACKEND=redis://redis:6379/0
      - AWS_S3_ENDPOINT_URL=http://minio:9000
      - AWS_ACCESS_KEY_ID=${MINIO_ROOT_USER:-minioadmin}
      - AWS_SECRET_ACCESS_KEY=${MINIO_ROOT_PASSWORD:-minioadmin}
      - AWS_BUCKET=${AWS_BUCKET:-ringo-media}
      - DJANGO_SECRET_KEY=${DJANGO_SECRET_KEY}
      - DJANGO_ALLOWED_HOSTS=ringoouchet.ru,www.ringoouchet.ru,91.229.90.72
      - CSRF_TRUSTED_ORIGINS=https://ringoouchet.ru,https://www.ringoouchet.ru,http://ringoouchet.ru,http://www.ringoouchet.ru,http://91.229.90.72
      - CORS_ALLOW_ALL_ORIGINS=true
    command: gunicorn ringo_backend.wsgi:application --bind 0.0.0.0:8000 --workers 2 --timeout 120 --access-logfile - --error-logfile -
    depends_on:
      db:
        condition: service_healthy
      redis:
        condition: service_healthy
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8000/api/health/"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 40s
    networks:
      - ringo-net
    ports:
      - "8001:8000"

  celery-worker:
    build:
      context: .
      dockerfile: Dockerfile
    image: backend-celery-worker:latest
    restart: unless-stopped
    volumes:
      - ./orders:/app/orders:ro
      - ./ringo_backend:/app/ringo_backend:ro
    environment:
      - DJANGO_SETTINGS_MODULE=ringo_backend.settings.prod
      - POSTGRES_HOST=db
      - POSTGRES_PORT=5432
      - POSTGRES_DB=${DB_NAME:-ringo_prod}
      - POSTGRES_USER=${DB_USER:-ringo_user}
      - POSTGRES_PASSWORD=${DB_PASSWORD}
      - CELERY_BROKER_URL=redis://redis:6379/0
      - CELERY_RESULT_BACKEND=redis://redis:6379/0
      - AWS_S3_ENDPOINT_URL=http://minio:9000
      - AWS_ACCESS_KEY_ID=${MINIO_ROOT_USER:-minioadmin}
      - AWS_SECRET_ACCESS_KEY=${MINIO_ROOT_PASSWORD:-minioadmin}
      - AWS_BUCKET=${AWS_BUCKET:-ringo-media}
      - DJANGO_SECRET_KEY=${DJANGO_SECRET_KEY}
      - CELERY_WORKER_CONCURRENCY=4
    command: >
      celery -A ringo_backend worker
      --loglevel=info
      --concurrency=4
      --queues=default,finance,notifications,orders
    depends_on:
      db:
        condition: service_healthy
      redis:
        condition: service_healthy
    healthcheck:
      test: ["CMD", "celery", "-A", "ringo_backend", "inspect", "ping"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 40s
    networks:
      - ringo-net

  celery-beat:
    build:
      context: .
      dockerfile: Dockerfile
    image: backend-celery-beat:latest
    restart: unless-stopped
    volumes:
      - ./orders:/app/orders:ro
      - ./ringo_backend:/app/ringo_backend:ro
    environment:
      - DJANGO_SETTINGS_MODULE=ringo_backend.settings.prod
      - POSTGRES_HOST=db
      - POSTGRES_PORT=5432
      - POSTGRES_DB=${DB_NAME:-ringo_prod}
      - POSTGRES_USER=${DB_USER:-ringo_user}
      - POSTGRES_PASSWORD=${DB_PASSWORD}
      - CELERY_BROKER_URL=redis://redis:6379/0
      - CELERY_RESULT_BACKEND=redis://redis:6379/0
      - DJANGO_SECRET_KEY=${DJANGO_SECRET_KEY}
    command: celery -A ringo_backend beat --loglevel=info
    depends_on:
      db:
        condition: service_healthy
      redis:
        condition: service_healthy
    networks:
      - ringo-net

volumes:
  postgres_data:
  redis_data:
  minio_data:

networks:
  ringo-net:
    driver: bridge
```

### Исправление 2: Удаление устаревшего version из docker-compose

**Проблема:** Предупреждение `the attribute 'version' is obsolete`

**Решение:** Удалить строку `version: '3.8'` из начала файла (Docker Compose v2 не требует version)

### Исправление 3: Настройка Git для использования токенов

**Проблема:** Git push не работает с паролем

**Решение:**

```bash
# На сервере
cd ~/ringo-uchet/backend

# Настроить Git для использования токена
git config --global credential.helper store

# При следующем push использовать токен вместо пароля
# Username: Alikdseq
# Password: <Personal Access Token>
```

**Создание Personal Access Token:**
1. GitHub → Settings → Developer settings → Personal access tokens → Tokens (classic)
2. Generate new token (classic)
3. Выбрать scope: `repo`
4. Скопировать токен и использовать как пароль

---

## 🚀 ПОЛНАЯ ИНСТРУКЦИЯ ПО ДЕПЛОЮ

### Этап 1: Подготовка на локальной машине

#### 1.1 Проверка кода

```powershell
# На вашем компьютере
cd C:\ringo-uchet

# Проверить статус Git
git status

# Убедиться что все изменения закоммичены
git add .
git commit -m "Исправления перед деплоем"

# Проверить что нет конфликтов
git pull origin master
```

#### 1.2 Проверка Flutter Web сборки

```powershell
cd C:\ringo-uchet\mobile

# Обновить зависимости
flutter pub get

# Очистить старую сборку
flutter clean

# Собрать для production
flutter build web --release --base-href /

# Проверить что сборка создана
Test-Path build\web\index.html
Test-Path build\web\main.dart.js
```

#### 1.3 Очистка сборки от ненужных файлов

```powershell
cd C:\ringo-uchet\mobile\build\web

# Удалить debug символы
Get-ChildItem -Recurse -Filter "*.symbols" | Remove-Item -Force

# Удалить NOTICES файлы
Get-ChildItem -Recurse -Filter "NOTICES" | Remove-Item -Force

# Проверить размер (должен быть ~6-7 MB)
Get-ChildItem -Recurse -File | Measure-Object -Property Length -Sum | Select-Object @{Name="TotalSize(MB)";Expression={[math]::Round($_.Sum/1MB,2)}}
```

#### 1.4 Создание архива

```powershell
cd C:\ringo-uchet\mobile\build

# Создать архив
Compress-Archive -Path web\* -DestinationPath web-build-$(Get-Date -Format "yyyyMMdd-HHmmss").zip -Force

# Проверить размер архива
Get-Item web-build-*.zip | Select-Object Name, @{Name="Size(MB)";Expression={[math]::Round($_.Length/1MB,2)}} | Sort-Object Name -Descending | Select-Object -First 1
```

---

### Этап 2: Подготовка на сервере

#### 2.1 Подключение к серверу

```bash
# На вашем компьютере
ssh root@91.229.90.72
```

#### 2.2 Обновление кода на сервере

```bash
# На сервере
cd ~/ringo-uchet/backend

# Создать резервную копию БД
docker compose -f docker-compose.prod.yml exec db pg_dump -U ringo_user ringo_prod > /root/backup-$(date +%Y%m%d-%H%M%S).sql

# Проверить что бэкап создан
ls -lh /root/backup-*.sql | tail -1

# Обновить код из репозитория
git pull origin master

# Если есть конфликты, разрешить их
# git checkout --theirs <файл> или --ours
# git add <файл>
# git commit -m "Resolve merge conflict"
```

#### 2.3 Применение исправлений docker-compose.prod.yml

```bash
# На сервере
cd ~/ringo-uchet/backend

# Создать резервную копию текущего файла
cp docker-compose.prod.yml docker-compose.prod.yml.backup

# Применить исправления (см. раздел "Исправление 1")
# Или использовать готовый исправленный файл
```

#### 2.4 Настройка переменных окружения

```bash
# На сервере
cd ~/ringo-uchet/backend

# Проверить что .env файл существует и содержит все переменные
cat .env | grep -E "DB_|CELERY_|AWS_|DJANGO_|MINIO_"

# Если переменных нет, создать .env файл
# (НЕ коммитить .env в Git!)
```

**Пример .env файла:**
```bash
# Database
DB_HOST=db
DB_PORT=5432
DB_NAME=ringo_prod
DB_USER=ringo_user
DB_PASSWORD=<ваш_пароль>

# Celery
CELERY_BROKER_URL=redis://redis:6379/0
CELERY_RESULT_BACKEND=redis://redis:6379/0

# MinIO/S3
AWS_S3_ENDPOINT_URL=http://minio:9000
AWS_ACCESS_KEY_ID=minioadmin
AWS_SECRET_ACCESS_KEY=minioadmin
AWS_BUCKET=ringo-media

# Django
DJANGO_SECRET_KEY=<ваш_секретный_ключ>
MINIO_ROOT_USER=minioadmin
MINIO_ROOT_PASSWORD=minioadmin
```

---

### Этап 3: Сборка и запуск Docker контейнеров

#### 3.1 Остановка старых контейнеров

```bash
# На сервере
cd ~/ringo-uchet/backend

# Остановить все контейнеры
docker compose -f docker-compose.prod.yml down

# Удалить старые образы (опционально)
docker image prune -f
```

#### 3.2 Сборка образов

```bash
# На сервере
cd ~/ringo-uchet/backend

# Собрать образы
docker compose -f docker-compose.prod.yml build --no-cache

# Проверить что образы собраны
docker images | grep backend
```

#### 3.3 Запуск контейнеров

```bash
# На сервере
cd ~/ringo-uchet/backend

# Запустить все сервисы
docker compose -f docker-compose.prod.yml up -d

# Проверить статус
docker compose -f docker-compose.prod.yml ps

# Проверить логи
docker compose -f docker-compose.prod.yml logs -f api
```

#### 3.4 Применение миграций

```bash
# На сервере
cd ~/ringo-uchet/backend

# Проверить статус миграций
docker compose -f docker-compose.prod.yml exec api python manage.py showmigrations

# Применить миграции (если есть непримененные)
docker compose -f docker-compose.prod.yml exec api python manage.py migrate

# Собрать статические файлы
docker compose -f docker-compose.prod.yml exec api python manage.py collectstatic --noinput
```

---

### Этап 4: Деплой Frontend (Flutter Web)

#### 4.1 Загрузка архива на сервер

```powershell
# На вашем компьютере
# Использовать последний созданный архив
$latestArchive = Get-ChildItem C:\ringo-uchet\mobile\build\web-build-*.zip | Sort-Object Name -Descending | Select-Object -First 1

# Загрузить на сервер
scp $latestArchive.FullName root@91.229.90.72:~/web-build-latest.zip
```

#### 4.2 Распаковка на сервере

```bash
# На сервере
cd ~

# Создать резервную копию текущей версии
sudo mkdir -p /var/www/ringo-uchet-backup-$(date +%Y%m%d-%H%M%S)
sudo cp -r /var/www/ringo-uchet/* /var/www/ringo-uchet-backup-$(date +%Y%m%d-%H%M%S)/ 2>/dev/null || true

# Распаковать новую версию
unzip -o ~/web-build-latest.zip -d /tmp/flutter-web-new/

# Очистить старые файлы
sudo rm -rf /var/www/ringo-uchet/*

# Переместить новые файлы
sudo mv /tmp/flutter-web-new/web/* /var/www/ringo-uchet/ 2>/dev/null || sudo mv /tmp/flutter-web-new/* /var/www/ringo-uchet/

# Установить права
sudo chown -R www-data:www-data /var/www/ringo-uchet
sudo chmod -R 755 /var/www/ringo-uchet

# Проверить что файлы на месте
ls -la /var/www/ringo-uchet/ | head -20
```

#### 4.3 Перезагрузка Nginx

```bash
# На сервере
# Проверить конфигурацию
sudo nginx -t

# Если все ОК, перезагрузить
sudo systemctl reload nginx

# Очистить кэш Nginx
sudo rm -rf /var/cache/nginx/*
sudo systemctl reload nginx
```

---

### Этап 5: Проверка работы системы

#### 5.1 Проверка Backend

```bash
# На сервере
cd ~/ringo-uchet/backend

# Проверить health endpoint
curl http://localhost:8001/api/health/

# Проверить логи API
docker compose -f docker-compose.prod.yml logs api --tail 50

# Проверить логи Celery
docker compose -f docker-compose.prod.yml logs celery-worker --tail 50

# Проверить подключение к БД
docker compose -f docker-compose.prod.yml exec db psql -U ringo_user -d ringo_prod -c "SELECT COUNT(*) FROM orders_order;"
```

#### 5.2 Проверка Frontend

```bash
# На вашем компьютере
# Открыть сайт в браузере
# https://ringoouchet.ru

# Проверить консоль браузера (F12)
# - Нет ошибок
# - Service Worker зарегистрирован
# - API запросы успешны

# Проверить Network tab
# - Все файлы загружаются (200 OK)
# - API запросы работают
```

#### 5.3 Функциональное тестирование

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

4. **Отчеты:**
   - Просмотреть финансовые отчеты
   - Проверить фильтры

---

## 📋 КОНТРОЛЬНЫЙ СПИСОК ДЕПЛОЯ

### Перед деплоем:
- [ ] Код проверен и закоммичен
- [ ] Flutter Web пересобран
- [ ] Сборка очищена от ненужных файлов
- [ ] Архив создан
- [ ] Резервная копия БД создана
- [ ] docker-compose.prod.yml исправлен
- [ ] Переменные окружения настроены

### На сервере:
- [ ] Код обновлен из репозитория
- [ ] Docker образы собраны
- [ ] Контейнеры запущены и работают
- [ ] Миграции применены
- [ ] Статические файлы собраны
- [ ] Frontend файлы обновлены
- [ ] Nginx перезагружен

### После деплоя:
- [ ] Health endpoint работает
- [ ] API endpoints работают
- [ ] Frontend загружается
- [ ] Аутентификация работает
- [ ] Все функции работают
- [ ] Нет ошибок в логах

---

## 🔍 ДИАГНОСТИКА ПРОБЛЕМ

### Проблема: Контейнеры не запускаются

**Решение:**
```bash
# Проверить логи
docker compose -f docker-compose.prod.yml logs

# Проверить статус
docker compose -f docker-compose.prod.yml ps

# Перезапустить
docker compose -f docker-compose.prod.yml restart
```

### Проблема: БД не подключается

**Решение:**
```bash
# Проверить что БД запущена
docker compose -f docker-compose.prod.yml ps db

# Проверить логи БД
docker compose -f docker-compose.prod.yml logs db

# Проверить подключение
docker compose -f docker-compose.prod.yml exec api python manage.py dbshell
```

### Проблема: API возвращает 500 ошибки

**Решение:**
```bash
# Проверить логи API
docker compose -f docker-compose.prod.yml logs api --tail 100

# Проверить миграции
docker compose -f docker-compose.prod.yml exec api python manage.py showmigrations

# Проверить настройки
docker compose -f docker-compose.prod.yml exec api python manage.py check
```

### Проблема: Frontend не загружается

**Решение:**
```bash
# Проверить что файлы на месте
ls -la /var/www/ringo-uchet/

# Проверить права
sudo chown -R www-data:www-data /var/www/ringo-uchet
sudo chmod -R 755 /var/www/ringo-uchet

# Проверить Nginx
sudo nginx -t
sudo systemctl status nginx

# Проверить логи Nginx
sudo tail -f /var/log/nginx/error.log
```

---

## 📞 ПОДДЕРЖКА

При возникновении проблем:
1. Проверить логи: `docker compose -f docker-compose.prod.yml logs`
2. Проверить статус: `docker compose -f docker-compose.prod.yml ps`
3. Проверить health: `curl http://localhost:8001/api/health/`
4. Проверить консоль браузера (F12)

---

**Дата создания:** 2025-12-11
**Версия:** 1.0
**Автор:** AI Assistant


# ✅ ДЕЙСТВИЕ 5: ЗАПУСК BACKEND СЕРВИСОВ

## 🎯 ЦЕЛЬ
Собрать Docker образы и запустить все backend сервисы (API, БД, Redis, MinIO).

---

## 📋 ШАГ 1: СОЗДАНИЕ PRODUCTION DOCKER-COMPOSE

### 1.1 Переход в директорию backend

```bash
cd ~/ringo-uchet/backend
```

### 1.2 Создание docker-compose.prod.yml (если его нет или нужно обновить)

```bash
nano docker-compose.prod.yml
```

**Вставьте следующее содержимое:**

```yaml
version: '3.8'

services:
  db:
    image: postgres:15-alpine
    restart: unless-stopped
    environment:
      POSTGRES_DB: ${POSTGRES_DB:-ringo_prod}
      POSTGRES_USER: ${POSTGRES_USER:-ringo_user}
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD}
    volumes:
      - postgres_data:/var/lib/postgresql/data
    networks:
      - ringo-net
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U ${POSTGRES_USER:-ringo_user}"]
      interval: 10s
      timeout: 5s
      retries: 5

  redis:
    image: redis:7-alpine
    restart: unless-stopped
    volumes:
      - redis_data:/data
    networks:
      - ringo-net
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 10s
      timeout: 5s
      retries: 5

  minio:
    image: minio/minio:latest
    restart: unless-stopped
    command: server /data --console-address ":9001"
    environment:
      MINIO_ROOT_USER: ${MINIO_ROOT_USER:-minioadmin}
      MINIO_ROOT_PASSWORD: ${MINIO_ROOT_PASSWORD}
    volumes:
      - minio_data:/data
    ports:
      - "9000:9000"
      - "9001:9001"
    networks:
      - ringo-net
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:9000/minio/health/live"]
      interval: 30s
      timeout: 20s
      retries: 3

  api:
    build:
      context: .
      dockerfile: Dockerfile
    restart: unless-stopped
    env_file:
      - .env
    environment:
      - DJANGO_SETTINGS_MODULE=ringo_backend.settings.prod
    command: gunicorn ringo_backend.wsgi:application --bind 0.0.0.0:8000 --workers 2 --timeout 120 --access-logfile - --error-logfile -
    volumes:
      - ./staticfiles:/app/staticfiles
      - ./media:/app/media
    ports:
      - "8001:8000"
    depends_on:
      db:
        condition: service_healthy
      redis:
        condition: service_healthy
      minio:
        condition: service_healthy
    networks:
      - ringo-net

  celery-worker:
    build:
      context: .
      dockerfile: Dockerfile
    restart: unless-stopped
    env_file:
      - .env
    environment:
      - DJANGO_SETTINGS_MODULE=ringo_backend.settings.prod
    command: celery -A ringo_backend worker --loglevel=info --concurrency=2
    volumes:
      - .:/app
    depends_on:
      - api
      - redis
    networks:
      - ringo-net

  celery-beat:
    build:
      context: .
      dockerfile: Dockerfile
    restart: unless-stopped
    env_file:
      - .env
    environment:
      - DJANGO_SETTINGS_MODULE=ringo_backend.settings.prod
    command: celery -A ringo_backend beat --loglevel=info
    volumes:
      - .:/app
    depends_on:
      - api
      - redis
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

**Сохраните:** `Ctrl + O`, `Enter`, `Ctrl + X`

---

## 📋 ШАГ 2: УСТАНОВКА GUNICORN

**Gunicorn нужен для production. Проверим Dockerfile:**

```bash
grep -i gunicorn Dockerfile || echo "Gunicorn не найден в Dockerfile"
```

**Если gunicorn не установлен, добавьте его в requirements.txt:**

```bash
echo "gunicorn" >> requirements.txt
```

---

## 📋 ШАГ 3: СОЗДАНИЕ ДИРЕКТОРИЙ ДЛЯ СТАТИЧЕСКИХ ФАЙЛОВ

```bash
mkdir -p staticfiles media
```

---

## 📋 ШАГ 4: ЗАПУСК КОНТЕЙНЕРОВ

### 4.1 Сборка и запуск

```bash
docker compose -f docker-compose.prod.yml up -d --build
```

⏱️ **Займет 5-10 минут (первая сборка)**

### 4.2 Проверка статуса

```bash
docker compose -f docker-compose.prod.yml ps
```

**Все сервисы должны быть в статусе `Up` или `healthy`**

### 4.3 Просмотр логов (если нужно)

```bash
docker compose -f docker-compose.prod.yml logs -f api
```

**Для выхода из логов нажмите:** `Ctrl + C`

---

## 📋 ШАГ 5: ПРИМЕНЕНИЕ МИГРАЦИЙ

### 5.1 Выполнение миграций

```bash
docker compose -f docker-compose.prod.yml exec api python manage.py migrate
```

### 5.2 Сбор статических файлов

```bash
docker compose -f docker-compose.prod.yml exec api python manage.py collectstatic --noinput
```

---

## 📋 ШАГ 6: СОЗДАНИЕ СУПЕРПОЛЬЗОВАТЕЛЯ

```bash
docker compose -f docker-compose.prod.yml exec api python manage.py createsuperuser
```

**Введите:**
- Phone (номер телефона): например `+79991234567`
- Email: ваш email
- Password: придумайте пароль
- Подтвердите пароль

**Если команда `createsuperuser` не работает, используйте альтернативный способ:**

```bash
docker compose -f docker-compose.prod.yml exec api python manage.py shell
```

**В Python shell:**

```python
from users.models import User
User.objects.create_superuser(
    phone='+79991234567',
    email='admin@example.com',
    password='ВАШ_ПАРОЛЬ',
    role='admin',
    first_name='Admin',
    last_name='User'
)
exit()
```

---

## 📋 ШАГ 7: ПРОВЕРКА РАБОТЫ API

### 7.1 Проверка health endpoint

```bash
curl http://localhost:8001/api/health/
```

**Или с сервера:**

```bash
curl http://127.0.0.1:8001/api/health/
```

**Должен вернуть JSON с информацией о сервисе.**

---

## ✅ ФИНАЛЬНАЯ ПРОВЕРКА

```bash
docker compose -f docker-compose.prod.yml ps
```

**Все должно быть `Up`:**
- db
- redis
- minio
- api
- celery-worker
- celery-beat

---

## ⏭️ СЛЕДУЮЩИЙ ШАГ

**После успешного запуска напишите:**
- ✅ **"Готово, backend запущен"** - перейдем к сборке Flutter Web приложения

---

**Статус:** ⏳ Запуск Backend сервисов

**Время выполнения:** 10-15 минут


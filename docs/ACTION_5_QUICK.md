# ✅ ДЕЙСТВИЕ 5: ЗАПУСК BACKEND (БЫСТРАЯ ВЕРСИЯ)

## ШАГ 1: СОЗДАНИЕ docker-compose.prod.yml

```bash
cd ~/ringo-uchet/backend
nano docker-compose.prod.yml
```

**Вставьте весь файл ниже (от version до networks):**

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

  api:
    build:
      context: .
      dockerfile: Dockerfile
    restart: unless-stopped
    env_file:
      - .env
    environment:
      - DJANGO_SETTINGS_MODULE=ringo_backend.settings.prod
    command: gunicorn ringo_backend.wsgi:application --bind 0.0.0.0:8000 --workers 2 --timeout 120
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

## ШАГ 2: СОЗДАНИЕ ДИРЕКТОРИЙ

```bash
mkdir -p staticfiles media
```

---

## ШАГ 3: ЗАПУСК КОНТЕЙНЕРОВ

```bash
docker compose -f docker-compose.prod.yml up -d --build
```

⏱️ **Займет 5-10 минут**

---

## ШАГ 4: ПРОВЕРКА

```bash
docker compose -f docker-compose.prod.yml ps
```

Все должны быть `Up`

---

## ШАГ 5: МИГРАЦИИ

```bash
docker compose -f docker-compose.prod.yml exec api python manage.py migrate
docker compose -f docker-compose.prod.yml exec api python manage.py collectstatic --noinput
```

---

## ШАГ 6: СУПЕРПОЛЬЗОВАТЕЛЬ

```bash
docker compose -f docker-compose.prod.yml exec api python manage.py createsuperuser
```

---

## ШАГ 7: ПРОВЕРКА API

```bash
curl http://localhost:8001/api/health/
```

---

**После этого напишите:** "Готово, backend запущен"


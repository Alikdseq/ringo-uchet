# ✅ ИСПРАВЛЕНИЕ: Добавить DJANGO_ALLOWED_HOSTS в docker-compose

## ❌ ПРОБЛЕМА

Контейнер использует старые значения:
```
DJANGO_ALLOWED_HOSTS=91.229.90.72,localhost,127.0.0.1
CORS_ALLOWED_ORIGINS=http://91.229.90.72,https://ваш-домен.ru  ← ПЛЕЙСХОЛДЕР!
```

**.env файл правильный, но контейнер его не читает!**

---

## ✅ РЕШЕНИЕ

### ШАГ 1: Открыть docker-compose.prod.yml

```bash
cd ~/ringo-uchet/backend
nano docker-compose.prod.yml
```

---

### ШАГ 2: Добавить переменные напрямую в секцию api

**Найдите блок `api:` (строка 4) и в секции `environment:` (после строки 20) добавьте:**

```yaml
      - DJANGO_ALLOWED_HOSTS=ringoouchet.ru,www.ringoouchet.ru,91.229.90.72
      - CSRF_TRUSTED_ORIGINS=http://ringoouchet.ru,http://www.ringoouchet.ru,http://91.229.90.72
      - CORS_ALLOWED_ORIGINS=http://ringoouchet.ru,http://www.ringoouchet.ru,http://91.229.90.72
```

**После строки 20 (`DJANGO_SECRET_KEY`) должно быть:**

```yaml
    environment:
      - DJANGO_SETTINGS_MODULE=ringo_backend.settings.prod
      - POSTGRES_HOST=${DB_HOST}
      - POSTGRES_PORT=${DB_PORT}
      - POSTGRES_DB=${DB_NAME}
      - POSTGRES_USER=${DB_USER}
      - POSTGRES_PASSWORD=${DB_PASSWORD}
      - CELERY_BROKER_URL=${CELERY_BROKER_URL}
      - CELERY_RESULT_BACKEND=${CELERY_RESULT_BACKEND}
      - AWS_S3_ENDPOINT_URL=${AWS_S3_ENDPOINT_URL}
      - AWS_ACCESS_KEY_ID=${AWS_ACCESS_KEY_ID}
      - AWS_SECRET_ACCESS_KEY=${AWS_SECRET_ACCESS_KEY}
      - AWS_BUCKET=${AWS_BUCKET}
      - DJANGO_SECRET_KEY=${DJANGO_SECRET_KEY}
      - DJANGO_ALLOWED_HOSTS=ringoouchet.ru,www.ringoouchet.ru,91.229.90.72
      - CSRF_TRUSTED_ORIGINS=http://ringoouchet.ru,http://www.ringoouchet.ru,http://91.229.90.72
      - CORS_ALLOWED_ORIGINS=http://ringoouchet.ru,http://www.ringoouchet.ru,http://91.229.90.72
      - ALLOWED_HOSTS=${ALLOWED_HOSTS:-*}
```

**Сохраните:** `Ctrl + O`, `Enter`, `Ctrl + X`

---

### ШАГ 3: Полностью пересоздать контейнер

```bash
docker compose -f docker-compose.prod.yml down
docker compose -f docker-compose.prod.yml up -d
```

**Подождите 30 секунд.**

---

### ШАГ 4: Проверка переменных

```bash
docker compose -f docker-compose.prod.yml exec api env | grep -E "DJANGO_ALLOWED|CORS_ALLOWED"
```

**Должно показать домен `ringoouchet.ru`, а НЕ `ваш-домен.ru`!**

---

### ШАГ 5: Проверка API

```bash
curl http://ringoouchet.ru/api/health/
```

**Должен вернуть JSON или 200, но НЕ 400!**

---

**Выполните эти шаги!**


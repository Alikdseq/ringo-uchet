# ✅ ФИНАЛЬНОЕ ИСПРАВЛЕНИЕ: 400 Bad Request

## ❌ ПРОБЛЕМА

В логах:
```
Invalid HTTP_HOST header: 'ringoouchet.ru'. You may need to add 'ringoouchet.ru' to ALLOWED_HOSTS.
```

**Django не видит домен, потому что:**
1. `docker-compose.prod.yml` не загружает `.env` файл
2. Нужно добавить `DJANGO_ALLOWED_HOSTS` напрямую

---

## ✅ РЕШЕНИЕ

### ШАГ 1: Открыть docker-compose.prod.yml

```bash
cd ~/ringo-uchet/backend
nano docker-compose.prod.yml
```

---

### ШАГ 2: Добавить переменные в секцию api

**Найдите блок `api:` и в секции `environment:` добавьте:**

**После строки 20 (`DJANGO_SECRET_KEY`) добавьте две строки:**

```yaml
      - DJANGO_ALLOWED_HOSTS=ringoouchet.ru,www.ringoouchet.ru,91.229.90.72
      - CSRF_TRUSTED_ORIGINS=http://ringoouchet.ru,http://www.ringoouchet.ru,http://91.229.90.72
```

**Пример, как должно выглядеть (строки 7-22):**

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
      - ALLOWED_HOSTS=${ALLOWED_HOSTS:-*}
```

**Сохраните:** `Ctrl + O`, `Enter`, `Ctrl + X`

---

### ШАГ 3: Перезапустить контейнер

```bash
docker compose -f docker-compose.prod.yml restart api
```

**Подождите 15 секунд.**

---

### ШАГ 4: Проверка

```bash
curl http://ringoouchet.ru/api/health/
```

**Должен вернуть JSON или 200, но НЕ 400!**

---

**Выполните эти шаги!**


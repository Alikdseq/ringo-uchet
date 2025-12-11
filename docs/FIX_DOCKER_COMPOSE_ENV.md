# 🔧 ИСПРАВЛЕНИЕ: docker-compose не читает .env файл

## ❌ ПРОБЛЕМА

В логах:
```
Invalid HTTP_HOST header: 'ringoouchet.ru'. You may need to add 'ringoouchet.ru' to ALLOWED_HOSTS.
```

**Причина:** 
1. `docker-compose.prod.yml` не использует `env_file`, поэтому `.env` не загружается
2. Используется `ALLOWED_HOSTS`, а Django читает `DJANGO_ALLOWED_HOSTS`

---

## ✅ РЕШЕНИЕ

### Вариант 1: Добавить env_file в docker-compose (РЕКОМЕНДУЕТСЯ)

**Измените docker-compose.prod.yml:**

```bash
cd ~/ringo-uchet/backend
nano docker-compose.prod.yml
```

**В секции `api:` добавьте `env_file`:**

```yaml
  api:
    build:
      context: .
      dockerfile: Dockerfile
    restart: unless-stopped
    env_file:
      - .env  # ДОБАВЬТЕ ЭТУ СТРОКУ
    environment:
      - DJANGO_SETTINGS_MODULE=ringo_backend.settings.prod
      # ... остальные переменные
```

**Сохраните:** `Ctrl + O`, `Enter`, `Ctrl + X`

---

### Вариант 2: Добавить DJANGO_ALLOWED_HOSTS напрямую

**Или добавьте переменную напрямую в environment:**

```yaml
  api:
    # ... существующие настройки ...
    environment:
      - DJANGO_SETTINGS_MODULE=ringo_backend.settings.prod
      - DJANGO_ALLOWED_HOSTS=ringoouchet.ru,www.ringoouchet.ru,91.229.90.72  # ДОБАВЬТЕ
      # ... остальные переменные
```

---

## ✅ БЫСТРОЕ РЕШЕНИЕ

**Используем существующий docker-compose, который использует build (не image):**

**Проверьте, какой docker-compose файл вы используете:**

```bash
cd ~/ringo-uchet/backend
ls -la docker-compose*.yml
```

**Если используете docker-compose.prod.yml с `image:` (не build), нужно изменить его на `build:`.**

---

**Выполните проверку и скажите, какой файл вы используете!**


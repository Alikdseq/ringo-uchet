# ✅ ПОЛНОЕ ИСПРАВЛЕНИЕ: Django не видит DJANGO_ALLOWED_HOSTS

## ❌ ПРОБЛЕМА

В логах:
```
Invalid HTTP_HOST header: 'ringoouchet.ru'. You may need to add 'ringoouchet.ru' to ALLOWED_HOSTS.
```

**Домен в .env есть, но Django его не читает!**

---

## 🔍 ПРИЧИНА

**Проблема:** В `docker-compose.prod.yml` нет `env_file: - .env`, поэтому переменные из .env не загружаются в контейнер.

---

## ✅ РЕШЕНИЕ

### ШАГ 1: Проверить какой docker-compose используется

```bash
cd ~/ringo-uchet/backend
docker compose -f docker-compose.prod.yml ps
```

**Посмотрим, какие контейнеры запущены.**

---

### ШАГ 2: Добавить DJANGO_ALLOWED_HOSTS напрямую в docker-compose

**Самый простой способ - добавить переменную напрямую:**

```bash
cd ~/ringo-uchet/backend
nano docker-compose.prod.yml
```

**Найдите секцию `api:` и в блоке `environment:` добавьте:**

```yaml
  api:
    # ... существующие настройки ...
    environment:
      - DJANGO_SETTINGS_MODULE=ringo_backend.settings.prod
      - DJANGO_ALLOWED_HOSTS=ringoouchet.ru,www.ringoouchet.ru,91.229.90.72  # ДОБАВЬТЕ ЭТУ СТРОКУ
      - CSRF_TRUSTED_ORIGINS=http://ringoouchet.ru,http://www.ringoouchet.ru,http://91.229.90.72  # ДОБАВЬТЕ ЭТУ СТРОКУ
      # ... остальные переменные
```

**Сохраните:** `Ctrl + O`, `Enter`, `Ctrl + X`

---

### ШАГ 3: Полностью перезапустить контейнеры

```bash
cd ~/ringo-uchet/backend
docker compose -f docker-compose.prod.yml down
docker compose -f docker-compose.prod.yml up -d
```

**Подождите 20 секунд для полного запуска.**

---

### ШАГ 4: Проверка переменной в контейнере

```bash
docker compose -f docker-compose.prod.yml exec api env | grep DJANGO_ALLOWED
```

**Должен показать:**
```
DJANGO_ALLOWED_HOSTS=ringoouchet.ru,www.ringoouchet.ru,91.229.90.72
```

---

### ШАГ 5: Проверка API

```bash
curl http://ringoouchet.ru/api/health/
```

**Должен вернуть JSON или 200/301, но НЕ 400!**

---

## ✅ АЛЬТЕРНАТИВНОЕ РЕШЕНИЕ: Добавить env_file

**Если хотите использовать .env файл, добавьте в docker-compose.prod.yml:**

```yaml
  api:
    # ... существующие настройки ...
    env_file:
      - .env  # ДОБАВЬТЕ ЭТУ СТРОКУ
    environment:
      # ... переменные
```

**Но проще добавить переменные напрямую (как в Шаге 2).**

---

**Выполните Шаг 2 и 3, затем сообщите результат!**


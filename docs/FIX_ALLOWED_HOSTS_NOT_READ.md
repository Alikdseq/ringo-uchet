# 🔧 ИСПРАВЛЕНИЕ: Django не видит домен в ALLOWED_HOSTS

## ❌ ПРОБЛЕМА

В логах:
```
Invalid HTTP_HOST header: 'ringoouchet.ru'. You may need to add 'ringoouchet.ru' to ALLOWED_HOSTS.
```

**Домен в .env есть, но Django его не видит!**

---

## 🔍 ДИАГНОСТИКА

### Проверка 1: Проверить, что .env файл правильный

```bash
cd ~/ringo-uchet/backend
cat .env | grep DJANGO_ALLOWED_HOSTS
```

**Должно показать:**
```
DJANGO_ALLOWED_HOSTS=ringoouchet.ru,www.ringoouchet.ru,91.229.90.72
```

---

### Проверка 2: Проверить переменные в контейнере

```bash
docker compose -f docker-compose.prod.yml exec api env | grep DJANGO_ALLOWED
```

**Должен показать переменную с доменами!**

---

### Проверка 3: Проверить как docker-compose читает .env

**Посмотрим docker-compose.prod.yml:**

```bash
cat docker-compose.prod.yml | grep -A 10 "api:"
```

**Проверим, используется ли env_file.**

---

## ✅ РЕШЕНИЕ

### Вариант 1: Перезапустить контейнер ПОЛНОСТЬЮ

**Остановить и запустить заново:**

```bash
cd ~/ringo-uchet/backend
docker compose -f docker-compose.prod.yml down
docker compose -f docker-compose.prod.yml up -d
```

**Это гарантированно перечитает .env файл.**

---

### Вариант 2: Проверить путь к .env файлу

**Убедитесь, что docker-compose.prod.yml правильно указывает на .env:**

```bash
cat docker-compose.prod.yml | grep env_file
```

**Должно быть:**
```yaml
env_file:
  - .env
```

---

### Вариант 3: Передать переменную напрямую

**Если .env не работает, добавим переменную напрямую в docker-compose:**

```bash
cd ~/ringo-uchet/backend
nano docker-compose.prod.yml
```

**В секции `api:` добавьте в `environment`:**

```yaml
  api:
    # ... существующие настройки ...
    environment:
      - DJANGO_SETTINGS_MODULE=ringo_backend.settings.prod
      - DJANGO_ALLOWED_HOSTS=ringoouchet.ru,www.ringoouchet.ru,91.229.90.72
```

---

## ✅ БЫСТРОЕ РЕШЕНИЕ

**Выполните по порядку:**

```bash
cd ~/ringo-uchet/backend

# 1. Проверить .env
cat .env | grep DJANGO_ALLOWED_HOSTS

# 2. Полностью перезапустить контейнеры
docker compose -f docker-compose.prod.yml down
docker compose -f docker-compose.prod.yml up -d

# 3. Подождать 20 секунд

# 4. Проверить переменную в контейнере
docker compose -f docker-compose.prod.yml exec api env | grep DJANGO_ALLOWED

# 5. Проверить API
curl http://ringoouchet.ru/api/health/
```

---

**Выполните эти команды и сообщите результат!**


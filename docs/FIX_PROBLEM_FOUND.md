# ✅ ПРОБЛЕМА НАЙДЕНА И ИСПРАВЛЕНИЕ

## ❌ ПРОБЛЕМА

**В контейнере (старые значения):**
```
DJANGO_ALLOWED_HOSTS=91.229.90.72,localhost,127.0.0.1
CORS_ALLOWED_ORIGINS=http://91.229.90.72,https://ваш-домен.ru  ← ПЛЕЙСХОЛДЕР!
```

**В .env файле (правильные значения):**
```
DJANGO_ALLOWED_HOSTS=ringoouchet.ru,www.ringoouchet.ru,91.229.90.72
```

**Контейнер НЕ читает обновленный .env!**

---

## ✅ РЕШЕНИЕ

### ШАГ 1: Проверить весь .env файл на плейсхолдеры

```bash
cd ~/ringo-uchet/backend
grep -n "ваш-домен" .env
```

**Покажет все места, где остался плейсхолдер.**

---

### ШАГ 2: Проверить, используется ли env_file в docker-compose

```bash
cat docker-compose.prod.yml | grep -A 10 "api:" | grep -E "env_file|build|image"
```

**Покажет, как конфигурирован API.**

---

### ШАГ 3: Полностью пересоздать контейнеры

**Остановить все:**

```bash
cd ~/ringo-uchet/backend
docker compose -f docker-compose.prod.yml down
```

**Запустить заново (с пересборкой):**

```bash
docker compose -f docker-compose.prod.yml up -d --build
```

**Подождите 30-40 секунд для полного запуска.**

---

### ШАГ 4: Проверить переменные в контейнере

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

**Выполните все шаги по порядку!**


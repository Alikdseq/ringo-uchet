# ✅ ПРОФЕССИОНАЛЬНОЕ ИСПРАВЛЕНИЕ: ALLOWED_HOSTS

## ❌ ПРОБЛЕМА

Django возвращает 400 Bad Request, потому что домен не в `DJANGO_ALLOWED_HOSTS`.

---

## 🔍 ЧТО НУЖНО ИСПРАВИТЬ

В `prod.py` Django читает:
- `ALLOWED_HOSTS` из переменной `DJANGO_ALLOWED_HOSTS`
- `CSRF_TRUSTED_ORIGINS` из переменной `CSRF_TRUSTED_ORIGINS`

**Нужно добавить домен в .env файл!**

---

## ✅ РЕШЕНИЕ

### ШАГ 1: Проверить текущий .env

```bash
cd ~/ringo-uchet/backend
cat .env | grep -E "DJANGO_ALLOWED|CSRF"
```

**Посмотрим, что там сейчас.**

---

### ШАГ 2: Открыть .env файл

```bash
cd ~/ringo-uchet/backend
nano .env
```

---

### ШАГ 3: Добавить/Обновить переменные

**Найдите или добавьте эти строки:**

```env
# ALLOWED_HOSTS - домены, которые может обслуживать Django
DJANGO_ALLOWED_HOSTS=ringoouchet.ru,www.ringoouchet.ru,91.229.90.72

# CSRF Trusted Origins - для защиты от CSRF
CSRF_TRUSTED_ORIGINS=http://ringoouchet.ru,http://www.ringoouchet.ru,http://91.229.90.72
```

**Если есть CORS, также добавьте:**

```env
CORS_ALLOWED_ORIGINS=http://ringoouchet.ru,http://www.ringoouchet.ru,http://91.229.90.72
CORS_ALLOW_CREDENTIALS=True
```

**Важно:**
- Запятые БЕЗ пробелов между доменами
- Оставьте IP адрес тоже

**Сохраните:** `Ctrl + O`, `Enter`, `Ctrl + X`

---

### ШАГ 4: Перезапустить API

```bash
docker compose -f docker-compose.prod.yml restart api
```

**Подождите 10 секунд.**

---

### ШАГ 5: Проверка

```bash
curl http://ringoouchet.ru/api/health/
```

**Должен вернуть JSON или 200/301, но НЕ 400!**

---

**После исправления напишите результат!**


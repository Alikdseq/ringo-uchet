# ✅ ПОЛНОЕ ИСПРАВЛЕНИЕ: 400 Bad Request

## ✅ ЧТО УЖЕ ЕСТЬ

```
DJANGO_ALLOWED_HOSTS=ringoouchet.ru,www.ringoouchet.ru,91.229.90.72
```

**Домен добавлен правильно!** ✅

---

## ❌ ЧТО НУЖНО ДОБАВИТЬ

1. **CSRF_TRUSTED_ORIGINS** - для защиты от CSRF атак
2. **Возможно временно отключить SECURE_SSL_REDIRECT** (пока SSL не настроен)

---

## ✅ ПОЛНОЕ РЕШЕНИЕ

### ШАГ 1: Открыть .env файл

```bash
cd ~/ringo-uchet/backend
nano .env
```

---

### ШАГ 2: Добавить недостающие переменные

**После строки с `DJANGO_ALLOWED_HOSTS` добавьте:**

```env
CSRF_TRUSTED_ORIGINS=http://ringoouchet.ru,http://www.ringoouchet.ru,http://91.229.90.72
```

**Если используете CORS (django-cors-headers), также добавьте:**

```env
CORS_ALLOWED_ORIGINS=http://ringoouchet.ru,http://www.ringoouchet.ru,http://91.229.90.72
CORS_ALLOW_CREDENTIALS=True
```

**Сохраните:** `Ctrl + O`, `Enter`, `Ctrl + X`

---

### ШАГ 3: Временно отключить SSL редирект

**Проблема:** `SECURE_SSL_REDIRECT = True` в prod.py заставляет редиректить на HTTPS, но SSL еще не настроен.

**Вариант А: Через переменную окружения (если поддерживается)**

**Добавьте в .env:**

```env
DJANGO_SECURE_SSL_REDIRECT=False
```

**Вариант Б: Изменить prod.py напрямую (временно)**

```bash
cd ~/ringo-uchet/backend
docker compose -f docker-compose.prod.yml exec api sed -i 's/SECURE_SSL_REDIRECT = True/SECURE_SSL_REDIRECT = False/' ringo_backend/settings/prod.py
```

---

### ШАГ 4: Перезапустить API

```bash
docker compose -f docker-compose.prod.yml restart api
```

**Подождите 15 секунд для полного перезапуска.**

---

### ШАГ 5: Проверка

```bash
curl -v http://ringoouchet.ru/api/health/
```

**Должен вернуть JSON или 200, но НЕ 400!**

---

### ШАГ 6: Проверка логов (если все еще ошибка)

```bash
docker compose -f docker-compose.prod.yml logs api | grep -i "error\|allowed\|csrf" | tail -20
```

---

## ✅ ФИНАЛЬНЫЙ .ENV (должен содержать)

```env
DJANGO_ALLOWED_HOSTS=ringoouchet.ru,www.ringoouchet.ru,91.229.90.72
CSRF_TRUSTED_ORIGINS=http://ringoouchet.ru,http://www.ringoouchet.ru,http://91.229.90.72
```

---

**Выполните эти шаги и сообщите результат!**


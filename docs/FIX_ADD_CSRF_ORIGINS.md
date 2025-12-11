# ✅ ИСПРАВЛЕНИЕ: Добавить CSRF_TRUSTED_ORIGINS

## ✅ ЧТО УЖЕ ЕСТЬ

```
DJANGO_ALLOWED_HOSTS=ringoouchet.ru,www.ringoouchet.ru,91.229.90.72
```

**Это правильно!** ✅

---

## ❌ ЧЕГО НЕ ХВАТАЕТ

**Нет `CSRF_TRUSTED_ORIGINS`** - это может вызывать проблемы.

---

## ✅ РЕШЕНИЕ

### ШАГ 1: Открыть .env файл

```bash
cd ~/ringo-uchet/backend
nano .env
```

### ШАГ 2: Добавить CSRF_TRUSTED_ORIGINS

**После строки с `DJANGO_ALLOWED_HOSTS` добавьте:**

```env
CSRF_TRUSTED_ORIGINS=http://ringoouchet.ru,http://www.ringoouchet.ru,http://91.229.90.72
```

**Если есть CORS, также добавьте:**

```env
CORS_ALLOWED_ORIGINS=http://ringoouchet.ru,http://www.ringoouchet.ru,http://91.229.90.72
CORS_ALLOW_CREDENTIALS=True
```

**Сохраните:** `Ctrl + O`, `Enter`, `Ctrl + X`

---

### ШАГ 3: Перезапустить API

```bash
docker compose -f docker-compose.prod.yml restart api
```

**Подождите 10 секунд для полного перезапуска.**

---

### ШАГ 4: Проверка

```bash
curl http://ringoouchet.ru/api/health/
```

**Должен вернуть JSON или 200/301, но НЕ 400!**

---

### ШАГ 5: Если все еще 400 - проверка логов

```bash
docker compose -f docker-compose.prod.yml logs api | tail -50
```

**Ищите ошибки про ALLOWED_HOSTS или CSRF.**

---

## ✅ ЧТО ДОЛЖНО БЫТЬ В .ENV

```env
DJANGO_ALLOWED_HOSTS=ringoouchet.ru,www.ringoouchet.ru,91.229.90.72
CSRF_TRUSTED_ORIGINS=http://ringoouchet.ru,http://www.ringoouchet.ru,http://91.229.90.72
```

---

**После добавления и перезапуска напишите результат!**


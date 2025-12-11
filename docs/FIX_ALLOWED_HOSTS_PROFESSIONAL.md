# 🔧 ПРОФЕССИОНАЛЬНОЕ ИСПРАВЛЕНИЕ: ALLOWED_HOSTS и CSRF_TRUSTED_ORIGINS

## ❌ ПРОБЛЕМА

Django возвращает 400 Bad Request, потому что:
1. Домен `ringoouchet.ru` не в `DJANGO_ALLOWED_HOSTS`
2. Возможно не настроен `CSRF_TRUSTED_ORIGINS`

---

## ✅ ПРОФЕССИОНАЛЬНОЕ РЕШЕНИЕ

### ШАГ 1: Проверить текущий .env файл

```bash
cd ~/ringo-uchet/backend
cat .env | grep -E "ALLOWED_HOSTS|CSRF|DJANGO_ALLOWED"
```

**Это покажет, какие переменные уже есть.**

---

### ШАГ 2: Открыть и обновить .env файл

```bash
cd ~/ringo-uchet/backend
nano .env
```

---

### ШАГ 3: Добавить/Обновить переменные

**Найдите или добавьте следующие строки:**

```env
# Django ALLOWED_HOSTS - список доменов, которые может обслуживать Django
DJANGO_ALLOWED_HOSTS=ringoouchet.ru,www.ringoouchet.ru,91.229.90.72

# CSRF Trusted Origins - домены для CORS и CSRF защиты
CSRF_TRUSTED_ORIGINS=http://ringoouchet.ru,http://www.ringoouchet.ru,http://91.229.90.72

# CORS Allowed Origins (если используете CORS)
CORS_ALLOWED_ORIGINS=http://ringoouchet.ru,http://www.ringoouchet.ru,http://91.229.90.72
CORS_ALLOW_CREDENTIALS=True
```

**Важно:**
- Разделяйте значения запятыми БЕЗ пробелов
- Оставьте IP адрес тоже (на случай проблем с доменом)
- После настройки SSL измените `http://` на `https://`

**Сохраните:** `Ctrl + O`, `Enter`, `Ctrl + X`

---

### ШАГ 4: Проверить содержимое .env

```bash
cd ~/ringo-uchet/backend
cat .env | grep -E "DJANGO_ALLOWED_HOSTS|CSRF_TRUSTED_ORIGINS|CORS_ALLOWED"
```

**Должны быть ваши домены!**

---

### ШАГ 5: Перезапустить API

```bash
docker compose -f docker-compose.prod.yml restart api
```

**Подождите 10-15 секунд для полного перезапуска.**

---

### ШАГ 6: Проверка в логах

```bash
docker compose -f docker-compose.prod.yml logs api | grep -i "allowed_hosts\|error" | tail -10
```

**Не должно быть ошибок про ALLOWED_HOSTS.**

---

### ШАГ 7: Проверка API

```bash
curl -v http://ringoouchet.ru/api/health/
```

**Должен вернуть JSON или 200/301, но НЕ 400.**

---

### ШАГ 8: Проверка фронтенда

```bash
curl -I http://ringoouchet.ru/
```

**Должен вернуть 200 OK.**

---

## 📝 ПОЛНЫЙ ПРИМЕР .ENV (релевантные строки)

```env
# Django Settings
DJANGO_SETTINGS_MODULE=ringo_backend.settings.prod
DJANGO_SECRET_KEY=ваш-секретный-ключ
DJANGO_DEBUG=False

# ALLOWED_HOSTS - домены, которые может обслуживать Django
DJANGO_ALLOWED_HOSTS=ringoouchet.ru,www.ringoouchet.ru,91.229.90.72

# CSRF Trusted Origins - для защиты от CSRF атак
CSRF_TRUSTED_ORIGINS=http://ringoouchet.ru,http://www.ringoouchet.ru,http://91.229.90.72

# CORS - если фронтенд на другом домене
CORS_ALLOWED_ORIGINS=http://ringoouchet.ru,http://www.ringoouchet.ru,http://91.229.90.72
CORS_ALLOW_CREDENTIALS=True

# Остальные настройки...
```

---

## ✅ ЧЕКЛИСТ

- [ ] .env файл открыт
- [ ] `DJANGO_ALLOWED_HOSTS` содержит `ringoouchet.ru,www.ringoouchet.ru,91.229.90.72`
- [ ] `CSRF_TRUSTED_ORIGINS` содержит домены с `http://`
- [ ] `CORS_ALLOWED_ORIGINS` содержит домены (если используется CORS)
- [ ] Файл сохранен
- [ ] API перезапущен
- [ ] Проверен: `curl http://ringoouchet.ru/api/health/` - НЕ 400

---

## ⏭️ ПОСЛЕ ИСПРАВЛЕНИЯ

**Напишите:**
- ✅ **"Готово, исправил ALLOWED_HOSTS"** - перейдем к проверке

---

**Статус:** 🔧 Исправление ALLOWED_HOSTS


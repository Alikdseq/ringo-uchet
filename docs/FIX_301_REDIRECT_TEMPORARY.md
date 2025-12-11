# ✅ ИСПРАВЛЕНИЕ: 301 редирект на HTTPS (SSL еще не настроен)

## ❌ ПРОБЛЕМА

**Nginx редиректит на HTTPS:**
```
HTTP/1.1 301 Moved Permanently
Location: https://ringoouchet.ru/api/health/
```

**Но SSL еще не настроен, поэтому запросы не работают!**

---

## ✅ РЕШЕНИЕ

### Вариант 1: Временно отключить SSL редирект (для проверки)

**Затем настроим SSL правильно.**

---

### ШАГ 1: Временно отключить SSL редирект в Django

```bash
cd ~/ringo-uchet/backend
docker compose -f docker-compose.prod.yml exec api sed -i 's/SECURE_SSL_REDIRECT = True/SECURE_SSL_REDIRECT = False/' ringo_backend/settings/prod.py
```

---

### ШАГ 2: Перезапустить API

```bash
docker compose -f docker-compose.prod.yml restart api
```

**Подождите 10 секунд.**

---

### ШАГ 3: Проверка

```bash
curl -L http://ringoouchet.ru/api/health/
```

**Должен вернуть JSON, но НЕ 301!**

---

**ИЛИ настроим SSL прямо сейчас - тогда редирект будет работать правильно!**

---

**Какой вариант выбираете?**


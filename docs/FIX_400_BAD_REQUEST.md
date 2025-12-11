# 🔧 ИСПРАВЛЕНИЕ: 400 Bad Request для API

## ❌ ПРОБЛЕМА

При обращении к `http://ringoouchet.ru/api/health/` возвращается:
```
Bad Request (400)
```

## 🔍 ПРИЧИНА

Django не принимает домен, потому что он не добавлен в `ALLOWED_HOSTS`.

---

## ✅ РЕШЕНИЕ

### ШАГ 1: Обновить .env файл

```bash
cd ~/ringo-uchet/backend
nano .env
```

**Найдите и измените `ALLOWED_HOSTS` или `DJANGO_ALLOWED_HOSTS`:**

**Если есть:**
```env
ALLOWED_HOSTS=91.229.90.72
```

**Или:**
```env
DJANGO_ALLOWED_HOSTS=91.229.90.72
```

**Измените на:**
```env
ALLOWED_HOSTS=ringoouchet.ru,www.ringoouchet.ru,91.229.90.72
```

**Или:**
```env
DJANGO_ALLOWED_HOSTS=ringoouchet.ru,www.ringoouchet.ru,91.229.90.72
```

**Сохраните:** `Ctrl + O`, `Enter`, `Ctrl + X`

---

### ШАГ 2: Проверить как Django читает ALLOWED_HOSTS

**Проверим, как настроены ALLOWED_HOSTS в prod.py:**

```bash
cd ~/ringo-uchet/backend
grep -r "ALLOWED_HOSTS" ringo_backend/settings/
```

**Посмотрим, что в prod.py:**

```bash
cat ringo_backend/settings/prod.py | grep -A 5 ALLOWED_HOSTS
```

---

### ШАГ 3: Перезапустить API

```bash
docker compose -f docker-compose.prod.yml restart api
```

---

### ШАГ 4: Проверка

```bash
curl -v http://ringoouchet.ru/api/health/
```

**Должен вернуть JSON или 200/301, но НЕ 400.**

---

## 🔍 ДОПОЛНИТЕЛЬНАЯ ДИАГНОСТИКА

**Если 400 все еще возникает, проверьте логи:**

```bash
docker compose -f docker-compose.prod.yml logs api | tail -50
```

**Ищите ошибки связанные с ALLOWED_HOSTS.**

---

**После исправления напишите результат!**


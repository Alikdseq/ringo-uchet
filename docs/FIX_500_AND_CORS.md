# 🔧 ИСПРАВЛЕНИЕ: Ошибка 500 + CORS

## ❌ ПРОБЛЕМЫ

1. **HTTP/2 500** - Django возвращает ошибку при логине!
2. **CORS** - нужно разрешить все origins
3. **Ответ:** `{"detail":"Ошибка при получении токена. Проверьте логи сервера."}`

---

## ✅ ИСПРАВЛЕНО

**Обновил `docker-compose.prod.yml` - включил `CORS_ALLOW_ALL_ORIGINS=true`**

---

## ✅ ШАГ 1: Перезапустить API

**На сервере:**

```bash
cd /root/ringo-uchet/backend

# Перезапустить
docker compose -f docker-compose.prod.yml up -d api

# Подождать
sleep 5

# Проверить что запустился
docker compose -f docker-compose.prod.yml ps api
```

---

## ✅ ШАГ 2: Посмотреть логи Django для ошибки 500

**На сервере:**

```bash
cd /root/ringo-uchet/backend

# Посмотреть логи с ошибками
docker compose -f docker-compose.prod.yml logs api --tail=200 | grep -A 30 -i "error\|exception\|traceback\|token\|500"
```

**Ищите:**
- Stack trace
- Exception details
- Причину ошибки 500

**Пришлите логи!**

---

## ✅ ШАГ 3: Тест логина после перезапуска

**На сервере:**

```bash
curl -k -X POST https://ringoouchet.ru/api/v1/token/ \
  -H "Content-Type: application/json" \
  -H "Origin: https://ringoouchet.ru" \
  -d '{"phone":"79991234567","password":"admin123"}' \
  2>&1 | grep -E "< HTTP|token|error|detail|access"
```

**Пришлите результат!**

---

**Выполните ШАГИ 1-3 и пришлите результаты!**


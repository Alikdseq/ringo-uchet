# 🔧 ИСПРАВЛЕНИЕ: Ошибка 500 при логине + CORS

## ❌ ПРОБЛЕМЫ НАЙДЕНЫ

1. **HTTP/2 500** - ошибка сервера при логине
2. **CORS_ALLOWED_ORIGINS** - нет HTTPS в списке!
3. **Ответ:** `{"detail":"Ошибка при получении токена. Проверьте логи сервера."}`

---

## ✅ ИСПРАВЛЕНИЕ 1: Добавить CORS для HTTPS

**Обновил `docker-compose.prod.yml` - включил `CORS_ALLOW_ALL_ORIGINS=true`**

**Теперь нужно:**

```bash
cd /root/ringo-uchet/backend

# Перезапустить API
docker compose -f docker-compose.prod.yml up -d api

# Проверить
docker compose -f docker-compose.prod.yml exec api env | grep CORS
```

---

## ✅ ИСПРАВЛЕНИЕ 2: Проверить логи Django для ошибки 500

**На сервере:**

```bash
cd /root/ringo-uchet/backend

# Смотреть последние логи
docker compose -f docker-compose.prod.yml logs api --tail=100 | grep -A 20 -i "error\|exception\|traceback\|token"
```

**Ищите ошибку которая вызывает 500!**

---

## ✅ ИСПРАВЛЕНИЕ 3: Тест после исправления

**На сервере:**

```bash
# После перезапуска API
sleep 5

# Тест логина
curl -k -X POST https://ringoouchet.ru/api/v1/token/ \
  -H "Content-Type: application/json" \
  -H "Origin: https://ringoouchet.ru" \
  -d '{"phone":"79991234567","password":"admin123"}' \
  -v 2>&1 | grep -E "< HTTP|token|error|detail"
```

---

**Выполните исправления 1-3 и пришлите результаты!**


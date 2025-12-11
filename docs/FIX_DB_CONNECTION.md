# 🔧 БЫСТРОЕ ИСПРАВЛЕНИЕ: Подключение к БД

## ✅ ПРОБЛЕМА

**Пароль в контейнере:** `d44b63fbd381ec5d8c`  
**Нужно проверить пароль в .env и исправить несоответствие!**

---

## ✅ ШАГ 1: Проверить пароль в .env

**На сервере:**

```bash
cd /root/ringo-uchet/backend
echo "Пароль DB_PASSWORD:"
grep "^DB_PASSWORD=" .env | cut -d '=' -f2
echo "Пароль POSTGRES_PASSWORD:"
grep "^POSTGRES_PASSWORD=" .env | cut -d '=' -f2
```

**Скажите: совпадает ли пароль с `d44b63fbd381ec5d8c`?**

---

## 🔧 ШАГ 2: Исправить подключение

### Если пароли НЕ совпадают - обновить пароль в БД:

**На сервере:**

```bash
cd /root/ringo-uchet/backend

# Получить пароль из .env
NEW_PASSWORD=$(grep "^DB_PASSWORD=" .env | cut -d '=' -f2)
echo "Новый пароль: $NEW_PASSWORD"

# Обновить пароль в БД (используя текущий доступ)
docker exec -e PGPASSWORD=d44b63fbd381ec5d8c backend-db-1 psql -U ringo_user -d ringo_prod -c "ALTER USER ringo_user WITH PASSWORD '${NEW_PASSWORD}';"
```

---

### Если пароли совпадают - проверить подключение:

**На сервере:**

```bash
docker exec -e PGPASSWORD=d44b63fbd381ec5d8c backend-db-1 psql -U ringo_user -d ringo_prod -c "SELECT 1;"
```

---

## ✅ ШАГ 3: Перезапустить API после исправления

**На сервере:**

```bash
cd /root/ringo-uchet/backend
docker compose -f docker-compose.prod.yml restart api
sleep 5
curl -k https://ringoouchet.ru/api/health/
```

**Должно быть:** `"database": {"status": "healthy"}`

---

**Сначала выполните ШАГ 1 и скажите результат!**


# 🔧 ИСПРАВЛЕНИЕ: Пароль БД (КОПИРУЙ И ВЫПОЛНЯЙ)

## ✅ ВСЕ В ОДНОЙ КОМАНДЕ

**На сервере выполните ВСЮ эту команду:**

```bash
cd /root/ringo-uchet/backend && DB_PASSWORD=$(grep "^DB_PASSWORD=" .env | cut -d '=' -f2) && [ -z "$DB_PASSWORD" ] && DB_PASSWORD=$(grep "^POSTGRES_PASSWORD=" .env | cut -d '=' -f2) && echo "Пароль из .env: $DB_PASSWORD" && docker exec -e PGPASSWORD=d44b63fbd381ec5d8c backend-db-1 psql -U ringo_user -d ringo_prod -c "ALTER USER ringo_user WITH PASSWORD '${DB_PASSWORD}';" && sed -i "s/^POSTGRES_PASSWORD=.*/POSTGRES_PASSWORD=${DB_PASSWORD}/" .env && docker compose -f docker-compose.prod.yml restart api && sleep 10 && echo "=== ПРОВЕРКА ===" && curl -k https://ringoouchet.ru/api/health/
```

---

## 📋 ИЛИ ПОШАГОВО (если не сработало):

### ШАГ 1: Получить пароль из .env

```bash
cd /root/ringo-uchet/backend
grep "^DB_PASSWORD=" .env | cut -d '=' -f2
```

**Скопируйте пароль!**

---

### ШАГ 2: Обновить пароль в БД (замените `ВАШ_ПАРОЛЬ` на пароль из шага 1)

```bash
docker exec -e PGPASSWORD=d44b63fbd381ec5d8c backend-db-1 psql -U ringo_user -d ringo_prod -c "ALTER USER ringo_user WITH PASSWORD 'ВАШ_ПАРОЛЬ';"
```

---

### ШАГ 3: Перезапустить API

```bash
cd /root/ringo-uchet/backend
docker compose -f docker-compose.prod.yml restart api
sleep 10
```

---

### ШАГ 4: Проверить

```bash
curl -k https://ringoouchet.ru/api/health/
```

**Должно быть:** `"database": {"status": "healthy"}`

---

**Выполните команду и пришлите результат!**


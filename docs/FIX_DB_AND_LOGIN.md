# 🔧 ИСПРАВЛЕНИЕ: База данных и логин

## ❌ ПРОБЛЕМЫ

1. **Ошибка БД:** `password authentication failed for user "ringo_user"`
2. **API доступен через домен, но БД недоступна**
3. **Логин не работает из-за недоступности БД**

---

## ✅ ШАГ 1: Проверить настройки БД

**На сервере выполните:**

```bash
cd /root/ringo-uchet/backend
echo "=== DB настройки в .env ==="
grep -E "DB_|POSTGRES_" .env | grep -v "^#" | sed 's/\(PASSWORD=\).*/\1***СКРЫТО***/'
```

**Пришлите вывод!**

---

## ✅ ШАГ 2: Проверить как запущена БД

**На сервере:**

```bash
echo "=== Контейнеры БД ==="
docker ps | grep -E "db|postgres"

echo "=== Инспект контейнера БД ==="
docker inspect backend-db-1 | grep -A 5 POSTGRES | head -15
```

**Пришлите вывод!**

---

## ✅ ШАГ 3: Проверить доступ к БД как postgres

**На сервере:**

```bash
docker compose -f docker-compose.prod.yml exec db psql -U postgres -c "\du"
```

**Если ошибка "container not found", попробуйте:**

```bash
docker exec backend-db-1 psql -U postgres -c "\du"
```

**Пришлите вывод!**

---

## 🔧 РЕШЕНИЕ: Исправить пароль БД

### Вариант A: Обновить пароль пользователя ringo_user

**На сервере (замените `НОВЫЙ_ПАРОЛЬ` на пароль из .env):**

```bash
cd /root/ringo-uchet/backend

# Получить пароль из .env
DB_PASSWORD=$(grep "^DB_PASSWORD=" .env | cut -d '=' -f2)

# Обновить пароль в БД
docker exec backend-db-1 psql -U postgres -c "ALTER USER ringo_user WITH PASSWORD '${DB_PASSWORD}';"

# Или если использует POSTGRES_PASSWORD:
DB_PASSWORD=$(grep "^POSTGRES_PASSWORD=" .env | cut -d '=' -f2)
docker exec backend-db-1 psql -U postgres -c "ALTER USER ringo_user WITH PASSWORD '${DB_PASSWORD}';"
```

---

### Вариант B: Пересоздать пользователя

**На сервере:**

```bash
cd /root/ringo-uchet/backend

# Получить настройки из .env
DB_USER=$(grep "^DB_USER=" .env | cut -d '=' -f2)
DB_NAME=$(grep "^DB_NAME=" .env | cut -d '=' -f2)
DB_PASSWORD=$(grep "^DB_PASSWORD=" .env | cut -d '=' -f2)

# Пересоздать пользователя
docker exec backend-db-1 psql -U postgres << EOF
DROP USER IF EXISTS ${DB_USER};
CREATE USER ${DB_USER} WITH PASSWORD '${DB_PASSWORD}';
GRANT ALL PRIVILEGES ON DATABASE ${DB_NAME} TO ${DB_USER};
\q
EOF
```

---

## ✅ ПРОВЕРКА после исправления

**На сервере:**

```bash
curl -k https://ringoouchet.ru/api/health/
```

**Должно быть:** `"database": {"status": "healthy"}`

---

**Сначала выполните ШАГИ 1-3 и пришлите результаты!**


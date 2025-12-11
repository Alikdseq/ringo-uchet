# 🔧 АВТОМАТИЧЕСКОЕ ИСПРАВЛЕНИЕ: Пароль БД

## 🎯 ЦЕЛЬ

**Автоматически исправить пароль БД чтобы совпадал с .env!**

---

## ✅ РЕШЕНИЕ (все в одном)

**На сервере выполните:**

```bash
cd /root/ringo-uchet/backend

# Шаг 1: Получить пароль из .env
DB_PASSWORD=$(grep "^DB_PASSWORD=" .env | cut -d '=' -f2)

# Если DB_PASSWORD пустой, попробуем POSTGRES_PASSWORD
if [ -z "$DB_PASSWORD" ]; then
    DB_PASSWORD=$(grep "^POSTGRES_PASSWORD=" .env | cut -d '=' -f2)
fi

echo "Пароль из .env: $DB_PASSWORD"

# Шаг 2: Обновить пароль в БД (используя текущий пароль из контейнера)
docker exec -e PGPASSWORD=d44b63fbd381ec5d8c backend-db-1 psql -U ringo_user -d ringo_prod -c "ALTER USER ringo_user WITH PASSWORD '${DB_PASSWORD}';"

# Шаг 3: Убедиться что POSTGRES_PASSWORD тоже обновлен в .env
sed -i "s/^POSTGRES_PASSWORD=.*/POSTGRES_PASSWORD=${DB_PASSWORD}/" .env

# Шаг 4: Перезапустить API
docker compose -f docker-compose.prod.yml restart api

# Шаг 5: Подождать и проверить
sleep 10
echo "=== Проверка API ==="
curl -k https://ringoouchet.ru/api/health/
```

---

**Выполните эту команду и пришлите результат!**


# 🔧 ИСПРАВЛЕНИЕ: Ошибка пароля базы данных

## ❌ ПРОБЛЕМА

**Ошибка:** `password authentication failed for user "ringo_user"`

**API работает через домен, но БД недоступна - поэтому логин не работает!**

---

## ✅ ПОШАГОВОЕ РЕШЕНИЕ

### ШАГ 1: Проверить настройки БД в .env

**На сервере:**

```bash
cd /root/ringo-uchet/backend
grep -E "DB_|POSTGRES_" .env | grep -v "^#"
```

**Пришлите вывод (скройте реальные пароли для безопасности)!**

---

### ШАГ 2: Проверить какой пароль использует контейнер БД

**На сервере:**

```bash
docker compose -f docker-compose.prod.yml exec db env | grep POSTGRES
```

**Если контейнер db не найден, проверьте как он запущен:**

```bash
docker ps | grep postgres
docker inspect backend-db-1 | grep -A 10 POSTGRES
```

**Пришлите вывод!**

---

### ШАГ 3: Проверить какие контейнеры БД запущены

**На сервере:**

```bash
docker ps -a | grep -E "db|postgres"
```

**Пришлите вывод!**

---

### ШАГ 4: Проверить логи БД

**На сервере:**

```bash
docker logs backend-db-1 --tail=30
```

**Ищите ошибки авторизации!**

---

## 🔧 ВОЗМОЖНЫЕ РЕШЕНИЯ

### РЕШЕНИЕ 1: Если пароли не совпадают - обновить пароль в БД

**Вариант A: Если есть доступ к БД как postgres**

```bash
docker compose -f docker-compose.prod.yml exec db psql -U postgres -c "ALTER USER ringo_user WITH PASSWORD 'новый_пароль_из_env';"
```

**Вариант B: Пересоздать пользователя**

```bash
docker compose -f docker-compose.prod.yml exec db psql -U postgres -c "DROP USER IF EXISTS ringo_user;"
docker compose -f docker-compose.prod.yml exec db psql -U postgres -c "CREATE USER ringo_user WITH PASSWORD 'пароль_из_env';"
docker compose -f docker-compose.prod.yml exec db psql -U postgres -c "GRANT ALL PRIVILEGES ON DATABASE ringo_db TO ringo_user;"
```

---

### РЕШЕНИЕ 2: Если БД создана с другими параметрами - пересоздать

**ОСТОРОЖНО: Это удалит все данные!**

```bash
cd /root/ringo-uchet/backend

# Остановить все контейнеры
docker compose -f docker-compose.prod.yml down

# Найти и удалить том БД
docker volume ls | grep postgres
# Замените на реальное имя тома:
docker volume rm backend_postgres_data

# Запустить заново
docker compose -f docker-compose.prod.yml up -d

# Подождать пока БД запустится
sleep 10

# Выполнить миграции
docker compose -f docker-compose.prod.yml exec api python manage.py migrate
```

---

### РЕШЕНИЕ 3: Если контейнер БД не определен в docker-compose.prod.yml

**Нужно добавить определение БД в docker-compose.prod.yml!**

---

**Сначала выполните ШАГИ 1-4 и пришлите результаты!**


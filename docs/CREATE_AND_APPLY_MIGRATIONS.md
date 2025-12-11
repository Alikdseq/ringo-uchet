# 🔧 СОЗДАНИЕ И ПРИМЕНЕНИЕ МИГРАЦИЙ В ПРОДАКШЕНЕ

## 🎯 ЦЕЛЬ
Создать миграции для изменений в модели `orders` и применить их в продакшене.

---

## 📋 ШАГ 1: Временно убрать :ro из docker-compose.prod.yml на сервере

**На сервере:**

```bash
cd ~/ringo-uchet/backend

# Создать резервную копию
cp docker-compose.prod.yml docker-compose.prod.yml.backup

# Временно убрать :ro из volumes для orders
sed -i 's|./orders:/app/orders:ro|./orders:/app/orders|g' docker-compose.prod.yml

# Проверить что изменилось
grep -A 2 "orders:" docker-compose.prod.yml | head -5
```

**Должно быть:**
```yaml
- ./orders:/app/orders
```
Вместо:
```yaml
- ./orders:/app/orders:ro
```

---

## 📋 ШАГ 2: Перезапустить контейнеры

**На сервере:**

```bash
cd ~/ringo-uchet/backend

# Перезапустить контейнеры чтобы применить изменения
docker compose -f docker-compose.prod.yml restart api celery-worker celery-beat

# Подождать запуска
sleep 10

# Проверить статус
docker compose -f docker-compose.prod.yml ps api
```

---

## 📋 ШАГ 3: Создать миграции

**На сервере:**

```bash
cd ~/ringo-uchet/backend

# Создать миграции
docker compose -f docker-compose.prod.yml exec api python manage.py makemigrations

# Должно показать:
# Migrations for 'orders':
#   orders/migrations/0007_alter_order_status_alter_orderstatuslog_from_status_and_more.py
#     - Alter field status on order
#     - Alter field from_status on orderstatuslog
#     - Alter field to_status on orderstatuslog
```

---

## 📋 ШАГ 4: Проверить что миграции созданы

**На сервере:**

```bash
cd ~/ringo-uchet/backend

# Проверить что файл миграции создан
ls -la orders/migrations/0007_*.py

# Посмотреть содержимое миграции
cat orders/migrations/0007_*.py | head -30
```

---

## 📋 ШАГ 5: Применить миграции

**На сервере:**

```bash
cd ~/ringo-uchet/backend

# Применить миграции
docker compose -f docker-compose.prod.yml exec api python manage.py migrate

# Должно показать:
# Running migrations:
#   Applying orders.0007_alter_order_status_alter_orderstatuslog_from_status_and_more... OK
```

---

## 📋 ШАГ 6: Вернуть :ro обратно

**На сервере:**

```bash
cd ~/ringo-uchet/backend

# Вернуть :ro обратно
sed -i 's|./orders:/app/orders|./orders:/app/orders:ro|g' docker-compose.prod.yml

# Проверить что вернулось
grep -A 2 "orders:" docker-compose.prod.yml | head -5

# Перезапустить контейнеры
docker compose -f docker-compose.prod.yml restart api celery-worker celery-beat
```

---

## 📋 ШАГ 7: Закоммитить миграции в репозиторий

**На сервере:**

```bash
cd ~/ringo-uchet/backend

# Проверить статус
git status

# Добавить файл миграции
git add orders/migrations/0007_*.py

# Закоммитить
git commit -m "Add migration for order status changes (DELETED status)"

# Запушить в репозиторий
git push origin master
```

---

## 📋 ШАГ 8: Обновить код на локальной машине

**На вашем компьютере (PowerShell):**

```powershell
cd C:\ringo-uchet\backend
git pull origin master
```

---

## 🚀 БЫСТРАЯ КОМАНДА (ВСЕ СРАЗУ)

**На сервере выполните все команды подряд:**

```bash
cd ~/ringo-uchet/backend && \
cp docker-compose.prod.yml docker-compose.prod.yml.backup && \
sed -i 's|./orders:/app/orders:ro|./orders:/app/orders|g' docker-compose.prod.yml && \
docker compose -f docker-compose.prod.yml restart api celery-worker celery-beat && \
sleep 10 && \
docker compose -f docker-compose.prod.yml exec api python manage.py makemigrations && \
docker compose -f docker-compose.prod.yml exec api python manage.py migrate && \
sed -i 's|./orders:/app/orders|./orders:/app/orders:ro|g' docker-compose.prod.yml && \
docker compose -f docker-compose.prod.yml restart api celery-worker celery-beat && \
git add orders/migrations/0007_*.py && \
git commit -m "Add migration for order status changes" && \
git push origin master && \
echo "✅ Миграции созданы и применены!"
```

---

## ✅ ПРОВЕРКА ПОСЛЕ ПРИМЕНЕНИЯ

**На сервере:**

```bash
cd ~/ringo-uchet/backend

# Проверить что миграции применены
docker compose -f docker-compose.prod.yml exec api python manage.py migrate

# Должно быть:
# Running migrations:
#   No migrations to apply.

# Проверить что предупреждение исчезло
docker compose -f docker-compose.prod.yml exec api python manage.py showmigrations orders
```

---

## 🔍 ЕСЛИ ЧТО-ТО ПОШЛО НЕ ТАК

### Проблема: sed не работает

**Решение:**
```bash
# Вручную отредактировать файл
nano docker-compose.prod.yml

# Найти строки:
# - ./orders:/app/orders:ro
# Заменить на:
# - ./orders:/app/orders

# Сохранить (Ctrl+O, Enter, Ctrl+X)
```

### Проблема: Миграции не создаются

**Решение:**
```bash
# Проверить что папка orders доступна для записи
docker compose -f docker-compose.prod.yml exec api ls -la /app/orders/migrations/

# Проверить права доступа
ls -la orders/migrations/
```

### Проблема: Git push не работает

**Решение:**
```bash
# Проверить статус
git status

# Если нужно настроить git
git config user.name "Ваше имя"
git config user.email "ваш@email.com"

# Попробовать push снова
git push origin master
```

---

**Начните с ШАГА 1 - временно уберите :ro из docker-compose.prod.yml!** 🚀


# 🔧 ИСПРАВЛЕНИЕ ОПЕЧАТКИ orderss -> orders

## 🔴 ПРОБЛЕМА
После выполнения sed команды получилось `./orders:/app/orderss` вместо `./orders:/app/orders`

---

## ✅ БЫСТРОЕ ИСПРАВЛЕНИЕ

**На сервере:**

```bash
cd ~/ringo-uchet/backend

# Исправить опечатку
sed -i 's|./orders:/app/orderss|./orders:/app/orders|g' docker-compose.prod.yml

# Проверить что исправлено
grep "orders:" docker-compose.prod.yml

# Должно быть:
# - ./orders:/app/orders
# (БЕЗ двойного 's')
```

---

## 🚀 ПОЛНАЯ ПОСЛЕДОВАТЕЛЬНОСТЬ (С ИСПРАВЛЕНИЕМ)

**На сервере выполните все команды подряд:**

```bash
cd ~/ringo-uchet/backend && \
# Исправить опечатку
sed -i 's|./orders:/app/orderss|./orders:/app/orders|g' docker-compose.prod.yml && \
# Проверить
grep "orders:" docker-compose.prod.yml && \
# Полностью пересоздать контейнеры
docker compose -f docker-compose.prod.yml down && \
docker compose -f docker-compose.prod.yml up -d && \
sleep 25 && \
# Создать миграции
docker compose -f docker-compose.prod.yml exec api python manage.py makemigrations && \
# Применить миграции
docker compose -f docker-compose.prod.yml exec api python manage.py migrate && \
# Вернуть :ro обратно
sed -i 's|./orders:/app/orders|./orders:/app/orders:ro|g' docker-compose.prod.yml && \
# Пересоздать контейнеры
docker compose -f docker-compose.prod.yml down && \
docker compose -f docker-compose.prod.yml up -d && \
# Закоммитить миграции
git add orders/migrations/0007_*.py && \
git commit -m "Add migration for order status changes" && \
git push origin master && \
echo "✅ Готово!"
```

---

**Сначала исправьте опечатку, затем продолжайте!** 🚀


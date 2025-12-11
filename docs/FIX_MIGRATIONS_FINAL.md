# 🔧 ФИНАЛЬНОЕ ИСПРАВЛЕНИЕ МИГРАЦИЙ

## 🔴 ПРОБЛЕМА
Контейнеры все еще используют старые volumes, даже после изменения docker-compose.prod.yml.

---

## ✅ РЕШЕНИЕ: Полностью пересоздать контейнеры

**На сервере выполните все команды подряд:**

```bash
cd ~/ringo-uchet/backend

# 1. Проверить что :ro убран везде
grep "orders:" docker-compose.prod.yml

# 2. Исправить опечатку если есть (./orders:/app/order -> ./orders:/app/orders)
sed -i 's|./orders:/app/order|./orders:/app/orders|g' docker-compose.prod.yml

# 3. Убедиться что везде БЕЗ :ro
sed -i 's|./orders:/app/orders:ro|./orders:/app/orders|g' docker-compose.prod.yml

# 4. Проверить что исправлено
grep "orders:" docker-compose.prod.yml

# 5. ПОЛНОСТЬЮ остановить и удалить контейнеры
docker compose -f docker-compose.prod.yml down

# 6. Запустить заново (создаст новые контейнеры с правильными volumes)
docker compose -f docker-compose.prod.yml up -d

# 7. Подождать полного запуска
sleep 25

# 8. Проверить статус
docker compose -f docker-compose.prod.yml ps

# 9. Создать миграции
docker compose -f docker-compose.prod.yml exec api python manage.py makemigrations

# 10. Применить миграции
docker compose -f docker-compose.prod.yml exec api python manage.py migrate

# 11. Проверить что миграции применены
docker compose -f docker-compose.prod.yml exec api python manage.py migrate

# 12. Вернуть :ro обратно
sed -i 's|./orders:/app/orders|./orders:/app/orders:ro|g' docker-compose.prod.yml

# 13. Пересоздать контейнеры снова
docker compose -f docker-compose.prod.yml down
docker compose -f docker-compose.prod.yml up -d

# 14. Закоммитить миграции
git add orders/migrations/0007_*.py
git commit -m "Add migration for order status changes (DELETED status)"
git push origin master

echo "✅ Миграции созданы и применены!"
```

---

## 🚀 ОДНА КОМАНДА (ВСЕ СРАЗУ)

```bash
cd ~/ringo-uchet/backend && \
sed -i 's|./orders:/app/order|./orders:/app/orders|g' docker-compose.prod.yml && \
sed -i 's|./orders:/app/orders:ro|./orders:/app/orders|g' docker-compose.prod.yml && \
docker compose -f docker-compose.prod.yml down && \
docker compose -f docker-compose.prod.yml up -d && \
sleep 25 && \
docker compose -f docker-compose.prod.yml exec api python manage.py makemigrations && \
docker compose -f docker-compose.prod.yml exec api python manage.py migrate && \
sed -i 's|./orders:/app/orders|./orders:/app/orders:ro|g' docker-compose.prod.yml && \
docker compose -f docker-compose.prod.yml down && \
docker compose -f docker-compose.prod.yml up -d && \
git add orders/migrations/0007_*.py && \
git commit -m "Add migration for order status changes" && \
git push origin master && \
echo "✅ Готово!"
```

---

**ВАЖНО:** Используйте `down` + `up`, а не `restart` - это пересоздаст контейнеры с новыми volumes!


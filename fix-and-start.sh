#!/bin/bash
# Скрипт для исправления и запуска проекта

echo "🔧 Исправление и запуск Ringo Uchet..."

echo "1️⃣ Останавливаем контейнеры..."
docker compose down

echo "2️⃣ Пересобираем образы с новыми зависимостями..."
docker compose build --no-cache django-api celery celery-beat

echo "3️⃣ Запускаем контейнеры..."
docker compose up -d

echo "4️⃣ Ждём инициализации базы данных (10 секунд)..."
sleep 10

echo "5️⃣ Применяем миграции..."
docker compose exec django-api python manage.py migrate

echo "6️⃣ Проверяем статус WeasyPrint..."
docker compose exec django-api python -c "
try:
    from weasyprint import HTML
    print('✅ WeasyPrint работает корректно!')
except Exception as e:
    print(f'❌ WeasyPrint не работает: {e}')
"

echo ""
echo "✅ Готово! Теперь создайте суперпользователя:"
echo "   docker compose exec django-api python manage.py shell"
echo ""
echo "   Затем в Python shell выполните:"
echo "   from users.models import User"
echo "   User.objects.create_superuser("
echo "       phone='+79991234567',"
echo "       email='admin@ringo.local',"
echo "       password='admin123',"
echo "       role='admin'"
echo "   )"
echo ""
echo "🌐 Админка: http://localhost:8000/admin/"
echo "📚 API Docs: http://localhost:8000/api/docs/"


# Полное исправление и запуск проекта

Write-Host "🔧 Полное исправление проекта Ringo Uchet..." -ForegroundColor Cyan

Write-Host "`n1️⃣ Останавливаем контейнеры..." -ForegroundColor Yellow
docker compose down

Write-Host "`n2️⃣ Пересобираем образы с зависимостями WeasyPrint..." -ForegroundColor Yellow
docker compose build --no-cache django-api celery celery-beat

Write-Host "`n3️⃣ Запускаем контейнеры..." -ForegroundColor Yellow
docker compose up -d

Write-Host "`n4️⃣ Ждём инициализации (15 секунд)..." -ForegroundColor Yellow
Start-Sleep -Seconds 15

Write-Host "`n5️⃣ Применяем миграции..." -ForegroundColor Yellow
docker compose exec django-api python manage.py migrate

Write-Host "`n6️⃣ Проверяем WeasyPrint..." -ForegroundColor Yellow
docker compose exec django-api python -c "try:
    from weasyprint import HTML
    print('✅ WeasyPrint работает!')
except Exception as e:
    print(f'⚠️ WeasyPrint не работает: {e}')"

Write-Host "`n✅ Готово! Теперь создайте суперпользователя:" -ForegroundColor Green
Write-Host "   docker compose exec django-api python manage.py shell" -ForegroundColor White
Write-Host ""
Write-Host "   В Python shell:" -ForegroundColor White
Write-Host "   from users.models import User" -ForegroundColor Gray
Write-Host "   User.objects.create_superuser(" -ForegroundColor Gray
Write-Host "       phone='+79991234567'," -ForegroundColor Gray
Write-Host "       email='admin@ringo.local'," -ForegroundColor Gray
Write-Host "       password='admin123'," -ForegroundColor Gray
Write-Host "       role='admin'" -ForegroundColor Gray
Write-Host "   )" -ForegroundColor Gray
Write-Host "   exit()" -ForegroundColor Gray
Write-Host ""
Write-Host "🌐 Админка: http://localhost:8000/admin/" -ForegroundColor Cyan
Write-Host "📚 API Docs: http://localhost:8000/api/docs/" -ForegroundColor Cyan


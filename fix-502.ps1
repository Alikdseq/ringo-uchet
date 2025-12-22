# Скрипт для исправления ошибки 502 Bad Gateway
# Запуск: .\fix-502.ps1

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Исправление ошибки 502 Bad Gateway" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Проверка, что мы в правильной директории
if (-not (Test-Path "docker-compose.yml")) {
    Write-Host "ОШИБКА: docker-compose.yml не найден!" -ForegroundColor Red
    Write-Host "Убедитесь, что вы находитесь в корне проекта (C:\ringo-uchet\)" -ForegroundColor Yellow
    exit 1
}

Write-Host "[ШАГ 1/6] Остановка текущих контейнеров..." -ForegroundColor Yellow
docker-compose down
if ($LASTEXITCODE -ne 0) {
    Write-Host "Предупреждение: некоторые контейнеры могли не остановиться" -ForegroundColor Yellow
}
Write-Host "✓ Контейнеры остановлены" -ForegroundColor Green
Write-Host ""

Write-Host "[ШАГ 2/6] Проверка файлов..." -ForegroundColor Yellow
$files = @(
    "frontend\Dockerfile",
    "frontend\.dockerignore",
    "infra\nginx\default.conf",
    "docker-compose.yml"
)

$allFilesExist = $true
foreach ($file in $files) {
    if (Test-Path $file) {
        Write-Host "  ✓ $file" -ForegroundColor Green
    } else {
        Write-Host "  ✗ $file - НЕ НАЙДЕН!" -ForegroundColor Red
        $allFilesExist = $false
    }
}

if (-not $allFilesExist) {
    Write-Host ""
    Write-Host "ОШИБКА: Не все необходимые файлы найдены!" -ForegroundColor Red
    exit 1
}
Write-Host ""

Write-Host "[ШАГ 3/6] Пересборка frontend контейнера..." -ForegroundColor Yellow
Write-Host "Это может занять 5-10 минут..." -ForegroundColor Gray
docker-compose build --no-cache frontend
if ($LASTEXITCODE -ne 0) {
    Write-Host ""
    Write-Host "ОШИБКА: Не удалось собрать frontend контейнер!" -ForegroundColor Red
    Write-Host "Проверьте логи выше для деталей" -ForegroundColor Yellow
    exit 1
}
Write-Host "✓ Frontend собран успешно" -ForegroundColor Green
Write-Host ""

Write-Host "[ШАГ 4/6] Запуск всех сервисов..." -ForegroundColor Yellow
docker-compose up -d
if ($LASTEXITCODE -ne 0) {
    Write-Host ""
    Write-Host "ОШИБКА: Не удалось запустить сервисы!" -ForegroundColor Red
    exit 1
}
Write-Host "✓ Сервисы запущены" -ForegroundColor Green
Write-Host ""

Write-Host "[ШАГ 5/6] Ожидание запуска сервисов (10 секунд)..." -ForegroundColor Yellow
Start-Sleep -Seconds 10

Write-Host "[ШАГ 6/6] Проверка статуса..." -ForegroundColor Yellow
docker-compose ps
Write-Host ""

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Проверка логов (последние 20 строк):" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "--- Frontend ---" -ForegroundColor Yellow
docker-compose logs --tail=20 frontend
Write-Host ""
Write-Host "--- Nginx ---" -ForegroundColor Yellow
docker-compose logs --tail=20 nginx
Write-Host ""

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "ГОТОВО!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Следующие шаги:" -ForegroundColor Yellow
Write-Host "1. Откройте браузер и перейдите на http://localhost" -ForegroundColor White
Write-Host "2. Откройте DevTools (F12) → Console" -ForegroundColor White
Write-Host "3. Проверьте, что нет ошибок 502" -ForegroundColor White
Write-Host ""
Write-Host "Если нужны логи в реальном времени:" -ForegroundColor Gray
Write-Host "  docker-compose logs -f frontend nginx" -ForegroundColor Gray
Write-Host ""
Write-Host "Если нужно остановить все:" -ForegroundColor Gray
Write-Host "  docker-compose down" -ForegroundColor Gray
Write-Host ""


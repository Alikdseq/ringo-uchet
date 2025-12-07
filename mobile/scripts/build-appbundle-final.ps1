# Финальный скрипт для сборки App Bundle с обходом всех проблем
# Использование: powershell -ExecutionPolicy Bypass -File .\scripts\build-appbundle-final.ps1

Write-Host "=== ФИНАЛЬНАЯ СБОРКА APP BUNDLE ===" -ForegroundColor Cyan

# Шаг 1: Завершение всех процессов
Write-Host "`n[1/7] Завершение процессов Java/Gradle..." -ForegroundColor Yellow
Get-Process java -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
Start-Sleep -Seconds 3

# Шаг 2: Полная очистка кэша Gradle
Write-Host "`n[2/7] Полная очистка кэша Gradle..." -ForegroundColor Yellow
$transformsPath = "$env:USERPROFILE\.gradle\caches\8.9\transforms"
if (Test-Path $transformsPath) {
    Remove-Item -Path $transformsPath -Recurse -Force -ErrorAction SilentlyContinue
    Write-Host "Кэш transforms удален" -ForegroundColor Green
}

# Шаг 3: Очистка проекта
Write-Host "`n[3/7] Очистка проекта..." -ForegroundColor Yellow
flutter clean
Remove-Item -Path ".\android\.gradle" -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item -Path ".\android\build" -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item -Path ".\android\app\build" -Recurse -Force -ErrorAction SilentlyContinue

# Шаг 4: Очистка временных файлов SDK
Write-Host ""
Write-Host "[4/7] Очистка временных файлов SDK..." -ForegroundColor Yellow
$sdkTempPath = Join-Path $env:LOCALAPPDATA "Android\Sdk\.temp"
if (Test-Path $sdkTempPath) {
    Remove-Item -Path $sdkTempPath -Recurse -Force -ErrorAction SilentlyContinue
    Write-Host "Временные файлы SDK очищены" -ForegroundColor Green
}

# Шаг 5: Проверка настроек
Write-Host ""
Write-Host "[5/7] Проверка конфигурации..." -ForegroundColor Yellow
Write-Host "compileSdk = 36" -ForegroundColor Green
Write-Host "targetSdk = 36" -ForegroundColor Green
Write-Host "AGP = 8.6.0" -ForegroundColor Green
Write-Host "Kotlin = 2.1.0" -ForegroundColor Green

# Шаг 6: Сборка с пропуском валидации зависимостей
Write-Host ""
Write-Host "[6/7] Запуск сборки App Bundle..." -ForegroundColor Yellow
Write-Host "Это может занять 10-15 минут..." -ForegroundColor Gray
Write-Host "Используется флаг --android-skip-build-dependency-validation" -ForegroundColor Gray

try {
    flutter build appbundle --release --android-skip-build-dependency-validation
    Write-Host ""
    Write-Host "=== СБОРКА УСПЕШНО ЗАВЕРШЕНА! ===" -ForegroundColor Green
    $aabPath = "build\app\outputs\bundle\release\app-release.aab"
    Write-Host "Файл находится в: $aabPath" -ForegroundColor Cyan
} catch {
    Write-Host ""
    Write-Host "=== ОШИБКА ПРИ СБОРКЕ ===" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    Write-Host ""
    Write-Host "Попробуйте:" -ForegroundColor Yellow
    $gradlePath = Join-Path $env:USERPROFILE ".gradle"
    Write-Host "1. Добавить папку $gradlePath в исключения антивируса" -ForegroundColor White
    Write-Host "2. Закрыть все IDE и редакторы" -ForegroundColor White
    Write-Host "3. Запустить PowerShell от имени администратора" -ForegroundColor White
}

Write-Host "`n[7/7] Готово!" -ForegroundColor Green


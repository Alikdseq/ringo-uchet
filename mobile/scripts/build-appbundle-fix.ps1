# Скрипт для сборки App Bundle с обходом проблемы кэша Gradle
# Использование: powershell -ExecutionPolicy Bypass -File .\scripts\build-appbundle-fix.ps1

Write-Host "=== Сборка App Bundle с исправлением проблем Gradle ===" -ForegroundColor Cyan

# Шаг 1: Завершение всех процессов
Write-Host "`n[1/6] Завершение процессов Java/Gradle..." -ForegroundColor Yellow
Get-Process java -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
Start-Sleep -Seconds 2

# Шаг 2: Удаление проблемного кэша
Write-Host "`n[2/6] Удаление проблемного кэша transforms..." -ForegroundColor Yellow
$transformsPath = "$env:USERPROFILE\.gradle\caches\8.9\transforms"
if (Test-Path $transformsPath) {
    Remove-Item -Path $transformsPath -Recurse -Force -ErrorAction SilentlyContinue
    Write-Host "Кэш transforms удален" -ForegroundColor Green
}

# Шаг 3: Очистка проекта
Write-Host "`n[3/6] Очистка проекта..." -ForegroundColor Yellow
flutter clean
Remove-Item -Path ".\android\.gradle" -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item -Path ".\android\build" -Recurse -Force -ErrorAction SilentlyContinue

# Шаг 4: Установка переменной окружения для использования временного кэша
Write-Host "`n[4/6] Настройка временного кэша Gradle..." -ForegroundColor Yellow
$tempGradleCache = "$env:TEMP\gradle-cache-$(Get-Random)"
New-Item -ItemType Directory -Path $tempGradleCache -Force | Out-Null
$env:GRADLE_USER_HOME = $tempGradleCache
Write-Host "Временный кэш: $tempGradleCache" -ForegroundColor Gray

# Шаг 5: Сборка с использованием временного кэша
Write-Host "`n[5/6] Запуск сборки App Bundle..." -ForegroundColor Yellow
Write-Host "Это может занять несколько минут..." -ForegroundColor Gray

try {
    flutter build appbundle --release
    Write-Host "`n=== Сборка успешно завершена! ===" -ForegroundColor Green
} catch {
    Write-Host "`n=== Ошибка при сборке ===" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
} finally {
    # Шаг 6: Очистка временного кэша
    Write-Host "`n[6/6] Очистка временного кэша..." -ForegroundColor Yellow
    Remove-Item -Path $tempGradleCache -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Variable -Name GRADLE_USER_HOME -ErrorAction SilentlyContinue
}

Write-Host "`nГотово!" -ForegroundColor Green


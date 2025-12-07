# Скрипт для исправления проблем с кэшем Gradle на Windows
# Использование: .\scripts\fix-gradle-cache.ps1

Write-Host "=== Исправление проблем с Gradle кэшем ===" -ForegroundColor Cyan

# Шаг 1: Завершение всех процессов Gradle
Write-Host "`n[1/5] Завершение процессов Gradle..." -ForegroundColor Yellow
$gradleProcesses = Get-Process -Name "java" -ErrorAction SilentlyContinue | Where-Object { $_.CommandLine -like "*gradle*" }
if ($gradleProcesses) {
    Write-Host "Найдено процессов Gradle: $($gradleProcesses.Count)" -ForegroundColor Yellow
    $gradleProcesses | ForEach-Object {
        Write-Host "Завершение процесса: $($_.Id) - $($_.ProcessName)" -ForegroundColor Gray
        Stop-Process -Id $_.Id -Force -ErrorAction SilentlyContinue
    }
    Start-Sleep -Seconds 2
} else {
    Write-Host "Процессы Gradle не найдены" -ForegroundColor Green
}

# Шаг 2: Очистка кэша Gradle
Write-Host "`n[2/5] Очистка кэша Gradle..." -ForegroundColor Yellow
$gradleCachePath = "$env:USERPROFILE\.gradle\caches"
if (Test-Path $gradleCachePath) {
    Write-Host "Удаление кэша: $gradleCachePath" -ForegroundColor Gray
    try {
        # Удаляем только проблемную директорию transforms
        $transformsPath = Join-Path $gradleCachePath "8.9\transforms"
        if (Test-Path $transformsPath) {
            Remove-Item -Path $transformsPath -Recurse -Force -ErrorAction SilentlyContinue
            Write-Host "Директория transforms очищена" -ForegroundColor Green
        }
        
        # Очищаем также временные файлы
        $tmpPath = Join-Path $gradleCachePath "8.9\tmp"
        if (Test-Path $tmpPath) {
            Remove-Item -Path $tmpPath -Recurse -Force -ErrorAction SilentlyContinue
            Write-Host "Временные файлы очищены" -ForegroundColor Green
        }
    } catch {
        Write-Host "Предупреждение: Не удалось полностью очистить кэш: $_" -ForegroundColor Yellow
        Write-Host "Попробуйте закрыть все IDE и повторите попытку" -ForegroundColor Yellow
    }
} else {
    Write-Host "Кэш Gradle не найден" -ForegroundColor Green
}

# Шаг 3: Очистка локального кэша проекта
Write-Host "`n[3/5] Очистка локального кэша проекта..." -ForegroundColor Yellow
$projectBuildPath = ".\android\.gradle"
if (Test-Path $projectBuildPath) {
    Remove-Item -Path $projectBuildPath -Recurse -Force -ErrorAction SilentlyContinue
    Write-Host "Локальный кэш проекта очищен" -ForegroundColor Green
}

$projectBuildPath = ".\android\build"
if (Test-Path $projectBuildPath) {
    Remove-Item -Path $projectBuildPath -Recurse -Force -ErrorAction SilentlyContinue
    Write-Host "Директория build очищена" -ForegroundColor Green
}

# Шаг 4: Очистка кэша Flutter
Write-Host "`n[4/5] Очистка кэша Flutter..." -ForegroundColor Yellow
flutter clean
Write-Host "Кэш Flutter очищен" -ForegroundColor Green

# Шаг 5: Проверка и исправление прав доступа
Write-Host "`n[5/5] Проверка прав доступа..." -ForegroundColor Yellow
$gradleUserHome = "$env:USERPROFILE\.gradle"
if (Test-Path $gradleUserHome) {
    try {
        $acl = Get-Acl $gradleUserHome
        $permission = $acl.Access | Where-Object { $_.IdentityReference -like "*$env:USERNAME*" }
        if ($permission) {
            Write-Host "Права доступа в порядке" -ForegroundColor Green
        }
    } catch {
        Write-Host "Не удалось проверить права доступа" -ForegroundColor Yellow
    }
}

Write-Host "`n=== Готово! ===" -ForegroundColor Green
Write-Host "Теперь попробуйте выполнить сборку снова:" -ForegroundColor Cyan
Write-Host "  flutter build appbundle --release" -ForegroundColor White
Write-Host "`nЕсли проблема сохраняется:" -ForegroundColor Yellow
Write-Host "  1. Добавьте папку $env:USERPROFILE\.gradle в исключения антивируса" -ForegroundColor White
Write-Host "  2. Закройте все IDE и редакторы кода" -ForegroundColor White
Write-Host "  3. Запустите PowerShell от имени администратора" -ForegroundColor White


# Скрипт для сборки Android App Bundle с исправлением проблемы кириллицы в путях Windows
# Использование: .\scripts\build-appbundle.ps1

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Сборка Android App Bundle" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Проверка наличия Flutter
$flutterPath = Get-Command flutter -ErrorAction SilentlyContinue
if (-not $flutterPath) {
    Write-Host "ОШИБКА: Flutter не найден в PATH!" -ForegroundColor Red
    exit 1
}

# Создание директорий для Gradle без кириллицы
$gradleHome = "C:\gradle-home"
$gradleTemp = "C:\gradle-temp"

Write-Host "Создание директорий для Gradle..." -ForegroundColor Yellow
if (-not (Test-Path $gradleHome)) {
    New-Item -ItemType Directory -Path $gradleHome -Force | Out-Null
    Write-Host "  Создана директория: $gradleHome" -ForegroundColor Green
}
if (-not (Test-Path $gradleTemp)) {
    New-Item -ItemType Directory -Path $gradleTemp -Force | Out-Null
    Write-Host "  Создана директория: $gradleTemp" -ForegroundColor Green
}

# Установка переменных окружения для текущей сессии
Write-Host ""
Write-Host "Настройка переменных окружения..." -ForegroundColor Yellow
$env:GRADLE_USER_HOME = $gradleHome
$env:GRADLE_OPTS = "-Djava.io.tmpdir=$gradleTemp -Dfile.encoding=UTF-8"
$env:JAVA_TOOL_OPTIONS = "-Dfile.encoding=UTF-8"
$env:TEMP = $gradleTemp
$env:TMP = $gradleTemp

Write-Host "  GRADLE_USER_HOME = $env:GRADLE_USER_HOME" -ForegroundColor Green
Write-Host "  TEMP = $env:TEMP" -ForegroundColor Green
Write-Host ""

# Переход в директорию проекта
$projectRoot = Split-Path -Parent $PSScriptRoot
Set-Location $projectRoot

Write-Host "Текущая директория: $projectRoot" -ForegroundColor Cyan
Write-Host ""

# Очистка предыдущих сборок
Write-Host "Очистка предыдущих сборок..." -ForegroundColor Yellow
flutter clean | Out-Null
Write-Host "  Очистка завершена" -ForegroundColor Green
Write-Host ""

# Получение зависимостей
Write-Host "Получение зависимостей Flutter..." -ForegroundColor Yellow
flutter pub get
if ($LASTEXITCODE -ne 0) {
    Write-Host "ОШИБКА: Не удалось получить зависимости!" -ForegroundColor Red
    exit 1
}
Write-Host "  Зависимости получены" -ForegroundColor Green
Write-Host ""

# Очистка кэша Gradle (опционально, если есть проблемы)
Write-Host "Очистка кэша Gradle..." -ForegroundColor Yellow
if (Test-Path "$gradleHome\caches") {
    Remove-Item -Path "$gradleHome\caches\*" -Recurse -Force -ErrorAction SilentlyContinue
    Write-Host "  Кэш Gradle очищен" -ForegroundColor Green
}
Write-Host ""

# Сборка App Bundle
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Начало сборки App Bundle..." -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

$startTime = Get-Date

flutter build appbundle --release

$endTime = Get-Date
$duration = $endTime - $startTime

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan

if ($LASTEXITCODE -eq 0) {
    Write-Host "УСПЕХ! Сборка завершена успешно!" -ForegroundColor Green
    Write-Host "Время сборки: $($duration.Minutes) мин $($duration.Seconds) сек" -ForegroundColor Green
    Write-Host ""
    $bundlePath = Get-ChildItem -Path "build\app\outputs\bundle\release" -Filter "*.aab" -ErrorAction SilentlyContinue
    if ($bundlePath) {
        Write-Host "Файл App Bundle создан:" -ForegroundColor Green
        Write-Host "  $($bundlePath.FullName)" -ForegroundColor White
        Write-Host ""
        Write-Host "Размер файла: $([math]::Round($bundlePath.Length / 1MB, 2)) MB" -ForegroundColor Cyan
    }
} else {
    Write-Host "ОШИБКА! Сборка завершилась с ошибкой!" -ForegroundColor Red
    Write-Host "Код выхода: $LASTEXITCODE" -ForegroundColor Red
    exit 1
}

Write-Host "========================================" -ForegroundColor Cyan


# Скрипт для очистки сборки от ненужных файлов
# Удаляет debug символы и другие файлы, не нужные в production

param(
    [string]$BuildPath = "build\web"
)

Write-Host "🧹 Очистка сборки от ненужных файлов..." -ForegroundColor Cyan

$fullPath = Join-Path $PSScriptRoot ".." $BuildPath
$fullPath = Resolve-Path $fullPath -ErrorAction SilentlyContinue

if (-not $fullPath) {
    Write-Host "❌ Путь не найден: $BuildPath" -ForegroundColor Red
    exit 1
}

Write-Host "📁 Путь: $fullPath" -ForegroundColor Gray

# Удаляем .symbols файлы (debug символы)
$symbolsFiles = Get-ChildItem -Path $fullPath -Recurse -Filter "*.symbols" -ErrorAction SilentlyContinue
if ($symbolsFiles) {
    $symbolsSize = ($symbolsFiles | Measure-Object -Property Length -Sum).Sum / 1MB
    Write-Host "🗑️  Удаление .symbols файлов (~$([math]::Round($symbolsSize, 2)) MB)..." -ForegroundColor Yellow
    $symbolsFiles | Remove-Item -Force
    Write-Host "✅ Удалено $($symbolsFiles.Count) .symbols файлов" -ForegroundColor Green
}

# Удаляем NOTICES файлы (лицензии, не нужны в production)
$noticesFiles = Get-ChildItem -Path $fullPath -Recurse -Filter "NOTICES" -ErrorAction SilentlyContinue
if ($noticesFiles) {
    $noticesSize = ($noticesFiles | Measure-Object -Property Length -Sum).Sum / 1MB
    Write-Host "🗑️  Удаление NOTICES файлов (~$([math]::Round($noticesSize, 2)) MB)..." -ForegroundColor Yellow
    $noticesFiles | Remove-Item -Force
    Write-Host "✅ Удалено $($noticesFiles.Count) NOTICES файлов" -ForegroundColor Green
}

# Подсчитываем итоговый размер
$totalSize = (Get-ChildItem -Path $fullPath -Recurse -File | Measure-Object -Property Length -Sum).Sum / 1MB
Write-Host "✅ Очистка завершена!" -ForegroundColor Green
Write-Host "📊 Итоговый размер: $([math]::Round($totalSize, 2)) MB" -ForegroundColor Cyan


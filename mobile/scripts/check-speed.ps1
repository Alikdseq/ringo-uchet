# Скрипт для проверки скорости загрузки сайта
# Использование: .\scripts\check-speed.ps1 -Domain ringoouchet.ru

param(
    [Parameter(Mandatory=$false)]
    [string]$Domain = "ringoouchet.ru"
)

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Проверка скорости загрузки" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Домен: https://$Domain" -ForegroundColor Yellow
Write-Host ""

# Проверка главной страницы
Write-Host "1. Проверка главной страницы..." -ForegroundColor Yellow
try {
    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    $response = Invoke-WebRequest -Uri "https://$Domain" -UseBasicParsing -ErrorAction Stop
    $stopwatch.Stop()
    
    $loadTime = $stopwatch.ElapsedMilliseconds
    $sizeKB = [math]::Round($response.RawContentLength / 1KB, 2)
    
    Write-Host "   ✅ Загружено за: $loadTime ms" -ForegroundColor $(if ($loadTime -lt 3000) { "Green" } else { "Yellow" })
    Write-Host "   Размер: $sizeKB KB" -ForegroundColor White
    
    if ($loadTime -lt 1000) {
        Write-Host "   ⚡ Отлично! Загрузка очень быстрая" -ForegroundColor Green
    } elseif ($loadTime -lt 3000) {
        Write-Host "   ✅ Хорошо! Загрузка быстрая" -ForegroundColor Green
    } else {
        Write-Host "   ⚠️  Можно улучшить" -ForegroundColor Yellow
    }
} catch {
    Write-Host "   ❌ Ошибка: $_" -ForegroundColor Red
}

Write-Host ""

# Проверка главного JS файла
Write-Host "2. Проверка main.dart.js (с gzip)..." -ForegroundColor Yellow
try {
    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    $response = Invoke-WebRequest -Uri "https://$Domain/main.dart.js" `
        -Headers @{"Accept-Encoding" = "gzip"} `
        -UseBasicParsing `
        -ErrorAction Stop
    $stopwatch.Stop()
    
    $loadTime = $stopwatch.ElapsedMilliseconds
    $contentLength = $response.Headers["Content-Length"]
    $contentEncoding = $response.Headers["Content-Encoding"]
    
    if ($contentLength) {
        $sizeMB = [math]::Round([int]$contentLength / 1MB, 2)
        Write-Host "   Размер: $contentLength bytes ($sizeMB MB)" -ForegroundColor White
    }
    
    if ($contentEncoding -eq "gzip" -or $contentEncoding -like "*gzip*") {
        Write-Host "   ✅ gzip включен" -ForegroundColor Green
    } else {
        Write-Host "   ⚠️  gzip не обнаружен" -ForegroundColor Yellow
    }
    
    Write-Host "   Загружено за: $loadTime ms" -ForegroundColor White
    
    if ($contentLength) {
        $sizeMB = [math]::Round([int]$contentLength / 1MB, 2)
        if ($sizeMB -lt 2) {
            Write-Host "   ✅ Размер отличный (с gzip)" -ForegroundColor Green
        } elseif ($sizeMB -lt 3) {
            Write-Host "   ✅ Размер хороший (с gzip)" -ForegroundColor Green
        } else {
            Write-Host "   ⚠️  Размер можно уменьшить" -ForegroundColor Yellow
        }
    }
} catch {
    Write-Host "   ❌ Ошибка: $_" -ForegroundColor Red
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "💡 Для детального анализа используйте:" -ForegroundColor Yellow
Write-Host "   - Chrome DevTools (F12 → Network)" -ForegroundColor Gray
Write-Host "   - PageSpeed Insights: https://pagespeed.web.dev/" -ForegroundColor Gray
Write-Host "   - GTmetrix: https://gtmetrix.com/" -ForegroundColor Gray


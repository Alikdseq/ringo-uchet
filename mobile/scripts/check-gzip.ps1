# Скрипт для проверки включен ли gzip на сервере
# Использование: .\scripts\check-gzip.ps1 -Domain ringoouchet.ru

param(
    [Parameter(Mandatory=$false)]
    [string]$Domain = "ringoouchet.ru"
)

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Проверка gzip на сервере" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Домен: https://$Domain" -ForegroundColor Yellow
Write-Host ""

# Проверка с gzip
Write-Host "Проверяю ответ сервера с gzip..." -ForegroundColor Yellow
try {
    $response = Invoke-WebRequest -Uri "https://$Domain/main.dart.js" `
        -Method Head `
        -Headers @{"Accept-Encoding" = "gzip"} `
        -UseBasicParsing `
        -ErrorAction Stop
    
    $contentEncoding = $response.Headers["Content-Encoding"]
    $contentLength = $response.Headers["Content-Length"]
    
    Write-Host ""
    if ($contentEncoding -eq "gzip" -or $contentEncoding -like "*gzip*") {
        Write-Host "  ✅ gzip РАБОТАЕТ!" -ForegroundColor Green
        Write-Host ""
        Write-Host "  Content-Encoding: $contentEncoding" -ForegroundColor White
        if ($contentLength) {
            $sizeMB = [math]::Round([int]$contentLength / 1MB, 2)
            Write-Host "  Content-Length: $contentLength bytes ($sizeMB MB)" -ForegroundColor White
        }
    } else {
        Write-Host "  ❌ gzip НЕ работает!" -ForegroundColor Red
        Write-Host "  Content-Encoding: $($contentEncoding ?? 'не указан')" -ForegroundColor White
        if ($contentLength) {
            $sizeMB = [math]::Round([int]$contentLength / 1MB, 2)
            Write-Host "  Content-Length: $contentLength bytes ($sizeMB MB)" -ForegroundColor White
        }
    }
} catch {
    Write-Host "  ❌ Ошибка при проверке: $_" -ForegroundColor Red
}

# Сравнение размеров
Write-Host ""
Write-Host "Сравнение размеров:" -ForegroundColor Yellow
try {
    # Без gzip
    $responseWithout = Invoke-WebRequest -Uri "https://$Domain/main.dart.js" `
        -Method Head `
        -UseBasicParsing `
        -ErrorAction Stop
    
    $sizeWithout = $responseWithout.Headers["Content-Length"]
    
    # С gzip
    $responseWith = Invoke-WebRequest -Uri "https://$Domain/main.dart.js" `
        -Method Head `
        -Headers @{"Accept-Encoding" = "gzip"} `
        -UseBasicParsing `
        -ErrorAction Stop
    
    $sizeWith = $responseWith.Headers["Content-Length"]
    
    if ($sizeWithout -and $sizeWith) {
        $sizeWithoutMB = [math]::Round([int]$sizeWithout / 1MB, 2)
        $sizeWithMB = [math]::Round([int]$sizeWith / 1MB, 2)
        $saved = [math]::Round(([int]$sizeWithout - [int]$sizeWith) / 1MB, 2)
        $percent = [math]::Round((([int]$sizeWithout - [int]$sizeWith) / [int]$sizeWithout) * 100, 1)
        
        Write-Host ""
        Write-Host "  Без gzip: $sizeWithout bytes ($sizeWithoutMB MB)" -ForegroundColor Gray
        Write-Host "  С gzip:   $sizeWith bytes ($sizeWithMB MB)" -ForegroundColor Gray
        Write-Host ""
        Write-Host "  Экономия: $saved MB ($percent%)" -ForegroundColor Green
    }
} catch {
    Write-Host "  Не удалось получить размеры: $_" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Для настройки gzip см. CHECK_GZIP.md" -ForegroundColor Gray


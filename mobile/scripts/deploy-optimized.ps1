# Скрипт для деплоя оптимизированной веб-версии на сервер
# Использование: .\scripts\deploy-optimized.ps1 -ServerUser root -ServerIP 91.229.90.72 -WebDir /var/www/ringo-uchet

param(
    [Parameter(Mandatory=$true)]
    [string]$ServerUser = "root",
    
    [Parameter(Mandatory=$true)]
    [string]$ServerIP,
    
    [string]$WebDir = "/var/www/ringo-uchet",
    
    [switch]$SkipBuild = $false,
    
    [switch]$SkipCleanup = $false
)

$ErrorActionPreference = "Stop"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Optimized Web Deployment" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Переходим в директорию проекта
$originalLocation = Get-Location
Set-Location "$PSScriptRoot\.."

try {
    # Шаг 1: Сборка (если не пропущена)
    if (-not $SkipBuild) {
        Write-Host "Step 1: Building optimized web version..." -ForegroundColor Yellow
        .\scripts\build-web-optimized.ps1
        
        if ($LASTEXITCODE -ne 0) {
            throw "Build failed"
        }
    }
    
    # Шаг 2: Очистка лишних файлов
    if (-not $SkipCleanup) {
        Write-Host "Step 2: Cleaning unnecessary files..." -ForegroundColor Yellow
        
        $buildPath = "build\web"
        
        if (Test-Path $buildPath) {
            # Удалить source maps
            Get-ChildItem -Path $buildPath -Recurse -Filter "*.map" -ErrorAction SilentlyContinue | Remove-Item -Force
            Write-Host "  Removed source maps" -ForegroundColor Gray
            
            # Удалить NOTICES файлы
            Get-ChildItem -Path $buildPath -Recurse -Filter "NOTICES*" -ErrorAction SilentlyContinue | Remove-Item -Force
            Write-Host "  Removed NOTICES files" -ForegroundColor Gray
            
            # Проверить размер
            $size = (Get-ChildItem -Path $buildPath -Recurse -File | Measure-Object -Property Length -Sum).Sum
            $sizeMB = [math]::Round($size / 1MB, 2)
            Write-Host "  Final size: $sizeMB MB" -ForegroundColor Green
        }
    }
    
    # Шаг 3: Создание архива
    Write-Host "Step 3: Creating optimized archive..." -ForegroundColor Yellow
    
    $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
    $archiveName = "web-optimized-$timestamp.zip"
    $archivePath = "build\$archiveName"
    
    if (Test-Path $archivePath) {
        Remove-Item $archivePath -Force
    }
    
    Compress-Archive -Path "build\web\*" -DestinationPath $archivePath -CompressionLevel Optimal
    Write-Host "  Archive created: $archiveName" -ForegroundColor Green
    
    # Шаг 4: Загрузка на сервер
    Write-Host "Step 4: Uploading to server..." -ForegroundColor Yellow
    Write-Host "  Server: $ServerUser@$ServerIP" -ForegroundColor Gray
    Write-Host "  Destination: $WebDir" -ForegroundColor Gray
    
    $remoteArchive = "/tmp/web-latest.zip"
    
    # Копируем архив
    scp $archivePath "${ServerUser}@${ServerIP}:$remoteArchive"
    
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to upload archive to server"
    }
    
    Write-Host "  Archive uploaded successfully" -ForegroundColor Green
    
    # Шаг 5: Развертывание на сервере
    Write-Host "Step 5: Deploying on server..." -ForegroundColor Yellow
    
    $deployScript = @"
# Create backup
sudo mkdir -p $WebDir-backup-$(date +%Y%m%d-%H%M%S)
sudo cp -r $WebDir/* $WebDir-backup-$(date +%Y%m%d-%H%M%S)/ 2>/dev/null || true

# Create directory if not exists
sudo mkdir -p $WebDir

# Extract new version
sudo unzip -o $remoteArchive -d $WebDir/

# Set permissions
sudo chown -R www-data:www-data $WebDir
sudo chmod -R 755 $WebDir

# Cleanup
rm -f $remoteArchive

echo "✅ Deployment completed successfully!"
"@
    
    # Выполняем скрипт на сервере
    ssh "${ServerUser}@${ServerIP}" $deployScript
    
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to deploy on server"
    }
    
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Green
    Write-Host "  Deployment completed successfully!" -ForegroundColor Green
    Write-Host "========================================" -ForegroundColor Green
    Write-Host ""
    Write-Host "Next steps:" -ForegroundColor Yellow
    Write-Host "1. Ensure Nginx is configured with gzip/brotli compression" -ForegroundColor Gray
    Write-Host "2. Reload Nginx: ssh $ServerUser@$ServerIP 'sudo systemctl reload nginx'" -ForegroundColor Gray
    Write-Host "3. Check the application in browser" -ForegroundColor Gray
    Write-Host ""
    Write-Host "See DEPLOY_OPTIMIZED.md for Nginx configuration" -ForegroundColor Gray
    
} catch {
    Write-Host ""
    Write-Host "ERROR: $_" -ForegroundColor Red
    exit 1
} finally {
    Set-Location $originalLocation
}


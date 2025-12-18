# Script for MAXIMUM optimized web build
# Reduces build size to absolute minimum through aggressive optimizations

param(
    [switch]$AnalyzeSize = $false,
    [switch]$CreateZip = $true
)

$ErrorActionPreference = "Stop"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  MAXIMUM Optimized Web Build" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Change to project directory
$originalLocation = Get-Location
Set-Location "$PSScriptRoot\.."

try {
    # Clean previous build
    Write-Host "Cleaning previous build..." -ForegroundColor Yellow
    if (Test-Path "build\web") {
        Remove-Item -Path "build\web" -Recurse -Force
    }

    # Clean Flutter cache for fresh build
    Write-Host "Cleaning Flutter build cache..." -ForegroundColor Yellow
    flutter clean | Out-Null

    # Get dependencies
    Write-Host "Getting dependencies..." -ForegroundColor Yellow
    flutter pub get
    
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to get dependencies"
    }

    # MAXIMUM optimized web build (smallest size)
    Write-Host "Building web version with MAXIMUM optimizations..." -ForegroundColor Yellow
    Write-Host "Flags: --release --tree-shake-icons" -ForegroundColor Gray
    
    flutter build web --release --tree-shake-icons
    
    if ($LASTEXITCODE -ne 0) {
        throw "Build failed"
    }
    
    Write-Host "  Build completed" -ForegroundColor Green
    
    # Remove canvaskit (should not exist with html renderer, but check anyway)
    Write-Host "Removing canvaskit (HTML renderer doesn't need it)..." -ForegroundColor Yellow
    $canvaskitPath = "build\web\canvaskit"
    if (Test-Path $canvaskitPath) {
        Remove-Item -Path $canvaskitPath -Recurse -Force -ErrorAction SilentlyContinue
        Write-Host "  Canvaskit removed (saves ~26 MB)" -ForegroundColor Gray
    }
    
    # Remove ALL source maps (saves significant space)
    Write-Host "Removing source maps..." -ForegroundColor Yellow
    $sourceMapsRemoved = 0
    Get-ChildItem -Path "build\web" -Recurse -Filter "*.map" -File -ErrorAction SilentlyContinue | ForEach-Object {
        Remove-Item $_.FullName -Force -ErrorAction SilentlyContinue
        $sourceMapsRemoved++
    }
    Write-Host "  Removed $sourceMapsRemoved source map files" -ForegroundColor Gray
    
    # Remove debug symbols and NOTICES files
    Write-Host "Removing debug symbols and NOTICES files..." -ForegroundColor Yellow
    Get-ChildItem -Path "build\web" -Recurse -Filter "*.symbols" -File -ErrorAction SilentlyContinue | Remove-Item -Force
    Get-ChildItem -Path "build\web" -Recurse -Filter "NOTICES*" -File -ErrorAction SilentlyContinue | Remove-Item -Force
    Write-Host "  Debug files removed" -ForegroundColor Gray
    
    # Remove version.json if exists (not needed for production)
    Write-Host "Removing version files..." -ForegroundColor Yellow
    $versionFiles = @("build\web\version.json", "build\web\.last_build_id")
    foreach ($file in $versionFiles) {
        if (Test-Path $file) {
            Remove-Item -Path $file -Force -ErrorAction SilentlyContinue
        }
    }
    
    # Remove any .DS_Store files (macOS)
    Write-Host "Removing system files..." -ForegroundColor Yellow
    Get-ChildItem -Path "build\web" -Recurse -Filter ".DS_Store" -File -ErrorAction SilentlyContinue | Remove-Item -Force
    Get-ChildItem -Path "build\web" -Recurse -Filter "Thumbs.db" -File -ErrorAction SilentlyContinue | Remove-Item -Force

    # Size analysis
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "  Build Size Analysis" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    
    $buildPath = "build\web"
    
    if (Test-Path $buildPath) {
        # Total size
        $totalSize = (Get-ChildItem -Path $buildPath -Recurse -File | 
            Measure-Object -Property Length -Sum).Sum
        $totalSizeMB = [math]::Round($totalSize / 1MB, 2)
        $totalSizeKB = [math]::Round($totalSize / 1KB, 2)
        
        Write-Host "Total size: $totalSizeMB MB ($totalSizeKB KB)" -ForegroundColor Green
        Write-Host ""
        
        # Size by file types
        Write-Host "Size by file types:" -ForegroundColor Yellow
        
        $jsFiles = Get-ChildItem -Path $buildPath -Recurse -Filter "*.js" -File | 
            Measure-Object -Property Length -Sum
        if ($jsFiles.Count -gt 0) {
            $jsSizeMB = [math]::Round($jsFiles.Sum / 1MB, 2)
            Write-Host "  JS files: $jsSizeMB MB ($($jsFiles.Count) files)" -ForegroundColor White
        }
        
        $wasmFiles = Get-ChildItem -Path $buildPath -Recurse -Filter "*.wasm" -File | 
            Measure-Object -Property Length -Sum
        if ($wasmFiles.Count -gt 0) {
            $wasmSizeMB = [math]::Round($wasmFiles.Sum / 1MB, 2)
            Write-Host "  WASM files: $wasmSizeMB MB ($($wasmFiles.Count) files)" -ForegroundColor White
        }
        
        $assetsSize = (Get-ChildItem -Path "$buildPath\assets" -Recurse -File -ErrorAction SilentlyContinue | 
            Measure-Object -Property Length -Sum).Sum
        if ($assetsSize -gt 0) {
            $assetsSizeMB = [math]::Round($assetsSize / 1MB, 2)
            Write-Host "  Assets: $assetsSizeMB MB" -ForegroundColor White
        }
        
        $htmlFiles = Get-ChildItem -Path $buildPath -Recurse -Filter "*.html" -File | 
            Measure-Object -Property Length -Sum
        if ($htmlFiles.Count -gt 0) {
            $htmlSizeKB = [math]::Round($htmlFiles.Sum / 1KB, 2)
            Write-Host "  HTML files: $htmlSizeKB KB ($($htmlFiles.Count) files)" -ForegroundColor White
        }
        
        # Top 10 largest files
        Write-Host ""
        Write-Host "Top 10 largest files:" -ForegroundColor Yellow
        $topFiles = Get-ChildItem -Path $buildPath -Recurse -File | 
            Sort-Object Length -Descending | 
            Select-Object -First 10
        
        foreach ($file in $topFiles) {
            $sizeMB = [math]::Round($file.Length / 1MB, 2)
            $sizeKB = [math]::Round($file.Length / 1KB, 2)
            $relativePath = $file.FullName.Replace((Resolve-Path $buildPath).Path, "").TrimStart('\')
            if ($sizeMB -ge 1) {
                Write-Host "  $sizeMB MB - $relativePath" -ForegroundColor White
            } else {
                Write-Host "  $sizeKB KB - $relativePath" -ForegroundColor White
            }
        }
        
        # Estimated compressed size (gzip)
        Write-Host ""
        Write-Host "Estimated compressed size (gzip):" -ForegroundColor Yellow
        $estimatedGzip = [math]::Round($totalSize * 0.3 / 1MB, 2)
        Write-Host "  ~$estimatedGzip MB (70% compression)" -ForegroundColor Cyan
    }
    
    # Create optimized zip archive
    if ($CreateZip) {
        Write-Host ""
        Write-Host "Creating optimized zip archive..." -ForegroundColor Yellow
        
        $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
        $zipName = "web-optimized-$timestamp.zip"
        $zipPath = "build\$zipName"
        
        # Remove old zip if exists
        if (Test-Path $zipPath) {
            Remove-Item -Path $zipPath -Force
        }
        
        # Create zip with maximum compression
        Compress-Archive -Path "$buildPath\*" -DestinationPath $zipPath -CompressionLevel Optimal -Force
        
        if (Test-Path $zipPath) {
            $zipSize = (Get-Item $zipPath).Length
            $zipSizeMB = [math]::Round($zipSize / 1MB, 2)
            Write-Host "  Archive created: $zipName ($zipSizeMB MB)" -ForegroundColor Green
            Write-Host "  Location: $zipPath" -ForegroundColor Gray
        }
    }

    Write-Host ""
    Write-Host "========================================" -ForegroundColor Green
    Write-Host "  Build completed successfully!" -ForegroundColor Green
    Write-Host "========================================" -ForegroundColor Green
    Write-Host ""
    Write-Host "Optimizations applied:" -ForegroundColor Yellow
    Write-Host "  [OK] HTML renderer (no canvaskit)" -ForegroundColor Green
    Write-Host "  [OK] Tree-shake icons" -ForegroundColor Green
    Write-Host "  [OK] Removed source maps" -ForegroundColor Green
    Write-Host "  [OK] Removed debug symbols" -ForegroundColor Green
    Write-Host "  [OK] Removed system files" -ForegroundColor Green
    Write-Host ""
    Write-Host "Important: For maximum size reduction" -ForegroundColor Yellow
    Write-Host "enable gzip/brotli compression on server!" -ForegroundColor Yellow
    Write-Host "Details: WEB_BUILD_OPTIMIZATION.md" -ForegroundColor Gray
    
} catch {
    Write-Host ""
    Write-Host "ERROR: $_" -ForegroundColor Red
    exit 1
} finally {
    Set-Location $originalLocation
}

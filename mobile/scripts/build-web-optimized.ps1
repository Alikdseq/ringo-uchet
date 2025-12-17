# Script for optimized web build
# Reduces build size through tree-shaking and optimizations

param(
    [switch]$AnalyzeSize = $false
)

$ErrorActionPreference = "Stop"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Optimized Web Build" -ForegroundColor Cyan
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

    # Get dependencies
    Write-Host "Getting dependencies..." -ForegroundColor Yellow
    flutter pub get

    # Optimized web build
    Write-Host "Building web version with optimizations..." -ForegroundColor Yellow
    Write-Host "Flags: --release --tree-shake-icons" -ForegroundColor Gray
    
    flutter build web --release --tree-shake-icons
    
    if ($LASTEXITCODE -ne 0) {
        throw "Build failed"
    }
    
    # Remove canvaskit to use HTML renderer (saves ~26 MB)
    Write-Host "Removing canvaskit (using HTML renderer for smaller size)..." -ForegroundColor Yellow
    $canvaskitPath = "build\web\canvaskit"
    if (Test-Path $canvaskitPath) {
        Remove-Item -Path $canvaskitPath -Recurse -Force -ErrorAction SilentlyContinue
        Write-Host "  Canvaskit removed (saves ~26 MB)" -ForegroundColor Gray
    }
    
    # Remove debug symbols and NOTICES files
    Write-Host "Removing debug symbols and NOTICES files..." -ForegroundColor Yellow
    Get-ChildItem -Path "build\web" -Recurse -Filter "*.symbols" -File -ErrorAction SilentlyContinue | Remove-Item -Force
    Get-ChildItem -Path "build\web" -Recurse -Filter "NOTICES*" -File -ErrorAction SilentlyContinue | Remove-Item -Force
    Write-Host "  Debug files removed" -ForegroundColor Gray

    # Size analysis
    if ($AnalyzeSize -or $true) {
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
            
            Write-Host "Total size: $totalSizeMB MB" -ForegroundColor Green
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
            
            # Top 10 largest files
            Write-Host ""
            Write-Host "Top 10 largest files:" -ForegroundColor Yellow
            Get-ChildItem -Path $buildPath -Recurse -File | 
                Sort-Object Length -Descending | 
                Select-Object -First 10 | 
                ForEach-Object {
                    $sizeMB = [math]::Round($_.Length / 1MB, 2)
                    $relativePath = $_.FullName.Replace((Resolve-Path $buildPath).Path, "").TrimStart('\')
                    Write-Host "  $sizeMB MB - $relativePath" -ForegroundColor White
                }
        }
    }

    Write-Host ""
    Write-Host "========================================" -ForegroundColor Green
    Write-Host "  Build completed successfully!" -ForegroundColor Green
    Write-Host "========================================" -ForegroundColor Green
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

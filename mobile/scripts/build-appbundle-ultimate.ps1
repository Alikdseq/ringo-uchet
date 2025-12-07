# ULTIMATE script for building App Bundle with maximum error handling
# Usage: powershell -ExecutionPolicy Bypass -File .\scripts\build-appbundle-ultimate.ps1

$ErrorActionPreference = "Continue"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  ULTIMATE APP BUNDLE BUILD" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Function for safe removal
function Remove-SafePath {
    param([string]$Path)
    if (Test-Path $Path) {
        try {
            Remove-Item -Path $Path -Recurse -Force -ErrorAction Stop
            return $true
        } catch {
            Write-Host "Warning: Could not remove $Path" -ForegroundColor Yellow
            Write-Host "  Error: $_" -ForegroundColor Gray
            return $false
        }
    }
    return $true
}

# Step 1: Stop all processes
Write-Host "[1/8] Stopping Java/Gradle processes..." -ForegroundColor Yellow
$javaProcesses = Get-Process java -ErrorAction SilentlyContinue
if ($javaProcesses) {
    Write-Host "  Found processes: $($javaProcesses.Count)" -ForegroundColor Gray
    $javaProcesses | ForEach-Object {
        try {
            Stop-Process -Id $_.Id -Force -ErrorAction Stop
            Write-Host "  Stopped process: $($_.Id)" -ForegroundColor Gray
        } catch {
            Write-Host "  Could not stop process: $($_.Id)" -ForegroundColor Yellow
        }
    }
    Start-Sleep -Seconds 5
} else {
    Write-Host "  No Java processes found" -ForegroundColor Green
}

# Step 2: Full Gradle cache cleanup
Write-Host ""
Write-Host "[2/8] Full Gradle cache cleanup..." -ForegroundColor Yellow
$gradleCachePaths = @(
    "$env:USERPROFILE\.gradle\caches\8.9\transforms",
    "$env:USERPROFILE\.gradle\caches\8.9\tmp",
    "$env:USERPROFILE\.gradle\daemon"
)

foreach ($path in $gradleCachePaths) {
    if (Remove-SafePath -Path $path) {
        Write-Host "  Cleaned: $(Split-Path $path -Leaf)" -ForegroundColor Green
    }
}

# Step 3: Project cleanup
Write-Host ""
Write-Host "[3/8] Project cleanup..." -ForegroundColor Yellow
try {
    flutter clean 2>&1 | Out-Null
    Write-Host "  flutter clean completed" -ForegroundColor Green
} catch {
    Write-Host "  Warning during flutter clean" -ForegroundColor Yellow
}

$projectPaths = @(
    ".\android\.gradle",
    ".\android\build",
    ".\android\app\build",
    ".\build"
)

foreach ($path in $projectPaths) {
    Remove-SafePath -Path $path | Out-Null
}

# Step 4: SDK temp files cleanup
Write-Host ""
Write-Host "[4/8] SDK temp files cleanup..." -ForegroundColor Yellow
$sdkTempPath = Join-Path $env:LOCALAPPDATA "Android\Sdk\.temp"
if (Remove-SafePath -Path $sdkTempPath) {
    Write-Host "  SDK temp files cleaned" -ForegroundColor Green
}

# Step 5: Configuration check
Write-Host ""
Write-Host "[5/8] Configuration check..." -ForegroundColor Yellow
$buildGradle = ".\android\app\build.gradle"
if (Test-Path $buildGradle) {
    $content = Get-Content $buildGradle -Raw
    if ($content -match "compileSdk\s+36") {
        Write-Host "  compileSdk = 36" -ForegroundColor Green
    } else {
        Write-Host "  WARNING: compileSdk is not 36" -ForegroundColor Yellow
    }
    if ($content -match "targetSdkVersion\s+36") {
        Write-Host "  targetSdk = 36" -ForegroundColor Green
    } else {
        Write-Host "  WARNING: targetSdk is not 36" -ForegroundColor Yellow
    }
} else {
    Write-Host "  WARNING: build.gradle not found" -ForegroundColor Yellow
}

# Step 6: Flutter check
Write-Host ""
Write-Host "[6/8] Flutter check..." -ForegroundColor Yellow
try {
    $flutterVersion = flutter --version 2>&1 | Select-Object -First 1
    Write-Host "  Flutter: $flutterVersion" -ForegroundColor Green
} catch {
    Write-Host "  ERROR: Flutter not found!" -ForegroundColor Red
    exit 1
}

# Step 7: Get dependencies
Write-Host ""
Write-Host "[7/8] Getting dependencies..." -ForegroundColor Yellow
try {
    flutter pub get 2>&1 | Out-Null
    Write-Host "  Dependencies retrieved" -ForegroundColor Green
} catch {
    Write-Host "  Warning during dependency retrieval" -ForegroundColor Yellow
}

# Step 8: Build
Write-Host ""
Write-Host "[8/8] Starting App Bundle build..." -ForegroundColor Yellow
Write-Host "  This may take 10-20 minutes..." -ForegroundColor Gray
Write-Host "  Using flag --android-skip-build-dependency-validation" -ForegroundColor Gray
Write-Host ""

$buildSuccess = $false
$attempts = 0
$maxAttempts = 2

while (-not $buildSuccess -and $attempts -lt $maxAttempts) {
    $attempts++
    Write-Host "  Build attempt #$attempts of $maxAttempts..." -ForegroundColor Cyan
    
    try {
        # Try to build
        $buildOutput = flutter build appbundle --release --android-skip-build-dependency-validation 2>&1
        
        # Check result
        if ($LASTEXITCODE -eq 0) {
            $buildSuccess = $true
            Write-Host ""
            Write-Host "========================================" -ForegroundColor Green
            Write-Host "  BUILD SUCCESSFUL!" -ForegroundColor Green
            Write-Host "========================================" -ForegroundColor Green
            Write-Host ""
            $aabPath = "build\app\outputs\bundle\release\app-release.aab"
            if (Test-Path $aabPath) {
                $fileInfo = Get-Item $aabPath
                $fileSizeMB = [math]::Round($fileInfo.Length / 1MB, 2)
                Write-Host "  File: $aabPath" -ForegroundColor Cyan
                Write-Host "  Size: $fileSizeMB MB" -ForegroundColor Cyan
                Write-Host ""
                Write-Host "  This file is ready for upload!" -ForegroundColor Green
            } else {
                Write-Host "  WARNING: File not found at expected path" -ForegroundColor Yellow
            }
        } else {
            Write-Host ""
            Write-Host "  ERROR during build (exit code: $LASTEXITCODE)" -ForegroundColor Red
            
            # Analyze errors
            $errorOutput = $buildOutput | Where-Object { $_ -match "error|Error|ERROR|failed|Failed|FAILED" }
            if ($errorOutput) {
                Write-Host ""
                Write-Host "  Main errors:" -ForegroundColor Yellow
                $errorOutput | Select-Object -First 5 | ForEach-Object {
                    Write-Host "    $_" -ForegroundColor Red
                }
            }
            
            # If cache error, clean again
            if ($buildOutput -match "Could not move temporary workspace|transforms") {
                Write-Host ""
                Write-Host "  Detected Gradle cache error" -ForegroundColor Yellow
                Write-Host "  Performing additional cleanup..." -ForegroundColor Yellow
                Remove-SafePath -Path "$env:USERPROFILE\.gradle\caches\8.9\transforms" | Out-Null
                Start-Sleep -Seconds 3
            }
        }
    } catch {
        Write-Host ""
        Write-Host "  EXCEPTION during build:" -ForegroundColor Red
        Write-Host "    $_" -ForegroundColor Red
    }
    
    if (-not $buildSuccess -and $attempts -lt $maxAttempts) {
        Write-Host ""
        Write-Host "  Retrying in 5 seconds..." -ForegroundColor Yellow
        Start-Sleep -Seconds 5
    }
}

if (-not $buildSuccess) {
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Red
    Write-Host "  BUILD FAILED" -ForegroundColor Red
    Write-Host "========================================" -ForegroundColor Red
    Write-Host ""
    Write-Host "Try the following:" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "1. Add to antivirus exclusions:" -ForegroundColor White
    Write-Host "   - $env:USERPROFILE\.gradle" -ForegroundColor Gray
    Write-Host "   - $env:LOCALAPPDATA\Android" -ForegroundColor Gray
    Write-Host "   - $(Get-Location)" -ForegroundColor Gray
    Write-Host ""
    Write-Host "2. Close ALL IDEs and code editors" -ForegroundColor White
    Write-Host ""
    Write-Host "3. Run PowerShell as Administrator" -ForegroundColor White
    Write-Host ""
    Write-Host "4. Try manual build:" -ForegroundColor White
    Write-Host "   flutter build appbundle --release --android-skip-build-dependency-validation" -ForegroundColor Gray
    Write-Host ""
    Write-Host "5. If cache issue, delete completely:" -ForegroundColor White
    Write-Host "   Remove-Item -Path `"$env:USERPROFILE\.gradle`" -Recurse -Force" -ForegroundColor Gray
    Write-Host ""
    Write-Host "Detailed documentation:" -ForegroundColor Cyan
    Write-Host "   - mobile/FINAL_SOLUTION.md" -ForegroundColor Gray
    Write-Host "   - mobile/docs/GRADLE_WINDOWS_FIX.md" -ForegroundColor Gray
    Write-Host ""
    exit 1
}

Write-Host ""
Write-Host "Done!" -ForegroundColor Green

# Script to check build status
# Usage: powershell -ExecutionPolicy Bypass -File .\scripts\check-build-status.ps1

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  BUILD STATUS CHECK" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Check if Java/Gradle processes are running
Write-Host "[1] Checking build processes..." -ForegroundColor Yellow
$javaProcesses = Get-Process java -ErrorAction SilentlyContinue
if ($javaProcesses) {
    Write-Host "  Build is RUNNING" -ForegroundColor Green
    Write-Host "  Active Java processes: $($javaProcesses.Count)" -ForegroundColor Gray
    $javaProcesses | ForEach-Object {
        $runtime = (Get-Date) - $_.StartTime
        Write-Host "    Process $($_.Id): Running for $([math]::Round($runtime.TotalMinutes, 1)) minutes" -ForegroundColor Gray
    }
} else {
    Write-Host "  No build processes found" -ForegroundColor Yellow
}

Write-Host ""

# Check if AAB file exists
Write-Host "[2] Checking for output file..." -ForegroundColor Yellow
$aabPath = "build\app\outputs\bundle\release\app-release.aab"
if (Test-Path $aabPath) {
    $fileInfo = Get-Item $aabPath
    $fileSizeMB = [math]::Round($fileInfo.Length / 1MB, 2)
    $fileDate = $fileInfo.LastWriteTime
    
    Write-Host "  BUILD COMPLETED SUCCESSFULLY!" -ForegroundColor Green
    Write-Host "  File: $aabPath" -ForegroundColor Cyan
    Write-Host "  Size: $fileSizeMB MB" -ForegroundColor Cyan
    Write-Host "  Created: $fileDate" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  This file is ready for upload!" -ForegroundColor Green
} else {
    Write-Host "  Output file not found yet" -ForegroundColor Yellow
    Write-Host "  Path checked: $aabPath" -ForegroundColor Gray
}

Write-Host ""

# Check build directory
Write-Host "[3] Checking build directory..." -ForegroundColor Yellow
$buildDir = "build\app\outputs\bundle\release"
if (Test-Path $buildDir) {
    $files = Get-ChildItem $buildDir -ErrorAction SilentlyContinue
    if ($files) {
        Write-Host "  Build directory exists with $($files.Count) file(s)" -ForegroundColor Green
        $files | ForEach-Object {
            Write-Host "    - $($_.Name) ($([math]::Round($_.Length / 1MB, 2)) MB)" -ForegroundColor Gray
        }
    } else {
        Write-Host "  Build directory exists but is empty" -ForegroundColor Yellow
    }
} else {
    Write-Host "  Build directory does not exist yet" -ForegroundColor Yellow
}

Write-Host ""

# Summary
if ($javaProcesses -and -not (Test-Path $aabPath)) {
    Write-Host "========================================" -ForegroundColor Yellow
    Write-Host "  BUILD IS IN PROGRESS" -ForegroundColor Yellow
    Write-Host "========================================" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "The build is still running. Please wait..." -ForegroundColor White
    Write-Host "This may take 10-20 minutes." -ForegroundColor Gray
    Write-Host ""
    Write-Host "To check again, run this script:" -ForegroundColor Cyan
    Write-Host "  powershell -ExecutionPolicy Bypass -File .\scripts\check-build-status.ps1" -ForegroundColor Gray
} elseif (Test-Path $aabPath) {
    Write-Host "========================================" -ForegroundColor Green
    Write-Host "  BUILD COMPLETED!" -ForegroundColor Green
    Write-Host "========================================" -ForegroundColor Green
} else {
    Write-Host "========================================" -ForegroundColor Red
    Write-Host "  BUILD NOT FOUND" -ForegroundColor Red
    Write-Host "========================================" -ForegroundColor Red
    Write-Host ""
    Write-Host "The build may have failed or not started yet." -ForegroundColor Yellow
    Write-Host "Check the build logs or run the build script again." -ForegroundColor Yellow
}

Write-Host ""


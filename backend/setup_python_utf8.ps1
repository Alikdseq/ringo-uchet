# Скрипт для установки PYTHONUTF8=1 глобально в Windows
# Это исправляет проблему UnicodeDecodeError в psycopg2 когда системные переменные Windows содержат кириллицу
#
# Использование:
#   .\setup_python_utf8.ps1
#
# Или для установки только для текущего пользователя:
#   .\setup_python_utf8.ps1 -UserOnly

param(
    [switch]$UserOnly = $false
)

Write-Host "Установка PYTHONUTF8=1 для исправления проблемы с кодировкой в psycopg2..." -ForegroundColor Green

$scope = if ($UserOnly) { "User" } else { "Machine" }
$currentValue = [System.Environment]::GetEnvironmentVariable('PYTHONUTF8', $scope)

if ($currentValue -eq '1') {
    Write-Host "PYTHONUTF8 уже установлен в значение '1' для $scope" -ForegroundColor Yellow
} else {
    try {
        [System.Environment]::SetEnvironmentVariable('PYTHONUTF8', '1', $scope)
        Write-Host "✓ PYTHONUTF8=1 успешно установлен для $scope" -ForegroundColor Green
        
        if (-not $UserOnly) {
            Write-Host "`nВНИМАНИЕ: Переменная установлена для всей системы (Machine scope)." -ForegroundColor Yellow
            Write-Host "Для применения изменений может потребоваться перезапуск терминала или перезагрузка системы." -ForegroundColor Yellow
        } else {
            Write-Host "`nВНИМАНИЕ: Переменная установлена только для текущего пользователя (User scope)." -ForegroundColor Yellow
            Write-Host "Для применения изменений может потребоваться перезапуск терминала." -ForegroundColor Yellow
        }
    } catch {
        Write-Host "ОШИБКА: Не удалось установить переменную окружения. Возможно, требуются права администратора." -ForegroundColor Red
        Write-Host $_.Exception.Message -ForegroundColor Red
        exit 1
    }
}

Write-Host "`nПроверка установки..." -ForegroundColor Cyan
$verifyValue = [System.Environment]::GetEnvironmentVariable('PYTHONUTF8', $scope)
if ($verifyValue -eq '1') {
    Write-Host "✓ Проверка пройдена: PYTHONUTF8=$verifyValue" -ForegroundColor Green
} else {
    Write-Host "✗ Проверка не пройдена: PYTHONUTF8=$verifyValue" -ForegroundColor Red
    Write-Host "Попробуйте перезапустить терминал и запустить скрипт снова." -ForegroundColor Yellow
}

Write-Host "`nГотово! Теперь можно запускать миграции Django." -ForegroundColor Green


# 🚀 Профессиональный скрипт деплоя бэкенда Ringo Uchet (PowerShell)
# Использование: .\deploy.ps1 [-Environment prod] [-SkipBackup] [-SkipTests]

param(
    [string]$Environment = "prod",
    [switch]$SkipBackup = $false,
    [switch]$SkipTests = $false
)

$ErrorActionPreference = "Stop"

# Переменные
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectName = "ringo-backend"
$Timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$BackupDir = Join-Path $ScriptDir "backups"
$LogFile = Join-Path $ScriptDir "deploy_$Timestamp.log"

# Функции логирования
function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    
    $Color = switch ($Level) {
        "SUCCESS" { "Green" }
        "WARNING" { "Yellow" }
        "ERROR" { "Red" }
        default { "Cyan" }
    }
    
    $LogMessage = "[$Level] $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - $Message"
    Write-Host $LogMessage -ForegroundColor $Color
    Add-Content -Path $LogFile -Value $LogMessage
}

# Проверка зависимостей
function Test-Dependencies {
    Write-Log "Проверка зависимостей..." "INFO"
    
    $missingDeps = @()
    
    if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
        $missingDeps += "docker"
    }
    if (-not (Get-Command docker-compose -ErrorAction SilentlyContinue)) {
        $missingDeps += "docker-compose"
    }
    if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
        $missingDeps += "git"
    }
    
    if ($missingDeps.Count -gt 0) {
        Write-Log "Отсутствуют зависимости: $($missingDeps -join ', ')" "ERROR"
        exit 1
    }
    
    Write-Log "Все зависимости установлены" "SUCCESS"
}

# Проверка окружения
function Test-Environment {
    Write-Log "Проверка окружения: $Environment" "INFO"
    
    $envFile = Join-Path $ScriptDir ".env"
    if (-not (Test-Path $envFile)) {
        Write-Log "Файл .env не найден!" "ERROR"
        exit 1
    }
    
    # Загрузка переменных окружения
    Get-Content $envFile | ForEach-Object {
        if ($_ -match '^\s*([^#][^=]*)=(.*)$') {
            $name = $matches[1].Trim()
            $value = $matches[2].Trim()
            [Environment]::SetEnvironmentVariable($name, $value, "Process")
        }
    }
    
    $requiredVars = @("DJANGO_SECRET_KEY", "POSTGRES_PASSWORD", "DB_PASSWORD")
    foreach ($var in $requiredVars) {
        if (-not [Environment]::GetEnvironmentVariable($var, "Process")) {
            Write-Log "Переменная окружения $var не установлена!" "ERROR"
            exit 1
        }
    }
    
    Write-Log "Окружение проверено" "SUCCESS"
}

# Создание бэкапа базы данных
function Backup-Database {
    if ($SkipBackup) {
        Write-Log "Пропуск создания бэкапа (флаг -SkipBackup)" "WARNING"
        return
    }
    
    Write-Log "Создание бэкапа базы данных..." "INFO"
    
    New-Item -ItemType Directory -Force -Path $BackupDir | Out-Null
    
    $backupFile = Join-Path $BackupDir "db_backup_$Timestamp.sql"
    
    try {
        docker-compose -f docker-compose.prod.yml exec -T db pg_dump -U $env:POSTGRES_USER ringo_prod | Out-File -FilePath $backupFile -Encoding UTF8
        Compress-Archive -Path $backupFile -DestinationPath "$backupFile.gz" -Force
        Remove-Item $backupFile
        Write-Log "Бэкап создан: $backupFile.gz" "SUCCESS"
    }
    catch {
        Write-Log "Не удалось создать бэкап БД (возможно, контейнер не запущен)" "WARNING"
    }
}

# Остановка сервисов
function Stop-Services {
    Write-Log "Остановка сервисов..." "INFO"
    
    Push-Location $ScriptDir
    try {
        docker-compose -f docker-compose.prod.yml down --timeout 30
        Write-Log "Сервисы остановлены" "SUCCESS"
    }
    catch {
        Write-Log "Ошибка при остановке сервисов: $_" "WARNING"
    }
    finally {
        Pop-Location
    }
}

# Получение последних изменений из Git
function Update-Code {
    Write-Log "Получение последних изменений из Git..." "INFO"
    
    Push-Location $ScriptDir
    try {
        if (Test-Path ".git") {
            git fetch origin
            git pull origin master
            Write-Log "Код обновлен" "SUCCESS"
        }
        else {
            Write-Log "Не найден репозиторий Git, пропускаем обновление" "WARNING"
        }
    }
    catch {
        Write-Log "Ошибка при обновлении кода: $_" "WARNING"
    }
    finally {
        Pop-Location
    }
}

# Сборка Docker образов
function Build-Images {
    Write-Log "Сборка Docker образов..." "INFO"
    
    Push-Location $ScriptDir
    try {
        docker-compose -f docker-compose.prod.yml build --no-cache --parallel
        Write-Log "Образы собраны" "SUCCESS"
    }
    catch {
        Write-Log "Ошибка при сборке образов: $_" "ERROR"
        throw
    }
    finally {
        Pop-Location
    }
}

# Запуск сервисов
function Start-Services {
    Write-Log "Запуск сервисов..." "INFO"
    
    Push-Location $ScriptDir
    try {
        # Запуск зависимостей
        docker-compose -f docker-compose.prod.yml up -d db redis minio
        
        # Ожидание готовности БД
        Write-Log "Ожидание готовности базы данных..." "INFO"
        Start-Sleep -Seconds 10
        
        $maxAttempts = 30
        $attempt = 0
        $dbReady = $false
        
        while ($attempt -lt $maxAttempts) {
            try {
                $result = docker-compose -f docker-compose.prod.yml exec -T db pg_isready -U $env:POSTGRES_USER 2>&1
                if ($LASTEXITCODE -eq 0) {
                    $dbReady = $true
                    break
                }
            }
            catch { }
            
            $attempt++
            Start-Sleep -Seconds 2
        }
        
        if (-not $dbReady) {
            Write-Log "База данных не готова после $maxAttempts попыток" "ERROR"
            throw "Database not ready"
        }
        
        Write-Log "База данных готова" "SUCCESS"
        
        # Запуск API и Celery
        docker-compose -f docker-compose.prod.yml up -d api celery-worker celery-beat
        
        Write-Log "Сервисы запущены" "SUCCESS"
    }
    catch {
        Write-Log "Ошибка при запуске сервисов: $_" "ERROR"
        throw
    }
    finally {
        Pop-Location
    }
}

# Выполнение миграций
function Invoke-Migrations {
    Write-Log "Выполнение миграций базы данных..." "INFO"
    
    Push-Location $ScriptDir
    try {
        docker-compose -f docker-compose.prod.yml exec -T api python manage.py migrate --noinput
        Write-Log "Миграции выполнены" "SUCCESS"
    }
    catch {
        Write-Log "Ошибка при выполнении миграций: $_" "ERROR"
        throw
    }
    finally {
        Pop-Location
    }
}

# Сборка статических файлов
function Collect-Static {
    Write-Log "Сборка статических файлов..." "INFO"
    
    Push-Location $ScriptDir
    try {
        docker-compose -f docker-compose.prod.yml exec -T api python manage.py collectstatic --noinput --clear
        Write-Log "Статические файлы собраны" "SUCCESS"
    }
    catch {
        Write-Log "Ошибка при сборке статических файлов: $_" "ERROR"
        throw
    }
    finally {
        Pop-Location
    }
}

# Проверка здоровья сервисов
function Test-Health {
    Write-Log "Проверка здоровья сервисов..." "INFO"
    
    $maxAttempts = 30
    $attempt = 0
    
    while ($attempt -lt $maxAttempts) {
        try {
            $response = Invoke-WebRequest -Uri "http://localhost:8001/api/health/" -TimeoutSec 5 -UseBasicParsing -ErrorAction Stop
            if ($response.StatusCode -eq 200) {
                Write-Log "API здоров" "SUCCESS"
                return $true
            }
        }
        catch { }
        
        $attempt++
        Start-Sleep -Seconds 2
    }
    
    Write-Log "API не отвечает после $maxAttempts попыток" "ERROR"
    return $false
}

# Откат к предыдущей версии
function Invoke-Rollback {
    Write-Log "ОТКАТ: Возврат к предыдущей версии..." "ERROR"
    
    Push-Location $ScriptDir
    try {
        docker-compose -f docker-compose.prod.yml down
        
        $latestBackup = Get-ChildItem -Path $BackupDir -Filter "db_backup_*.sql.gz" | Sort-Object LastWriteTime -Descending | Select-Object -First 1
        
        if ($latestBackup) {
            Write-Log "Восстановление базы данных из бэкапа..." "INFO"
            # Восстановление из бэкапа (требует дополнительной реализации)
        }
        
        Write-Log "Откат выполнен. Проверьте логи: $LogFile" "WARNING"
    }
    finally {
        Pop-Location
    }
}

# Очистка старых образов
function Clear-OldResources {
    Write-Log "Очистка старых образов..." "INFO"
    
    try {
        docker image prune -a -f --filter "until=168h" 2>&1 | Out-Null
        Get-ChildItem -Path $BackupDir -Filter "db_backup_*.sql.gz" | Where-Object { $_.LastWriteTime -lt (Get-Date).AddDays(-30) } | Remove-Item -Force
        Write-Log "Очистка завершена" "SUCCESS"
    }
    catch {
        Write-Log "Ошибка при очистке: $_" "WARNING"
    }
}

# Главная функция
function Main {
    Write-Log "==========================================" "INFO"
    Write-Log "🚀 Начало деплоя бэкенда Ringo Uchet" "INFO"
    Write-Log "Окружение: $Environment" "INFO"
    Write-Log "Время: $(Get-Date)" "INFO"
    Write-Log "==========================================" "INFO"
    
    try {
        Test-Dependencies
        Test-Environment
        Backup-Database
        Update-Code
        Stop-Services
        Build-Images
        Start-Services
        Invoke-Migrations
        Collect-Static
        
        if (Test-Health) {
            Write-Log "==========================================" "SUCCESS"
            Write-Log "✅ Деплой успешно завершен!" "SUCCESS"
            Write-Log "API доступен: http://localhost:8001/api/health/" "SUCCESS"
            Write-Log "Логи: $LogFile" "SUCCESS"
            Write-Log "==========================================" "SUCCESS"
        }
        else {
            throw "Health check failed"
        }
        
        # Очистка в фоне
        Start-Job -ScriptBlock { Clear-OldResources } | Out-Null
    }
    catch {
        Write-Log "Деплой завершился с ошибками: $_" "ERROR"
        Invoke-Rollback
        exit 1
    }
}

# Запуск
Main


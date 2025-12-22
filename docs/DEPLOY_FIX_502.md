# Пошаговая инструкция: Исправление ошибки 502

## Где выполнять команды

Все команды выполняются в **PowerShell** или **Command Prompt** в корне проекта `C:\ringo-uchet\`

---

## ШАГ 1: Остановка текущих контейнеров

Откройте PowerShell в папке проекта и выполните:

```powershell
# Перейти в корень проекта (если еще не там)
cd C:\ringo-uchet

# Остановить и удалить все контейнеры
docker-compose down
```

**Ожидаемый результат:** Все контейнеры остановлены и удалены.

---

## ШАГ 2: Проверка файлов

Убедитесь, что все файлы на месте:

```powershell
# Проверить наличие ключевых файлов
Test-Path frontend\Dockerfile
Test-Path frontend\.dockerignore
Test-Path infra\nginx\default.conf
Test-Path docker-compose.yml
```

**Ожидаемый результат:** Все файлы должны вернуть `True`

---

## ШАГ 3: Пересборка контейнеров

```powershell
# Пересобрать все контейнеры (особенно frontend)
docker-compose build --no-cache frontend

# Если нужно пересобрать все:
docker-compose build --no-cache
```

**Время выполнения:** 5-10 минут (зависит от скорости интернета для загрузки образов)

**Ожидаемый результат:** Успешная сборка без ошибок.

---

## ШАГ 4: Запуск всех сервисов

```powershell
# Запустить все сервисы в фоновом режиме
docker-compose up -d

# Или с выводом логов (для первого запуска):
docker-compose up
```

**Ожидаемый результат:** Все сервисы запущены.

---

## ШАГ 5: Проверка статуса сервисов

```powershell
# Проверить, что все контейнеры запущены
docker-compose ps

# Должны быть запущены:
# - django-api (статус: Up)
# - frontend (статус: Up)
# - nginx (статус: Up)
# - db, redis, minio, celery, celery-beat
```

**Ожидаемый результат:** Все сервисы в статусе `Up`

---

## ШАГ 6: Проверка логов

```powershell
# Проверить логи frontend (Next.js)
docker-compose logs frontend

# Проверить логи nginx
docker-compose logs nginx

# Следить за логами в реальном времени (Ctrl+C для выхода)
docker-compose logs -f frontend nginx
```

**Что искать:**
- Frontend: `Ready on http://0.0.0.0:3000`
- Nginx: `started` или без ошибок

---

## ШАГ 7: Проверка доступности

### В браузере:

1. Откройте `http://localhost` (или ваш домен)
2. Откройте DevTools (F12)
3. Перейдите на вкладку **Console**
4. Проверьте, что нет ошибок 502

### Проверка через curl (опционально):

```powershell
# Проверить главную страницу
curl http://localhost

# Проверить API
curl http://localhost/api/health/

# Проверить frontend напрямую (если порт открыт)
curl http://localhost:3000
```

---

## ШАГ 8: Очистка кэша браузера и Service Worker

Если ошибки все еще есть:

1. Откройте браузер
2. Нажмите `F12` → вкладка **Application**
3. В левом меню: **Service Workers**
4. Нажмите **Unregister** для всех зарегистрированных workers
5. В левом меню: **Storage** → **Clear site data**
6. Обновите страницу (`Ctrl+F5`)

---

## Полная последовательность команд (копировать целиком)

```powershell
# 1. Перейти в корень проекта
cd C:\ringo-uchet

# 2. Остановить контейнеры
docker-compose down

# 3. Пересобрать frontend
docker-compose build --no-cache frontend

# 4. Запустить все сервисы
docker-compose up -d

# 5. Проверить статус
docker-compose ps

# 6. Проверить логи (последние 50 строк)
docker-compose logs --tail=50 frontend
docker-compose logs --tail=50 nginx
```

---

## Если что-то пошло не так

### Проблема: Контейнер frontend не запускается

```powershell
# Проверить логи с ошибками
docker-compose logs frontend

# Попробовать запустить вручную для отладки
docker-compose run --rm frontend sh
```

### Проблема: Nginx не может подключиться к frontend

```powershell
# Проверить, что frontend слушает на порту 3000
docker-compose exec frontend netstat -tuln | findstr 3000

# Или проверить логи nginx
docker-compose logs nginx | Select-String "error"
```

### Проблема: Порты заняты

```powershell
# Проверить, какие порты заняты
netstat -ano | findstr ":80"
netstat -ano | findstr ":3000"

# Если порт 80 занят, измените в docker-compose.yml:
# ports:
#   - "8080:80"  # Вместо "80:80"
```

### Проблема: Нужно полностью пересоздать все

```powershell
# Остановить и удалить ВСЕ (включая volumes)
docker-compose down -v

# Удалить все образы проекта
docker-compose down --rmi all

# Пересобрать все с нуля
docker-compose build --no-cache

# Запустить
docker-compose up -d
```

---

## Проверка работоспособности после исправления

### 1. Проверка Service Worker

Откройте браузер → F12 → Application → Service Workers:
- Должен быть зарегистрирован `webpush-sw.js`
- Статус: `activated and is running`

### 2. Проверка API запросов

Откройте браузер → F12 → Network:
- Запросы к `/api/v1/` должны возвращать 200 или 401 (не 502)
- Запросы к `/` должны возвращать 200

### 3. Проверка консоли

Откройте браузер → F12 → Console:
- Не должно быть ошибок `502 Bad Gateway`
- Не должно быть ошибок `Failed to load resource`

---

## Быстрая проверка (одна команда)

```powershell
docker-compose ps | Select-String "Up"
```

Должно показать все сервисы в статусе `Up`.

---

## Контакты для помощи

Если проблема не решается:
1. Сохраните вывод `docker-compose logs frontend nginx`
2. Сохраните вывод `docker-compose ps`
3. Проверьте файлы конфигурации на наличие изменений


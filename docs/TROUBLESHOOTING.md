# 🔧 Решение проблем

## Ошибка: WeasyPrint не может загрузить библиотеки

**Симптомы:**
```
OSError: cannot load library 'libgobject-2.0-0': libgobject-2.0-0: cannot open shared object file: No such file or directory
```

**Причина:** В Docker контейнере отсутствуют системные зависимости для WeasyPrint.

**Решение:**

1. **Пересоберите Docker образ** (после обновления Dockerfile):
   ```bash
   docker compose build --no-cache django-api celery celery-beat
   ```

2. **Перезапустите контейнеры:**
   ```bash
   docker compose down
   docker compose up -d
   ```

3. **Проверьте, что зависимости установлены:**
   ```bash
   docker compose exec django-api apt list --installed | grep -E "(libgobject|libpango|libcairo)"
   ```

**Если проблема остаётся:**

Убедитесь, что в `backend/Dockerfile` установлены все зависимости:
- `libpango-1.0-0`
- `libpangoft2-1.0-0`
- `libgobject-2.0-0`
- `libgirepository-1.0-1`
- `libcairo2`
- `libgdk-pixbuf-xlib-2.0-0` (для Debian Trixie и новее; старые версии используют `libgdk-pixbuf2.0-0`)
- `libgdk-pixbuf-xlib-2.0-dev` (для Debian Trixie и новее; старые версии используют `libgdk-pixbuf2.0-dev`)
- `shared-mime-info`

---

## Ошибка: version в docker-compose.yml устарела

**Симптомы:**
```
warning msg="docker-compose.yml: the attribute `version` is obsolete"
```

**Решение:** Удалите строку `version: "3.9"` из `docker-compose.yml` (уже исправлено).

---

## Ошибка: Не могу создать суперпользователя

**Симптомы:**
```
CommandError: You must use --phone with --noinput
```

**Решение:** Используйте Python shell вместо команды `createsuperuser`:

```bash
docker compose exec django-api python manage.py shell
```

```python
from users.models import User
User.objects.create_superuser(
    phone='+79991234567',
    email='admin@ringo.local',
    password='admin123',
    role='admin'
)
exit()
```

---

## Ошибка: База данных не подключается

**Симптомы:**
```
django.db.utils.OperationalError: could not connect to server
```

**Решение:**

1. Проверьте, что контейнер БД запущен:
   ```bash
   docker compose ps db
   ```

2. Подождите 10-15 секунд после `docker compose up` (БД инициализируется)

3. Проверьте логи БД:
   ```bash
   docker compose logs db
   ```

4. Проверьте переменные окружения в `backend/.env`:
   - `POSTGRES_HOST=db` (не `localhost`!)
   - `POSTGRES_DB=ringo`
   - `POSTGRES_USER=ringo`
   - `POSTGRES_PASSWORD=ringo`

---

## Ошибка: Порт уже занят

**Симптомы:**
```
Error: bind: address already in use
```

**Решение:**

1. Найдите процесс, использующий порт:
   ```bash
   # Windows PowerShell
   netstat -ano | findstr :8000
   
   # Linux/Mac
   lsof -i :8000
   ```

2. Остановите процесс или измените порт в `docker-compose.yml`:
   ```yaml
   ports:
     - "8001:8000"  # Используйте другой порт
   ```

---

## Ошибка: Celery не работает

**Симптомы:**
- Задачи не выполняются
- Ошибки в логах Celery

**Решение:**

1. Проверьте, что Redis запущен:
   ```bash
   docker compose ps redis
   ```

2. Проверьте переменные окружения:
   ```env
   CELERY_BROKER_URL=redis://redis:6379/0
   CELERY_RESULT_BACKEND=redis://redis:6379/0
   ```

3. Проверьте логи Celery:
   ```bash
   docker compose logs celery
   ```

4. Перезапустите Celery:
   ```bash
   docker compose restart celery celery-beat
   ```

---

## Ошибка: Миграции не применяются

**Симптомы:**
```
django.db.migrations.exceptions.InconsistentMigrationHistory
```

**Решение:**

1. Проверьте текущее состояние миграций:
   ```bash
   docker compose exec django-api python manage.py showmigrations
   ```

2. Примените миграции вручную:
   ```bash
   docker compose exec django-api python manage.py migrate
   ```

3. Если проблема остаётся, сбросьте БД (⚠️ удалит все данные):
   ```bash
   docker compose down -v  # Удалит volumes
   docker compose up -d
   docker compose exec django-api python manage.py migrate
   ```

---

## Ошибка: Статические файлы не загружаются

**Симптомы:**
- 404 на `/static/...`
- CSS/JS не работают

**Решение:**

1. Соберите статические файлы:
   ```bash
   docker compose exec django-api python manage.py collectstatic --noinput
   ```

2. Проверьте настройки в `settings/base.py`:
   ```python
   STATIC_URL = "/static/"
   STATIC_ROOT = BASE_DIR / "staticfiles"
   ```

---

## Ошибка: MinIO не доступен

**Симптомы:**
- Ошибки при загрузке файлов
- Не могу подключиться к MinIO

**Решение:**

1. Проверьте, что MinIO запущен:
   ```bash
   docker compose ps minio
   ```

2. Проверьте переменные окружения:
   ```env
   AWS_S3_ENDPOINT_URL=http://minio:9000
   AWS_ACCESS_KEY_ID=minioadmin
   AWS_SECRET_ACCESS_KEY=minioadmin
   ```

3. Откройте консоль MinIO: http://localhost:9001
   - Login: `minioadmin`
   - Password: `minioadmin`

4. Создайте bucket `ringo-media` в консоли MinIO

---

## Ошибка: Content Security Policy блокирует eval()

**Симптомы:**
```
Content Security Policy of your site blocks the use of 'eval' in JavaScript
script-src заблокирован
```

**Причина:** Flutter web использует `eval()` внутренне для hot reload и генерации кода. Браузер блокирует выполнение из-за строгой Content Security Policy (CSP).

**Решение:**

CSP уже настроен в `mobile/web/index.html` с разрешением `unsafe-eval` для `script-src`. Это необходимо для работы Flutter web.

**Важно для production:**

1. **Текущая конфигурация** разрешает `unsafe-eval`, что необходимо для Flutter web
2. В production можно попытаться использовать более строгую CSP, но Flutter может требовать `unsafe-eval` даже в production сборках
3. Если вы используете nginx или другой веб-сервер для раздачи Flutter web, убедитесь, что CSP заголовки не конфликтуют с мета-тегом в HTML

**Проверка:**

Откройте DevTools (F12) → Console и убедитесь, что ошибок CSP больше нет.

---

## Общие советы

### Просмотр логов

```bash
# Все логи
docker compose logs -f

# Конкретный сервис
docker compose logs -f django-api
docker compose logs -f celery
docker compose logs -f db
```

### Пересборка после изменений

После изменения `Dockerfile` или `requirements.txt`:

```bash
docker compose build --no-cache
docker compose up -d
```

### Полный сброс (⚠️ удалит все данные)

```bash
docker compose down -v
docker compose build --no-cache
docker compose up -d
docker compose exec django-api python manage.py migrate
```

### Проверка здоровья контейнеров

```bash
docker compose ps
docker compose exec django-api python manage.py check
```

---

## Получение помощи

Если проблема не решена:

1. Проверьте логи: `docker compose logs`
2. Проверьте документацию: `docs/`
3. Убедитесь, что все зависимости установлены
4. Проверьте версии Docker и Docker Compose


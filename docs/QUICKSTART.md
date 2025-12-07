# 🚀 Быстрый старт проекта Ringo Uchet

## ⚠️ Важно: Если видите ошибку WeasyPrint

Если при запуске видите ошибку:
```
WeasyPrint not available: cannot load library 'libgobject-2.0-0'
```

**Выполните пересборку образа:**
```bash
# Windows PowerShell
.\fix-and-start.ps1

# Или вручную:
docker compose down
docker compose build --no-cache django-api celery celery-beat
docker compose up -d
docker compose exec django-api python manage.py migrate
```

---

## Предварительные требования

- Docker Desktop (Windows/Mac) или Docker + Docker Compose (Linux)
- Git
- Терминал (PowerShell, CMD, или Git Bash на Windows)

---

## Шаг 1: Подготовка окружения

### 1.1 Создайте файл `.env` для backend

Скопируйте шаблон и заполните переменные:

```bash
cd backend
copy .env.example .env
```

Или создайте файл `backend/.env` вручную со следующим содержимым:

```env
# Django
DJANGO_SETTINGS_MODULE=ringo_backend.settings.local
DJANGO_SECRET_KEY=your-secret-key-here-change-in-production
DJANGO_ALLOWED_HOSTS=localhost,127.0.0.1
CORS_ALLOWED_ORIGINS=http://localhost:3000

# Database
POSTGRES_DB=ringo
POSTGRES_USER=ringo
POSTGRES_PASSWORD=ringo
POSTGRES_HOST=db
POSTGRES_PORT=5432

# Redis
REDIS_URL=redis://redis:6379/0
CELERY_BROKER_URL=redis://redis:6379/0
CELERY_RESULT_BACKEND=redis://redis:6379/0

# Email (опционально)
EMAIL_HOST=smtp.gmail.com
EMAIL_PORT=587
EMAIL_USE_TLS=true
EMAIL_HOST_USER=
EMAIL_HOST_PASSWORD=

# S3/MinIO
AWS_ACCESS_KEY_ID=minioadmin
AWS_SECRET_ACCESS_KEY=minioadmin
AWS_BUCKET=ringo-media
AWS_S3_ENDPOINT_URL=http://minio:9000
AWS_S3_REGION_NAME=

# MinIO
MINIO_ROOT_USER=minioadmin
MINIO_ROOT_PASSWORD=minioadmin

# Encryption (сгенерируйте ключ: python -c "from cryptography.fernet import Fernet; print(Fernet.generate_key().decode())")
ENCRYPTION_KEY=

# JWT
JWT_ACCESS_MINUTES=30
JWT_REFRESH_DAYS=7

# Notifications (опционально)
FCM_SERVER_KEY=
TELEGRAM_BOT_TOKEN=
SMS_API_KEY=
SMS_API_URL=
```

**Важно:** Замените `DJANGO_SECRET_KEY` на случайную строку (можно сгенерировать через Django: `python -c "from django.core.management.utils import get_random_secret_key; print(get_random_secret_key())"`)

---

## Шаг 2: Запуск Docker контейнеров

### 2.1 Соберите и запустите все сервисы

```bash
# Из корневой директории проекта
make build
make up
```

Или вручную:

```bash
docker compose build
docker compose up -d
```

Это запустит:
- **django-api** - Django REST API (порт 8000)
- **db** - PostgreSQL (порт 5432)
- **redis** - Redis (порт 6379)
- **minio** - MinIO S3 storage (порты 9000, 9001)
- **celery** - Celery worker
- **celery-beat** - Celery scheduler
- **nginx** - Nginx reverse proxy (порт 80)

### 2.2 Проверьте статус контейнеров

```bash
docker compose ps
```

Все контейнеры должны быть в статусе `Up`.

---

## Шаг 3: Применение миграций базы данных

```bash
make migrate
```

Или:

```bash
docker compose exec django-api python manage.py migrate
```

Это создаст все необходимые таблицы в базе данных.

---

## Шаг 4: Создание суперпользователя (админа)

```bash
make shell
```

В Django shell выполните:

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

Или через команду (если она настроена):

```bash
docker compose exec django-api python manage.py createsuperuser
```

**Примечание:** Если команда `createsuperuser` не работает с кастомной моделью User, используйте Python shell выше.

---

## Шаг 5: Сбор статических файлов (опционально)

```bash
make collectstatic
```

Или:

```bash
docker compose exec django-api python manage.py collectstatic --noinput
```

---

## Шаг 6: Проверка работы

### 6.1 Проверьте API

Откройте в браузере:
- **Swagger UI:** http://localhost:8000/api/docs/
- **ReDoc:** http://localhost:8000/api/redoc/
- **OpenAPI Schema:** http://localhost:8000/api/schema/

### 6.2 Войдите в админку

1. Откройте: http://localhost:8000/admin/
2. Введите:
   - **Username/Phone:** `+79991234567` (или email)
   - **Password:** `admin123`

### 6.3 Проверьте MinIO консоль

- URL: http://localhost:9001
- Login: `minioadmin`
- Password: `minioadmin`

---

## Шаг 7: Создание тестовых данных (опционально)

### 7.1 Создайте тестового менеджера

```bash
make shell
```

```python
from users.models import User
User.objects.create_user(
    phone='+79997654321',
    email='manager@ringo.local',
    password='manager123',
    role='manager',
    first_name='Иван',
    last_name='Менеджеров'
)
exit()
```

### 7.2 Создайте тестовое оборудование

```python
from catalog.models import Equipment
Equipment.objects.create(
    code='EXC-001',
    name='Экскаватор JCB 3CX',
    hourly_rate=1500.00,
    daily_rate=12000.00,
    status='available'
)
exit()
```

---

## Полезные команды

### Просмотр логов

```bash
# Все логи
docker compose logs -f

# Только Django
make logs

# Только Celery
docker compose logs -f celery
```

### Остановка проекта

```bash
make down
```

### Перезапуск проекта

```bash
make down
make up
```

### Выполнение команд в контейнере

```bash
# Django shell
make shell

# Миграции
make migrate

# Создание миграций
make makemigrations

# Тесты
make test
```

---

## Решение проблем

### Проблема: Контейнеры не запускаются

**Решение:**
1. Проверьте, что порты 8000, 5432, 6379, 9000, 9001 не заняты
2. Проверьте логи: `docker compose logs`
3. Убедитесь, что Docker Desktop запущен

### Проблема: Ошибка подключения к базе данных

**Решение:**
1. Убедитесь, что контейнер `db` запущен: `docker compose ps`
2. Проверьте переменные окружения в `backend/.env`
3. Подождите 10-15 секунд после запуска (БД инициализируется)

### Проблема: Миграции не применяются

**Решение:**
1. Убедитесь, что БД запущена: `docker compose ps db`
2. Проверьте логи: `docker compose logs db`
3. Попробуйте применить миграции вручную: `make migrate`

### Проблема: Не могу войти в админку

**Решение:**
1. Убедитесь, что суперпользователь создан
2. Проверьте, что используете правильный phone/email
3. Попробуйте сбросить пароль через shell:
   ```python
   from users.models import User
   user = User.objects.get(phone='+79991234567')
   user.set_password('admin123')
   user.save()
   ```

### Проблема: Celery не работает

**Решение:**
1. Проверьте, что Redis запущен: `docker compose ps redis`
2. Проверьте логи Celery: `docker compose logs celery`
3. Убедитесь, что `CELERY_BROKER_URL` правильный в `.env`

---

## Следующие шаги

После успешного запуска:

1. ✅ Изучите API документацию: http://localhost:8000/api/docs/
2. ✅ Создайте тестовые данные (технику, клиентов, заявки)
3. ✅ Настройте уведомления (FCM, Telegram, Email)
4. ✅ Настройте production окружение (см. `docs/DEPLOYMENT.md`)

---

## Контакты и поддержка

При возникновении проблем проверьте:
- Логи контейнеров: `docker compose logs`
- Документацию: `docs/`
- GitHub Issues (если проект на GitHub)


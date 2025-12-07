# Troubleshooting Django Admin

Руководство по решению проблем с доступом к Django Admin панели.

## Проблема: Админка не открывается

### Симптомы
- В консоли нет ошибок
- Админка не загружается в браузере
- Возможна ошибка 403 Forbidden или таймаут

### Возможные причины и решения

#### 1. IP Allowlist блокирует доступ

**Проблема:** `IPAllowlistMiddleware` блокирует доступ к `/admin/` endpoints.

**Решение:**

1. Проверьте текущие настройки:
   ```bash
   docker compose exec django-api python manage.py check_admin
   ```

2. Для локальной разработки отключите IP allowlist:
   ```env
   # В backend/.env или через переменные окружения
   ADMIN_ALLOWED_IPS=
   ```

3. Или добавьте ваш IP в список разрешенных:
   ```env
   ADMIN_ALLOWED_IPS=127.0.0.1,::1,172.17.0.1
   ```

4. Перезапустите контейнер:
   ```bash
   docker compose restart django-api
   ```

#### 2. Проблемы с middleware

**Проблема:** Один из security middleware вызывает ошибку.

**Решение:**

1. Проверьте логи:
   ```bash
   docker compose logs django-api | grep -i error
   docker compose logs django-api | grep -i middleware
   ```

2. Временно отключите проблемный middleware в `settings/base.py`:
   ```python
   MIDDLEWARE = [
       # Закомментируйте проблемный middleware
       # "ringo_backend.middleware.security.IPAllowlistMiddleware",
       ...
   ]
   ```

3. Перезапустите:
   ```bash
   docker compose restart django-api
   ```

#### 3. Проблемы с URL маршрутизацией

**Проблема:** URL не настроен правильно.

**Решение:**

1. Проверьте URL patterns:
   ```bash
   docker compose exec django-api python manage.py check_admin
   ```

2. Проверьте вручную:
   ```bash
   docker compose exec django-api python manage.py shell
   ```
   ```python
   from django.urls import reverse
   reverse('admin:index')
   ```

#### 4. Проблемы с nginx

**Проблема:** Nginx не проксирует запросы к Django.

**Решение:**

1. Проверьте конфигурацию nginx:
   ```bash
   docker compose exec nginx cat /etc/nginx/conf.d/default.conf
   ```

2. Проверьте логи nginx:
   ```bash
   docker compose logs nginx
   ```

3. Попробуйте доступ напрямую к Django (минуя nginx):
   ```
   http://localhost:8001/admin/
   ```

#### 5. Проблемы с базой данных

**Проблема:** Пользователь admin не создан или не может войти.

**Решение:**

1. Создайте суперпользователя:
   ```bash
   docker compose exec django-api python manage.py createsuperuser
   ```

2. Или используйте скрипт:
   ```bash
   docker compose exec django-api python create_admin.py
   ```

#### 6. Проблемы с CSRF

**Проблема:** CSRF токен не работает.

**Решение:**

1. Проверьте настройки CSRF в `settings/local.py`:
   ```python
   CSRF_COOKIE_SECURE = False  # Для HTTP в разработке
   CSRF_TRUSTED_ORIGINS = ['http://localhost', 'http://127.0.0.1']
   ```

2. Добавьте в `settings/local.py`:
   ```python
   CSRF_TRUSTED_ORIGINS = ['http://localhost', 'http://127.0.0.1', 'http://localhost:8001']
   ```

## Диагностика

### Команда проверки

```bash
docker compose exec django-api python manage.py check_admin
```

Эта команда покажет:
- Настройки безопасности
- Состояние middleware
- URL patterns
- Зарегистрированные модели

### Проверка логов

```bash
# Все логи Django
docker compose logs django-api

# Только ошибки
docker compose logs django-api | grep -i error

# Security логи
docker compose logs django-api | grep -i security

# Middleware логи
docker compose logs django-api | grep -i middleware
```

### Проверка доступа

1. **Прямой доступ к Django (минуя nginx):**
   ```
   http://localhost:8001/admin/
   ```

2. **Через nginx:**
   ```
   http://localhost/admin/
   ```

3. **Проверка health check:**
   ```bash
   curl http://localhost:8001/api/health/
   ```

## Быстрое решение

Если ничего не помогает, временно отключите все security middleware:

1. Отредактируйте `backend/ringo_backend/settings/local.py`:
   ```python
   # Временно отключить security middleware
   MIDDLEWARE = [
       "django.middleware.security.SecurityMiddleware",
       "corsheaders.middleware.CorsMiddleware",
       "django.contrib.sessions.middleware.SessionMiddleware",
       "django.middleware.common.CommonMiddleware",
       "django.middleware.csrf.CsrfViewMiddleware",
       "django.contrib.auth.middleware.AuthenticationMiddleware",
       "django.contrib.messages.middleware.MessageMiddleware",
       "django.middleware.clickjacking.XFrameOptionsMiddleware",
       "ringo_backend.middleware.RequestIDMiddleware",
       "ringo_backend.middleware.AuditLogMiddleware",
   ]
   ```

2. Перезапустите:
   ```bash
   docker compose restart django-api
   ```

3. Попробуйте снова открыть админку.

## Профилактика

1. Всегда используйте `check_admin` команду после изменений в security настройках
2. Проверяйте логи при проблемах
3. Для production обязательно настройте `ADMIN_ALLOWED_IPS`
4. Регулярно проверяйте доступность админки


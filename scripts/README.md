# Scripts

Вспомогательные скрипты для проекта.

## API Regression Test

**Файл:** `api_regression_test.py`

Простой скрипт для проверки основных эндпоинтов API перед редкими обновлениями.

### Использование

```bash
# Базовое использование (localhost:8001)
python scripts/api_regression_test.py

# С указанием URL
python scripts/api_regression_test.py --base-url http://api.example.com

# С указанием учетных данных
python scripts/api_regression_test.py --username admin --password your_password
```

### Что проверяет

1. Health check (`/api/health/`)
2. Login (`/api/v1/token/`)
3. Get current user (`/api/v1/users/me/`)
4. Get clients (`/api/v1/clients/`)
5. Get equipment (`/api/v1/equipment/`)
6. Get orders (`/api/v1/orders/`)
7. Create order (`/api/v1/orders/`)

### Установка зависимостей

**Вариант 1: Установка в корне проекта (рекомендуется)**

```bash
# Из корня проекта
pip install -r scripts/requirements.txt

# Или напрямую
pip install httpx
```

**Вариант 2: Использование виртуального окружения**

```bash
# Создать виртуальное окружение (если еще нет)
python -m venv venv

# Активировать (Windows)
venv\Scripts\activate

# Активировать (Linux/Mac)
source venv/bin/activate

# Установить зависимости
pip install -r scripts/requirements.txt
```

**Вариант 3: Использование requests (уже есть в backend/requirements.txt)**

Если вы уже установили зависимости Django проекта:
```bash
cd backend
pip install -r requirements.txt
# requests уже включен, можно использовать его
```

Скрипт автоматически использует доступную библиотеку (httpx или requests).

**Примечание:** Скрипт можно запускать из любой директории, но зависимости должны быть установлены в том же Python окружении, которое используется для запуска.

### Пример вывода

```
============================================================
API Regression Test Suite
============================================================

ℹ Тест 1: Health check
✓ Health check passed
ℹ Тест 2: Login
✓ Login successful
ℹ Тест 3: Get current user
✓ Current user: admin
...
============================================================
Results: 7/7 tests passed
============================================================
```

### Когда запускать

- Перед редкими обновлениями production
- После деплоя новой версии
- При подозрении на проблемы с API
- Вручную по необходимости


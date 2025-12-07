# Установка зависимостей для скриптов

## Где устанавливать?

Скрипты находятся в `scripts/` в корне проекта, но они не являются частью Django приложения. Поэтому есть несколько вариантов установки зависимостей.

## Рекомендуемый способ

### 1. Установка в системное Python окружение (самый простой)

Если у вас уже установлен Python и pip:

```bash
# Из корня проекта
pip install httpx

# Или из папки scripts
cd scripts
pip install httpx
```

### 2. Использование виртуального окружения (рекомендуется для изоляции)

```bash
# Создать виртуальное окружение в корне проекта
python -m venv venv

# Активировать (Windows PowerShell)
.\venv\Scripts\Activate.ps1

# Активировать (Windows CMD)
venv\Scripts\activate.bat

# Активировать (Linux/Mac)
source venv/bin/activate

# Установить зависимости
pip install -r scripts/requirements.txt
```

### 3. Использование существующих зависимостей Django

Если вы уже установили зависимости Django проекта (`backend/requirements.txt`), то `requests` уже включен:

```bash
# Установить зависимости Django (если еще не установлены)
cd backend
pip install -r requirements.txt

# Теперь можно использовать скрипт, он автоматически найдет requests
cd ..
python scripts/api_regression_test.py
```

## Проверка установки

```bash
# Проверить, что httpx установлен
python -c "import httpx; print('httpx OK')"

# Или requests
python -c "import requests; print('requests OK')"
```

## Запуск скрипта

После установки зависимостей скрипт можно запускать из любой директории:

```bash
# Из корня проекта
python scripts/api_regression_test.py

# Или из папки scripts
cd scripts
python api_regression_test.py
```

## Важно

- Скрипт автоматически определяет, какая библиотека доступна (httpx или requests)
- Если обе библиотеки установлены, используется httpx (приоритет)
- Если ни одна не установлена, скрипт выдаст понятную ошибку с инструкцией


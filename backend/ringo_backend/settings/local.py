from __future__ import annotations
import os
from pathlib import Path

# Загружаем переменные окружения из .env файла с правильной кодировкой
try:
    from dotenv import load_dotenv
    BASE_DIR = Path(__file__).resolve().parent.parent.parent
    env_file = BASE_DIR / '.env'
    if env_file.exists():
        load_dotenv(env_file, encoding='utf-8')
except ImportError:
    pass

from .base import *  # noqa

DEBUG = True

ALLOWED_HOSTS = ["*", "127.0.0.1", "localhost"]

INSTALLED_APPS += ["django_extensions"]  # type: ignore

EMAIL_BACKEND = "django.core.mail.backends.console.EmailBackend"

# CORS настройки для локальной разработки
# ВНИМАНИЕ: Это только для разработки! Никогда не используйте в production!
CORS_ALLOW_ALL_ORIGINS = True  # Разрешаем все origins для разработки
CORS_ALLOW_CREDENTIALS = True

# Разрешаем все заголовки и методы
CORS_ALLOW_HEADERS = [
    "accept",
    "accept-encoding",
    "authorization",
    "content-type",
    "dnt",
    "origin",
    "user-agent",
    "x-csrftoken",
    "x-requested-with",
]

CORS_ALLOW_METHODS = [
    "DELETE",
    "GET",
    "OPTIONS",
    "PATCH",
    "POST",
    "PUT",
]

# Security settings для локальной разработки
# IP allowlist отключен (разрешаем всем)
ADMIN_ALLOWED_IPS = []


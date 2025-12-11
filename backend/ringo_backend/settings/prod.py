from __future__ import annotations
import os

from .base import *  # noqa

# Переопределяем STATIC_ROOT и MEDIA_ROOT для production (чтобы использовать writable volumes)
# В docker-compose.prod.yml смонтированы volumes ./staticfiles:/app/staticfiles и ./media:/app/media
# Важно: устанавливаем как строки, а не Path объекты, чтобы избежать проблем с путями
# Используем os.path для гарантии правильного формата пути
STATIC_ROOT = os.path.normpath("/app/staticfiles")
MEDIA_ROOT = os.path.normpath("/app/media")

# Убеждаемся, что это строки, а не Path объекты
if not isinstance(STATIC_ROOT, str):
    STATIC_ROOT = str(STATIC_ROOT)
if not isinstance(MEDIA_ROOT, str):
    MEDIA_ROOT = str(MEDIA_ROOT)

DEBUG = False

ALLOWED_HOSTS = [
    host.strip()
    for host in __import__("os").environ.get("DJANGO_ALLOWED_HOSTS", "").split(",")
    if host.strip()
]

if not ALLOWED_HOSTS:
    raise RuntimeError("DJANGO_ALLOWED_HOSTS must be set in production")

CSRF_TRUSTED_ORIGINS = [
    origin.strip()
    for origin in __import__("os").environ.get("CSRF_TRUSTED_ORIGINS", "").split(",")
    if origin.strip()
]

SECURE_PROXY_SSL_HEADER = ("HTTP_X_FORWARDED_PROTO", "https")
SECURE_HSTS_SECONDS = 31536000
SECURE_HSTS_INCLUDE_SUBDOMAINS = True
SECURE_HSTS_PRELOAD = True
SESSION_COOKIE_SECURE = True
CSRF_COOKIE_SECURE = True
SECURE_SSL_REDIRECT = True

LOGGING["root"]["level"] = "WARNING"  # type: ignore

# CORS настройки для production
# Разрешаем только определенные origins из переменной окружения
_cors_origins_env = __import__("os").environ.get("CORS_ALLOWED_ORIGINS", "")
CORS_ALLOWED_ORIGINS = [
    origin.strip()
    for origin in _cors_origins_env.split(",")
    if origin.strip()
]

# Если CORS_ALLOWED_ORIGINS не задан, используем регулярные выражения для localhost (для разработки)
if not CORS_ALLOWED_ORIGINS:
    import re
    CORS_ALLOWED_ORIGIN_REGEXES = [
        re.compile(r"^http://localhost:\d+$"),
        re.compile(r"^http://127\.0\.0\.1:\d+$"),
        re.compile(r"^http://\[::1\]:\d+$"),  # IPv6 localhost
    ]
else:
    CORS_ALLOWED_ORIGIN_REGEXES = []

# Разрешаем credentials для CORS
CORS_ALLOW_CREDENTIALS = True

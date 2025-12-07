from __future__ import annotations

from .base import *  # noqa

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


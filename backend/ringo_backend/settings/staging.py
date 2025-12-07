from __future__ import annotations

from .base import *  # noqa

DEBUG = False

ALLOWED_HOSTS = __import__("os").environ.get(
    "DJANGO_ALLOWED_HOSTS", "staging.ringo.local"
).split(",")

CSRF_TRUSTED_ORIGINS = [
    origin.strip()
    for origin in __import__("os").environ.get(
        "CSRF_TRUSTED_ORIGINS", "https://staging.ringo.local"
    ).split(",")
    if origin.strip()
]


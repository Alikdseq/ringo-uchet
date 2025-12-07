from __future__ import annotations

import os

from celery import Celery

os.environ.setdefault("DJANGO_SETTINGS_MODULE", "ringo_backend.settings.local")

app = Celery("ringo_backend")
app.config_from_object("django.conf:settings", namespace="CELERY")
app.autodiscover_tasks()

# Импортируем signals для Prometheus метрик
# Это должно быть после autodiscover_tasks()
try:
    import ringo_backend.celery_signals  # noqa: F401
except ImportError:
    pass  # Signals не критичны для работы приложения


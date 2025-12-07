from __future__ import annotations

from django.apps import AppConfig


class AuditConfig(AppConfig):
    default_auto_field = "django.db.models.BigAutoField"
    name = "audit"

    def ready(self):
        """Подключение сигналов при инициализации приложения"""
        import audit.signals  # noqa: F401


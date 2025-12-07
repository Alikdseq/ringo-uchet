from __future__ import annotations

from django.conf import settings
from django.db import models


class AuditAction(models.TextChoices):
    CREATE = "create", "Создание"
    UPDATE = "update", "Обновление"
    DELETE = "delete", "Удаление"
    VIEW = "view", "Просмотр"
    EXPORT = "export", "Экспорт"
    STATUS_CHANGE = "status_change", "Изменение статуса"
    FILE_UPLOAD = "file_upload", "Загрузка файла"
    PAYMENT = "payment", "Платёж"
    ROLE_CHANGE = "role_change", "Изменение роли"


class AuditLog(models.Model):
    """Таблица для аудита всех действий пользователей"""

    actor = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="audit_logs",
        verbose_name="Пользователь",
        help_text="Пользователь, выполнивший действие",
    )
    action = models.CharField(
        max_length=50, choices=AuditAction.choices, db_index=True, verbose_name="Действие", help_text="Тип выполненного действия"
    )
    entity_type = models.CharField(
        max_length=100,
        db_index=True,
        verbose_name="Тип сущности",
        help_text="Тип сущности (Order, Invoice, User, etc.)",
    )
    entity_id = models.CharField(
        max_length=255,
        db_index=True,
        verbose_name="ID сущности",
        help_text="ID сущности (может быть UUID)",
    )
    payload = models.JSONField(
        default=dict,
        blank=True,
        verbose_name="Данные",
        help_text="Дополнительные данные действия (изменённые поля, значения)",
    )
    ip_address = models.GenericIPAddressField(null=True, blank=True, verbose_name="IP адрес", help_text="IP адрес пользователя")
    user_agent = models.CharField(max_length=500, blank=True, verbose_name="User Agent", help_text="User Agent браузера")
    request_id = models.CharField(
        max_length=100, blank=True, db_index=True, verbose_name="Request ID", help_text="Request ID для трейсинга"
    )
    created_at = models.DateTimeField(auto_now_add=True, db_index=True, verbose_name="Дата создания", help_text="Дата и время действия")

    class Meta:
        ordering = ["-created_at"]
        indexes = [
            models.Index(fields=["actor", "created_at"]),
            models.Index(fields=["entity_type", "entity_id"]),
            models.Index(fields=["action", "created_at"]),
        ]
        verbose_name = "Лог аудита"
        verbose_name_plural = "Логи аудита"

    def __str__(self) -> str:
        actor_name = self.actor.get_full_name() or self.actor.phone if self.actor else "System"
        return f"{actor_name} {self.action} {self.entity_type}#{self.entity_id}"


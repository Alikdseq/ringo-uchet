from __future__ import annotations

from django.conf import settings
from django.db import models


class NotificationChannel(models.TextChoices):
    PUSH = "push", "Push-уведомление"
    EMAIL = "email", "Email"
    TELEGRAM = "telegram", "Telegram"
    SMS = "sms", "SMS"


class DeviceToken(models.Model):
    """FCM device token для push уведомлений"""
    user = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name="device_tokens",
        null=True,
        blank=True,
        verbose_name="Пользователь",
        help_text="Пользователь, которому принадлежит токен",
    )
    token = models.CharField(
        max_length=255, unique=True, db_index=True, verbose_name="Токен", help_text="FCM токен устройства"
    )
    platform = models.CharField(
        max_length=20, choices=[("ios", "iOS"), ("android", "Android")], verbose_name="Платформа", help_text="Платформа устройства"
    )
    app_version = models.CharField(max_length=20, blank=True, verbose_name="Версия приложения", help_text="Версия мобильного приложения")
    device_info = models.JSONField(default=dict, blank=True, verbose_name="Информация об устройстве", help_text="Дополнительная информация об устройстве")
    last_active_at = models.DateTimeField(auto_now=True, verbose_name="Последняя активность", help_text="Дата и время последней активности")
    created_at = models.DateTimeField(auto_now_add=True, verbose_name="Дата создания", help_text="Дата и время создания токена")

    class Meta:
        verbose_name = "Токен устройства"
        verbose_name_plural = "Токены устройств"
        ordering = ["-last_active_at"]

    def __str__(self) -> str:
        return f"{self.platform} {self.token[:20]}..."


class NotificationSubscription(models.Model):
    user = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name="notification_subscriptions",
        verbose_name="Пользователь",
        help_text="Пользователь, для которого настроена подписка",
    )
    channel = models.CharField(
        max_length=20, choices=NotificationChannel.choices, verbose_name="Канал", help_text="Канал уведомлений"
    )
    endpoint = models.CharField(
        max_length=255, verbose_name="Конечная точка", help_text="Device token / email / chat id"
    )
    enabled = models.BooleanField(default=True, verbose_name="Включена", help_text="Подписка активна")
    preferences = models.JSONField(
        default=dict, blank=True, verbose_name="Настройки", help_text="Настройки подписки"
    )
    last_used_at = models.DateTimeField(null=True, blank=True, verbose_name="Последнее использование", help_text="Дата и время последнего использования")
    created_at = models.DateTimeField(auto_now_add=True, verbose_name="Дата создания", help_text="Дата и время создания подписки")
    updated_at = models.DateTimeField(auto_now=True, verbose_name="Дата обновления", help_text="Дата и время последнего обновления")

    class Meta:
        verbose_name = "Подписка на уведомления"
        verbose_name_plural = "Подписки на уведомления"
        unique_together = ("user", "channel", "endpoint")
        ordering = ["-updated_at"]

    def __str__(self) -> str:
        return f"{self.user} {self.get_channel_display()}"


class NotificationLog(models.Model):
    """Лог попыток отправки уведомлений"""
    user = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.SET_NULL,
        null=True,
        related_name="notification_logs",
        verbose_name="Пользователь",
        help_text="Пользователь, которому отправлялось уведомление",
    )
    channel = models.CharField(
        max_length=20, choices=NotificationChannel.choices, verbose_name="Канал", help_text="Канал уведомлений"
    )
    endpoint = models.CharField(max_length=255, verbose_name="Конечная точка", help_text="Адрес доставки уведомления")
    event_type = models.CharField(
        max_length=50, verbose_name="Тип события", help_text="Тип события (order_created, status_changed, payment_received)"
    )
    payload = models.JSONField(default=dict, verbose_name="Данные", help_text="Данные уведомления")
    status = models.CharField(
        max_length=20,
        choices=[("pending", "Ожидает"), ("sent", "Отправлено"), ("failed", "Ошибка")],
        default="pending",
        verbose_name="Статус",
        help_text="Статус отправки уведомления",
    )
    error_message = models.TextField(blank=True, verbose_name="Сообщение об ошибке", help_text="Текст ошибки, если отправка не удалась")
    retry_count = models.IntegerField(default=0, verbose_name="Количество попыток", help_text="Количество попыток отправки")
    sent_at = models.DateTimeField(null=True, blank=True, verbose_name="Дата отправки", help_text="Дата и время успешной отправки")
    created_at = models.DateTimeField(auto_now_add=True, verbose_name="Дата создания", help_text="Дата и время создания лога")

    class Meta:
        verbose_name = "Лог уведомлений"
        verbose_name_plural = "Логи уведомлений"
        ordering = ["-created_at"]
        indexes = [
            models.Index(fields=["user", "status"]),
            models.Index(fields=["event_type", "created_at"]),
        ]

    def __str__(self) -> str:
        return f"{self.get_channel_display()} {self.event_type} {self.get_status_display()}"


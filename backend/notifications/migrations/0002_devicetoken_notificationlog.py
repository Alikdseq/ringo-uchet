from __future__ import annotations

from django.conf import settings
from django.db import migrations, models


class Migration(migrations.Migration):
    dependencies = [
        migrations.swappable_dependency(settings.AUTH_USER_MODEL),
        ("notifications", "0001_initial"),
    ]

    operations = [
        migrations.CreateModel(
            name="DeviceToken",
            fields=[
                ("id", models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name="ID")),
                ("token", models.CharField(db_index=True, max_length=255, unique=True)),
                ("platform", models.CharField(choices=[("ios", "iOS"), ("android", "Android")], max_length=20)),
                ("app_version", models.CharField(blank=True, max_length=20)),
                ("device_info", models.JSONField(blank=True, default=dict)),
                ("last_active_at", models.DateTimeField(auto_now=True)),
                ("created_at", models.DateTimeField(auto_now_add=True)),
                (
                    "user",
                    models.ForeignKey(
                        blank=True,
                        null=True,
                        on_delete=models.deletion.CASCADE,
                        related_name="device_tokens",
                        to=settings.AUTH_USER_MODEL,
                    ),
                ),
            ],
            options={
                "ordering": ["-last_active_at"],
            },
        ),
        migrations.CreateModel(
            name="NotificationLog",
            fields=[
                ("id", models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name="ID")),
                ("channel", models.CharField(choices=[("push", "Push"), ("email", "Email"), ("telegram", "Telegram"), ("sms", "SMS")], max_length=20)),
                ("endpoint", models.CharField(max_length=255)),
                ("event_type", models.CharField(help_text="order_created, status_changed, payment_received", max_length=50)),
                ("payload", models.JSONField(default=dict)),
                (
                    "status",
                    models.CharField(
                        choices=[("pending", "Pending"), ("sent", "Sent"), ("failed", "Failed")],
                        default="pending",
                        max_length=20,
                    ),
                ),
                ("error_message", models.TextField(blank=True)),
                ("retry_count", models.IntegerField(default=0)),
                ("sent_at", models.DateTimeField(blank=True, null=True)),
                ("created_at", models.DateTimeField(auto_now_add=True)),
                (
                    "user",
                    models.ForeignKey(
                        null=True,
                        on_delete=models.deletion.SET_NULL,
                        related_name="notification_logs",
                        to=settings.AUTH_USER_MODEL,
                    ),
                ),
            ],
            options={
                "ordering": ["-created_at"],
            },
        ),
        migrations.AddIndex(
            model_name="notificationlog",
            index=models.Index(fields=["user", "status"], name="notificatio_user_id_status_idx"),
        ),
        migrations.AddIndex(
            model_name="notificationlog",
            index=models.Index(fields=["event_type", "created_at"], name="notificatio_event_t_created_idx"),
        ),
    ]


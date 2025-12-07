from __future__ import annotations

from django.conf import settings
from django.db import migrations, models


class Migration(migrations.Migration):
    initial = True

    dependencies = [
        migrations.swappable_dependency(settings.AUTH_USER_MODEL),
    ]

    operations = [
        migrations.CreateModel(
            name="NotificationSubscription",
            fields=[
                ("id", models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name="ID")),
                ("channel", models.CharField(choices=[("push", "Push"), ("email", "Email"), ("telegram", "Telegram"), ("sms", "SMS")], max_length=20)),
                ("endpoint", models.CharField(help_text="Device token / email / chat id", max_length=255)),
                ("enabled", models.BooleanField(default=True)),
                ("preferences", models.JSONField(blank=True, default=dict)),
                ("last_used_at", models.DateTimeField(blank=True, null=True)),
                ("created_at", models.DateTimeField(auto_now_add=True)),
                ("updated_at", models.DateTimeField(auto_now=True)),
                ("user", models.ForeignKey(on_delete=models.deletion.CASCADE, related_name="notification_subscriptions", to=settings.AUTH_USER_MODEL)),
            ],
            options={
                "ordering": ["-updated_at"],
            },
        ),
        migrations.AlterUniqueTogether(
            name="notificationsubscription",
            unique_together={("user", "channel", "endpoint")},
        ),
    ]


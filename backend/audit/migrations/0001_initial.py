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
            name="AuditLog",
            fields=[
                ("id", models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name="ID")),
                (
                    "action",
                    models.CharField(
                        choices=[
                            ("create", "Create"),
                            ("update", "Update"),
                            ("delete", "Delete"),
                            ("view", "View"),
                            ("export", "Export"),
                            ("status_change", "Status Change"),
                            ("file_upload", "File Upload"),
                            ("payment", "Payment"),
                            ("role_change", "Role Change"),
                        ],
                        db_index=True,
                        max_length=50,
                    ),
                ),
                ("entity_type", models.CharField(db_index=True, help_text="Тип сущности (Order, Invoice, User, etc.)", max_length=100)),
                ("entity_id", models.CharField(db_index=True, help_text="ID сущности (может быть UUID)", max_length=255)),
                ("payload", models.JSONField(blank=True, default=dict, help_text="Дополнительные данные действия (изменённые поля, значения)")),
                ("ip_address", models.GenericIPAddressField(blank=True, null=True)),
                ("user_agent", models.CharField(blank=True, max_length=500)),
                ("request_id", models.CharField(blank=True, db_index=True, help_text="Request ID для трейсинга", max_length=100)),
                ("created_at", models.DateTimeField(auto_now_add=True, db_index=True)),
                (
                    "actor",
                    models.ForeignKey(
                        blank=True,
                        help_text="Пользователь, выполнивший действие",
                        null=True,
                        on_delete=models.deletion.SET_NULL,
                        related_name="audit_logs",
                        to=settings.AUTH_USER_MODEL,
                    ),
                ),
            ],
            options={
                "verbose_name": "Audit Log",
                "verbose_name_plural": "Audit Logs",
                "ordering": ["-created_at"],
            },
        ),
        migrations.AddIndex(
            model_name="auditlog",
            index=models.Index(fields=["actor", "created_at"], name="audit_auditl_actor_i_created_idx"),
        ),
        migrations.AddIndex(
            model_name="auditlog",
            index=models.Index(fields=["entity_type", "entity_id"], name="audit_auditl_entity__entity__idx"),
        ),
        migrations.AddIndex(
            model_name="auditlog",
            index=models.Index(fields=["action", "created_at"], name="audit_auditl_action__created_idx"),
        ),
    ]


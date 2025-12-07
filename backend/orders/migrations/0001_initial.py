from __future__ import annotations

import uuid

from django.conf import settings
from django.db import migrations, models
import django.db.models.deletion


class Migration(migrations.Migration):
    initial = True

    dependencies = [
        migrations.swappable_dependency(settings.AUTH_USER_MODEL),
        ("crm", "0001_initial"),
    ]

    operations = [
        migrations.CreateModel(
            name="Order",
            fields=[
                ("id", models.UUIDField(default=uuid.uuid4, editable=False, primary_key=True, serialize=False)),
                ("created_at", models.DateTimeField(auto_now_add=True)),
                ("updated_at", models.DateTimeField(auto_now=True)),
                ("number", models.CharField(max_length=32, unique=True)),
                ("address", models.CharField(max_length=500)),
                ("geo_lat", models.DecimalField(blank=True, decimal_places=6, max_digits=9, null=True)),
                ("geo_lng", models.DecimalField(blank=True, decimal_places=6, max_digits=9, null=True)),
                ("start_dt", models.DateTimeField()),
                ("end_dt", models.DateTimeField(blank=True, null=True)),
                ("description", models.TextField(blank=True)),
                ("status", models.CharField(choices=[("DRAFT", "Draft"), ("CREATED", "Created"), ("APPROVED", "Approved"), ("IN_PROGRESS", "In progress"), ("COMPLETED", "Completed"), ("CANCELLED", "Cancelled")], default="DRAFT", max_length=20)),
                ("prepayment_amount", models.DecimalField(decimal_places=2, default=0, max_digits=12)),
                ("prepayment_status", models.CharField(default="pending", max_length=20)),
                ("total_amount", models.DecimalField(decimal_places=2, default=0, max_digits=12)),
                ("price_snapshot", models.JSONField(blank=True, default=dict)),
                ("attachments", models.JSONField(blank=True, default=list)),
                ("meta", models.JSONField(blank=True, default=dict)),
                ("client", models.ForeignKey(null=True, on_delete=django.db.models.deletion.SET_NULL, related_name="orders", to="crm.client")),
                ("created_by", models.ForeignKey(blank=True, null=True, on_delete=django.db.models.deletion.SET_NULL, related_name="orders_created", to=settings.AUTH_USER_MODEL)),
                ("manager", models.ForeignKey(blank=True, null=True, on_delete=django.db.models.deletion.SET_NULL, related_name="managed_orders", to=settings.AUTH_USER_MODEL)),
                ("operator", models.ForeignKey(blank=True, null=True, on_delete=django.db.models.deletion.SET_NULL, related_name="operated_orders", to=settings.AUTH_USER_MODEL)),
            ],
            options={
                "ordering": ["-created_at"],
            },
        ),
        migrations.CreateModel(
            name="PhotoEvidence",
            fields=[
                ("id", models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name="ID")),
                ("created_at", models.DateTimeField(auto_now_add=True)),
                ("updated_at", models.DateTimeField(auto_now=True)),
                ("photo_type", models.CharField(choices=[("before", "Before"), ("after", "After"), ("incident", "Incident")], default="before", max_length=20)),
                ("file_url", models.URLField()),
                ("gps_lat", models.DecimalField(blank=True, decimal_places=6, max_digits=9, null=True)),
                ("gps_lng", models.DecimalField(blank=True, decimal_places=6, max_digits=9, null=True)),
                ("captured_at", models.DateTimeField(blank=True, null=True)),
                ("notes", models.TextField(blank=True)),
                ("metadata", models.JSONField(blank=True, default=dict)),
                ("order", models.ForeignKey(on_delete=django.db.models.deletion.CASCADE, related_name="photos", to="orders.order")),
                ("uploaded_by", models.ForeignKey(null=True, on_delete=django.db.models.deletion.SET_NULL, related_name="photo_evidence", to=settings.AUTH_USER_MODEL)),
            ],
        ),
        migrations.CreateModel(
            name="OrderStatusLog",
            fields=[
                ("id", models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name="ID")),
                ("from_status", models.CharField(blank=True, choices=[("DRAFT", "Draft"), ("CREATED", "Created"), ("APPROVED", "Approved"), ("IN_PROGRESS", "In progress"), ("COMPLETED", "Completed"), ("CANCELLED", "Cancelled")], max_length=20)),
                ("to_status", models.CharField(choices=[("DRAFT", "Draft"), ("CREATED", "Created"), ("APPROVED", "Approved"), ("IN_PROGRESS", "In progress"), ("COMPLETED", "Completed"), ("CANCELLED", "Cancelled")], max_length=20)),
                ("comment", models.TextField(blank=True)),
                ("attachment_url", models.URLField(blank=True)),
                ("created_at", models.DateTimeField(auto_now_add=True)),
                ("actor", models.ForeignKey(null=True, on_delete=django.db.models.deletion.SET_NULL, related_name="order_status_logs", to=settings.AUTH_USER_MODEL)),
                ("order", models.ForeignKey(on_delete=django.db.models.deletion.CASCADE, related_name="status_logs", to="orders.order")),
            ],
            options={
                "ordering": ["-created_at"],
            },
        ),
        migrations.CreateModel(
            name="OrderItem",
            fields=[
                ("id", models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name="ID")),
                ("created_at", models.DateTimeField(auto_now_add=True)),
                ("updated_at", models.DateTimeField(auto_now=True)),
                ("item_type", models.CharField(choices=[("equipment", "Equipment"), ("service", "Service"), ("material", "Material"), ("attachment", "Attachment")], max_length=20)),
                ("ref_id", models.PositiveIntegerField(blank=True, help_text="Reference ID in source table", null=True)),
                ("name_snapshot", models.CharField(max_length=255)),
                ("quantity", models.DecimalField(decimal_places=2, default=1, max_digits=10)),
                ("unit", models.CharField(blank=True, max_length=32)),
                ("unit_price", models.DecimalField(decimal_places=2, max_digits=12)),
                ("tax_rate", models.DecimalField(decimal_places=2, default=0, max_digits=5)),
                ("discount", models.DecimalField(decimal_places=2, default=0, max_digits=6)),
                ("metadata", models.JSONField(blank=True, default=dict)),
                ("order", models.ForeignKey(on_delete=django.db.models.deletion.CASCADE, related_name="items", to="orders.order")),
            ],
        ),
        migrations.AddIndex(
            model_name="order",
            index=models.Index(fields=["status"], name="orders_order_status_77f1e6_idx"),
        ),
        migrations.AddIndex(
            model_name="order",
            index=models.Index(fields=["start_dt"], name="orders_order_start_d_75e6fe_idx"),
        ),
    ]


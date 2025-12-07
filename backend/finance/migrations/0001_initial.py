from __future__ import annotations

from django.conf import settings
from django.db import migrations, models
import django.db.models.deletion


class Migration(migrations.Migration):
    initial = True

    dependencies = [
        ("catalog", "0001_initial"),
        ("orders", "0001_initial"),
        migrations.swappable_dependency(settings.AUTH_USER_MODEL),
    ]

    operations = [
        migrations.CreateModel(
            name="Invoice",
            fields=[
                ("id", models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name="ID")),
                ("created_at", models.DateTimeField(auto_now_add=True)),
                ("updated_at", models.DateTimeField(auto_now=True)),
                ("number", models.CharField(max_length=50, unique=True)),
                ("pdf_url", models.URLField(blank=True)),
                ("status", models.CharField(choices=[("draft", "Draft"), ("sent", "Sent"), ("paid", "Paid"), ("cancelled", "Cancelled")], default="draft", max_length=20)),
                ("issued_at", models.DateTimeField(auto_now_add=True)),
                ("due_date", models.DateTimeField(blank=True, null=True)),
                ("amount", models.DecimalField(decimal_places=2, default=0, max_digits=12)),
                ("currency", models.CharField(default="RUB", max_length=8)),
                ("metadata", models.JSONField(blank=True, default=dict)),
                ("order", models.OneToOneField(on_delete=django.db.models.deletion.CASCADE, related_name="invoice", to="orders.order")),
            ],
        ),
        migrations.CreateModel(
            name="SalaryRecord",
            fields=[
                ("id", models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name="ID")),
                ("created_at", models.DateTimeField(auto_now_add=True)),
                ("updated_at", models.DateTimeField(auto_now=True)),
                ("hours_worked", models.DecimalField(decimal_places=2, default=0, max_digits=8)),
                ("rate_type", models.CharField(choices=[("hourly", "Hourly"), ("fixed", "Fixed"), ("percent", "Percent")], default="fixed", max_length=20)),
                ("rate_value", models.DecimalField(decimal_places=2, default=0, max_digits=12)),
                ("amount", models.DecimalField(decimal_places=2, default=0, max_digits=12)),
                ("status", models.CharField(choices=[("pending", "Pending"), ("approved", "Approved"), ("paid", "Paid")], default="pending", max_length=20)),
                ("paid_at", models.DateTimeField(blank=True, null=True)),
                ("notes", models.TextField(blank=True)),
                ("order", models.ForeignKey(blank=True, null=True, on_delete=django.db.models.deletion.SET_NULL, related_name="salary_records", to="orders.order")),
                ("user", models.ForeignKey(on_delete=django.db.models.deletion.CASCADE, related_name="salary_records", to=settings.AUTH_USER_MODEL)),
            ],
            options={
                "ordering": ["-created_at"],
            },
        ),
        migrations.CreateModel(
            name="Payment",
            fields=[
                ("id", models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name="ID")),
                ("created_at", models.DateTimeField(auto_now_add=True)),
                ("updated_at", models.DateTimeField(auto_now=True)),
                ("method", models.CharField(choices=[("cash", "Cash"), ("bank_transfer", "Bank transfer"), ("online", "Online"), ("other", "Other")], default="bank_transfer", max_length=32)),
                ("status", models.CharField(choices=[("pending", "Pending"), ("success", "Success"), ("failed", "Failed"), ("refunded", "Refunded")], default="pending", max_length=20)),
                ("amount", models.DecimalField(decimal_places=2, max_digits=12)),
                ("currency", models.CharField(default="RUB", max_length=8)),
                ("transaction_id", models.CharField(blank=True, max_length=120)),
                ("paid_at", models.DateTimeField(blank=True, null=True)),
                ("metadata", models.JSONField(blank=True, default=dict)),
                ("invoice", models.ForeignKey(blank=True, null=True, on_delete=django.db.models.deletion.SET_NULL, related_name="payments", to="finance.invoice")),
                ("order", models.ForeignKey(on_delete=django.db.models.deletion.CASCADE, related_name="payments", to="orders.order")),
            ],
            options={
                "ordering": ["-paid_at", "-created_at"],
            },
        ),
        migrations.CreateModel(
            name="Expense",
            fields=[
                ("id", models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name="ID")),
                ("created_at", models.DateTimeField(auto_now_add=True)),
                ("updated_at", models.DateTimeField(auto_now=True)),
                ("category", models.CharField(choices=[("fuel", "Fuel"), ("repair", "Repair"), ("rent", "Equipment rent"), ("other", "Other")], default="other", max_length=50)),
                ("amount", models.DecimalField(decimal_places=2, max_digits=12)),
                ("date", models.DateField()),
                ("comment", models.TextField(blank=True)),
                ("attachment_url", models.URLField(blank=True)),
                ("equipment", models.ForeignKey(blank=True, null=True, on_delete=django.db.models.deletion.SET_NULL, related_name="expenses", to="catalog.equipment")),
                ("order", models.ForeignKey(blank=True, null=True, on_delete=django.db.models.deletion.SET_NULL, related_name="expenses", to="orders.order")),
                ("reported_by", models.ForeignKey(blank=True, null=True, on_delete=django.db.models.deletion.SET_NULL, related_name="reported_expenses", to=settings.AUTH_USER_MODEL)),
            ],
            options={
                "ordering": ["-date"],
            },
        ),
    ]


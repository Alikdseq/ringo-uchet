from __future__ import annotations

from django.db import migrations, models


class Migration(migrations.Migration):
    initial = True

    dependencies = []

    operations = [
        migrations.CreateModel(
            name="ServiceCategory",
            fields=[
                ("id", models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name="ID")),
                ("created_at", models.DateTimeField(auto_now_add=True)),
                ("updated_at", models.DateTimeField(auto_now=True)),
                ("name", models.CharField(max_length=200)),
                ("description", models.TextField(blank=True)),
                ("sort_order", models.PositiveIntegerField(default=0)),
            ],
            options={
                "ordering": ["sort_order", "name"],
            },
        ),
        migrations.CreateModel(
            name="Equipment",
            fields=[
                ("id", models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name="ID")),
                ("created_at", models.DateTimeField(auto_now_add=True)),
                ("updated_at", models.DateTimeField(auto_now=True)),
                ("code", models.CharField(max_length=50, unique=True)),
                ("name", models.CharField(max_length=255)),
                ("description", models.TextField(blank=True)),
                ("hourly_rate", models.DecimalField(decimal_places=2, max_digits=10)),
                ("daily_rate", models.DecimalField(blank=True, decimal_places=2, max_digits=10, null=True)),
                ("fuel_consumption", models.DecimalField(blank=True, decimal_places=2, max_digits=6, null=True)),
                ("status", models.CharField(choices=[("available", "Available"), ("busy", "Busy"), ("maintenance", "Maintenance"), ("inactive", "Inactive")], default="available", max_length=20)),
                ("photos", models.JSONField(blank=True, default=list)),
                ("last_maintenance_date", models.DateField(blank=True, null=True)),
                ("attributes", models.JSONField(blank=True, default=dict)),
            ],
        ),
        migrations.CreateModel(
            name="ServiceItem",
            fields=[
                ("id", models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name="ID")),
                ("created_at", models.DateTimeField(auto_now_add=True)),
                ("updated_at", models.DateTimeField(auto_now=True)),
                ("name", models.CharField(max_length=200)),
                ("unit", models.CharField(default="hour", max_length=32)),
                ("price", models.DecimalField(decimal_places=2, max_digits=10)),
                ("default_duration", models.DecimalField(blank=True, decimal_places=2, max_digits=8, null=True)),
                ("included_items", models.JSONField(blank=True, default=list)),
                ("is_active", models.BooleanField(default=True)),
                ("category", models.ForeignKey(on_delete=models.deletion.CASCADE, related_name="items", to="catalog.servicecategory")),
            ],
            options={
                "ordering": ["name"],
            },
        ),
        migrations.CreateModel(
            name="MaterialItem",
            fields=[
                ("id", models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name="ID")),
                ("created_at", models.DateTimeField(auto_now_add=True)),
                ("updated_at", models.DateTimeField(auto_now=True)),
                ("name", models.CharField(max_length=200)),
                ("unit", models.CharField(default="m3", max_length=32)),
                ("price", models.DecimalField(decimal_places=2, max_digits=10)),
                ("density", models.DecimalField(blank=True, decimal_places=2, max_digits=6, null=True)),
                ("supplier", models.CharField(blank=True, max_length=255)),
                ("is_active", models.BooleanField(default=True)),
            ],
            options={
                "ordering": ["name"],
            },
        ),
        migrations.CreateModel(
            name="MaintenanceRecord",
            fields=[
                ("id", models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name="ID")),
                ("created_at", models.DateTimeField(auto_now_add=True)),
                ("updated_at", models.DateTimeField(auto_now=True)),
                ("performed_at", models.DateField()),
                ("description", models.TextField(blank=True)),
                ("cost", models.DecimalField(blank=True, decimal_places=2, max_digits=10, null=True)),
                ("odometer", models.PositiveIntegerField(blank=True, null=True)),
                ("attachments", models.JSONField(blank=True, default=list)),
                ("equipment", models.ForeignKey(on_delete=models.deletion.CASCADE, related_name="maintenance_records", to="catalog.equipment")),
            ],
            options={
                "ordering": ["-performed_at"],
            },
        ),
        migrations.CreateModel(
            name="Attachment",
            fields=[
                ("id", models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name="ID")),
                ("created_at", models.DateTimeField(auto_now_add=True)),
                ("updated_at", models.DateTimeField(auto_now=True)),
                ("name", models.CharField(max_length=200)),
                ("pricing_modifier", models.DecimalField(decimal_places=2, default=0, help_text="Percentage modifier (e.g. 10 = +10%)", max_digits=6)),
                ("status", models.CharField(choices=[("available", "Available"), ("busy", "Busy"), ("maintenance", "Maintenance"), ("inactive", "Inactive")], default="available", max_length=20)),
                ("metadata", models.JSONField(blank=True, default=dict)),
                ("equipment", models.ForeignKey(on_delete=models.deletion.CASCADE, related_name="attachments", to="catalog.equipment")),
            ],
        ),
    ]


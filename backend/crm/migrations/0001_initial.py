from __future__ import annotations

from django.db import migrations, models


class Migration(migrations.Migration):
    initial = True

    dependencies = []

    operations = [
        migrations.CreateModel(
            name="Client",
            fields=[
                ("id", models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name="ID")),
                ("created_at", models.DateTimeField(auto_now_add=True)),
                ("updated_at", models.DateTimeField(auto_now=True)),
                ("name", models.CharField(max_length=255)),
                ("contact_person", models.CharField(blank=True, max_length=255)),
                ("phone", models.CharField(max_length=32)),
                ("email", models.EmailField(blank=True, max_length=254)),
                ("address", models.CharField(blank=True, max_length=500)),
                ("city", models.CharField(blank=True, max_length=120)),
                ("geo_lat", models.DecimalField(blank=True, decimal_places=6, max_digits=9, null=True)),
                ("geo_lng", models.DecimalField(blank=True, decimal_places=6, max_digits=9, null=True)),
                ("billing_details", models.JSONField(blank=True, default=dict)),
                ("inn", models.CharField(blank=True, max_length=20)),
                ("kpp", models.CharField(blank=True, max_length=20)),
                ("notes", models.TextField(blank=True)),
                ("is_active", models.BooleanField(default=True)),
            ],
            options={
                "ordering": ["name"],
            },
        ),
    ]


from __future__ import annotations

from django.db import migrations, models


class Migration(migrations.Migration):
    dependencies = [
        ("finance", "0002_invoice_payment_status_invoice_pdf_file_and_more"),
    ]

    operations = [
        migrations.CreateModel(
            name="DocumentTemplate",
            fields=[
                ("id", models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name="ID")),
                ("created_at", models.DateTimeField(auto_now_add=True)),
                ("updated_at", models.DateTimeField(auto_now=True)),
                ("slug", models.SlugField(max_length=100)),
                ("version", models.PositiveIntegerField(default=1)),
                (
                    "template_type",
                    models.CharField(
                        choices=[("invoice", "Invoice"), ("act", "Act"), ("receipt", "Receipt")],
                        default="invoice",
                        max_length=20,
                    ),
                ),
                ("template_path", models.CharField(default="invoices/default.html", max_length=255)),
                ("description", models.CharField(blank=True, max_length=255)),
                ("is_active", models.BooleanField(default=True)),
            ],
            options={
                "ordering": ("template_type", "-version"),
            },
        ),
        migrations.AlterUniqueTogether(
            name="documenttemplate",
            unique_together={("slug", "version")},
        ),
    ]


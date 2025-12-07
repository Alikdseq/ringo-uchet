from __future__ import annotations

from django.db import migrations, models


class Migration(migrations.Migration):
    dependencies = [
        ("finance", "0001_initial"),
    ]

    operations = [
        migrations.AddField(
            model_name="invoice",
            name="payment_status",
            field=models.CharField(
                choices=[
                    ("pending", "Pending"),
                    ("success", "Success"),
                    ("failed", "Failed"),
                    ("refunded", "Refunded"),
                ],
                default="pending",
                max_length=20,
            ),
        ),
        migrations.AddField(
            model_name="invoice",
            name="pdf_file",
            field=models.FileField(blank=True, null=True, upload_to="invoices/"),
        ),
        migrations.AlterField(
            model_name="invoice",
            name="number",
            field=models.CharField(blank=True, max_length=50, unique=True),
        ),
        migrations.RemoveField(
            model_name="invoice",
            name="status",
        ),
    ]


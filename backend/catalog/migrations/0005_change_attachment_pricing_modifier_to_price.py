# Generated migration

from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ("catalog", "0004_make_service_price_optional"),
    ]

    operations = [
        migrations.RenameField(
            model_name="attachment",
            old_name="pricing_modifier",
            new_name="price",
        ),
        migrations.AlterField(
            model_name="attachment",
            name="price",
            field=models.DecimalField(
                decimal_places=2,
                default=0,
                help_text="Цена навески в рублях",
                max_digits=10,
                verbose_name="Цена",
            ),
        ),
    ]


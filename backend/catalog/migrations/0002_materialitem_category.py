# Generated manually

from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('catalog', '0001_initial'),
    ]

    operations = [
        migrations.AddField(
            model_name='materialitem',
            name='category',
            field=models.CharField(
                choices=[('soil', 'Грунт'), ('tool', 'Инструмент'), ('other', 'Прочее')],
                default='other',
                help_text='Категория материала',
                max_length=20,
                verbose_name='Категория',
            ),
        ),
    ]


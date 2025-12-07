# Generated manually

from django.db import migrations, models


def update_material_categories(apps, schema_editor):
    """Обновляем категории материалов: убираем 'other', добавляем 'attachment'"""
    MaterialItem = apps.get_model('catalog', 'MaterialItem')
    
    # Переводим все материалы с категорией 'other' в 'soil' (по умолчанию)
    MaterialItem.objects.filter(category='other').update(category='soil')


def reverse_update_material_categories(apps, schema_editor):
    """Откат изменений"""
    MaterialItem = apps.get_model('catalog', 'MaterialItem')
    # При откате переводим обратно в 'other' (если такая категория будет существовать)
    pass


class Migration(migrations.Migration):

    dependencies = [
        ('catalog', '0002_materialitem_category'),
    ]

    operations = [
        # Сначала обновляем данные
        migrations.RunPython(update_material_categories, reverse_update_material_categories),
        
        # Затем изменяем поле категории
        migrations.AlterField(
            model_name='materialitem',
            name='category',
            field=models.CharField(
                choices=[('soil', 'Грунт'), ('tool', 'Инструмент'), ('attachment', 'Навеска')],
                default='soil',
                help_text='Категория материала',
                max_length=20,
                verbose_name='Категория',
            ),
        ),
    ]


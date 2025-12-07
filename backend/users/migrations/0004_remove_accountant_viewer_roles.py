# Generated manually

from django.db import migrations


def migrate_user_roles(apps, schema_editor):
    """Миграция ролей: accountant и viewer -> manager"""
    User = apps.get_model('users', 'User')
    
    # Переводим всех accountant и viewer в manager
    User.objects.filter(role='accountant').update(role='manager')
    User.objects.filter(role='viewer').update(role='manager')


def reverse_migrate_user_roles(apps, schema_editor):
    """Обратная миграция: manager -> accountant (если нужно)"""
    # В обратной миграции не делаем ничего, так как мы не знаем, кто был accountant, а кто manager
    pass


class Migration(migrations.Migration):

    dependencies = [
        ('users', '0002_alter_user_groups'),
    ]

    operations = [
        migrations.RunPython(migrate_user_roles, reverse_migrate_user_roles),
    ]


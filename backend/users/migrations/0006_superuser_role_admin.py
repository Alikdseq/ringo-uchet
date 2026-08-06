from __future__ import annotations

from django.db import migrations


def set_superusers_as_admin(apps, schema_editor):
    User = apps.get_model("users", "User")
    User.objects.filter(is_superuser=True).exclude(role="admin").update(role="admin")


def noop_reverse(apps, schema_editor):
    pass


class Migration(migrations.Migration):
    dependencies = [
        ("users", "0005_alter_user_options_alter_user_avatar_and_more"),
    ]

    operations = [
        migrations.RunPython(set_superusers_as_admin, noop_reverse),
    ]

#!/usr/bin/env python
"""
Скрипт для создания/обновления суперпользователя
"""
import os
import django

os.environ.setdefault("DJANGO_SETTINGS_MODULE", "ringo_backend.settings.local")
django.setup()

from users.models import User

# Создаем или обновляем суперпользователя
username = "admin"
password = "admin123"

try:
    user = User.objects.get(username=username)
    print(f"User {username} already exists. Updating...")
    user.set_password(password)
    user.is_superuser = True
    user.is_staff = True
    user.role = "admin"
    user.save()
    print(f"User {username} updated successfully!")
except User.DoesNotExist:
    user = User.objects.create_superuser(
        username=username,
        email="admin@ringo.local",
        password=password,
        role="admin",
        phone="+79991234567",
        first_name="Admin",
        last_name="User"
    )
    print(f"User {username} created successfully!")

print(f"\nLogin credentials:")
print(f"  Username: {username}")
print(f"  Password: {password}")
print(f"\nAccess admin panel at: http://localhost:8000/admin/")


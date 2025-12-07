#!/usr/bin/env python
"""
Скрипт для создания суперпользователя
Запуск: docker compose exec django-api python create_admin.py
"""
import os
import django

os.environ.setdefault("DJANGO_SETTINGS_MODULE", "ringo_backend.settings.local")
django.setup()

from users.models import User

# Проверяем, существует ли уже админ
if User.objects.filter(phone="+79991234567").exists():
    print("✅ Администратор уже существует!")
    admin = User.objects.get(phone="+79991234567")
    print(f"   Username: {admin.username}")
    print(f"   Email: {admin.email}")
    print(f"   Role: {admin.role}")
else:
    # Создаём суперпользователя
    admin = User.objects.create_superuser(
        username="admin",
        phone="+79991234567",
        email="admin@ringo.local",
        password="admin123",
        role="admin",
        first_name="Admin",
        last_name="User"
    )
    print("✅ Администратор создан!")
    print(f"   Username: {admin.username}")
    print(f"   Phone: {admin.phone}")
    print(f"   Email: {admin.email}")
    print(f"   Password: admin123")
    print(f"   Role: {admin.role}")

print("\n🌐 Войдите в админку: http://localhost:8000/admin/")
print("   Используйте username или phone для входа")


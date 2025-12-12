#!/usr/bin/env python
"""
Скрипт для исправления пользователей в БД:
1. Удалить операторов: Алихан Скяев и Олег Котов
2. Исправить фамилию: Тамик Купенв -> Тамик Купеев
"""
import os
import django

os.environ.setdefault("DJANGO_SETTINGS_MODULE", "ringo_backend.settings.prod")
django.setup()

from users.models import User

print("=" * 60)
print("ИСПРАВЛЕНИЕ ПОЛЬЗОВАТЕЛЕЙ В БД")
print("=" * 60)

# 1. Удалить Алихан Скяев
print("\n1. Поиск и удаление: Алихан Скяев")
users_to_delete = User.objects.filter(first_name__icontains="Алихан", last_name__icontains="Скяев")
if users_to_delete.exists():
    for user in users_to_delete:
        print(f"   Найден: {user.get_full_name()} (ID: {user.id}, Username: {user.username}, Role: {user.role})")
        # Проверяем связанные заявки
        from orders.models import Order
        orders_count = Order.objects.filter(operator=user).count() | Order.objects.filter(operators=user).count()
        if orders_count > 0:
            print(f"   ⚠️  ВНИМАНИЕ: У пользователя есть {orders_count} связанных заявок!")
            print(f"   Удаление пользователя...")
        user.delete()
        print(f"   ✅ Удален: {user.get_full_name()}")
else:
    print("   ❌ Пользователь 'Алихан Скяев' не найден")

# 2. Удалить Олег Котов
print("\n2. Поиск и удаление: Олег Котов")
users_to_delete = User.objects.filter(first_name__icontains="Олег", last_name__icontains="Котов")
if users_to_delete.exists():
    for user in users_to_delete:
        print(f"   Найден: {user.get_full_name()} (ID: {user.id}, Username: {user.username}, Role: {user.role})")
        # Проверяем связанные заявки
        from orders.models import Order
        orders_count = Order.objects.filter(operator=user).count() | Order.objects.filter(operators=user).count()
        if orders_count > 0:
            print(f"   ⚠️  ВНИМАНИЕ: У пользователя есть {orders_count} связанных заявок!")
            print(f"   Удаление пользователя...")
        user.delete()
        print(f"   ✅ Удален: {user.get_full_name()}")
else:
    print("   ❌ Пользователь 'Олег Котов' не найден")

# 3. Исправить фамилию: Тамик Купенв -> Тамик Купеев
print("\n3. Исправление фамилии: Тамик Купенв -> Тамик Купеев")
users_to_fix = User.objects.filter(first_name__icontains="Тамик", last_name__icontains="Купенв")
if users_to_fix.exists():
    for user in users_to_fix:
        print(f"   Найден: {user.get_full_name()} (ID: {user.id}, Username: {user.username})")
        old_name = user.get_full_name()
        user.last_name = "Купеев"
        user.save()
        print(f"   ✅ Исправлено: '{old_name}' -> '{user.get_full_name()}'")
else:
    # Попробуем найти по другой вариации
    users_to_fix = User.objects.filter(first_name__icontains="Тамик")
    if users_to_fix.exists():
        for user in users_to_fix:
            if "Купен" in user.last_name or "Купе" in user.last_name:
                print(f"   Найден: {user.get_full_name()} (ID: {user.id}, Username: {user.username})")
                old_name = user.get_full_name()
                user.last_name = "Купеев"
                user.save()
                print(f"   ✅ Исправлено: '{old_name}' -> '{user.get_full_name()}'")
            else:
                print(f"   ⚠️  Найден пользователь с именем 'Тамик', но фамилия не содержит 'Купенв': {user.get_full_name()}")
    else:
        print("   ❌ Пользователь 'Тамик Купенв' не найден")

print("\n" + "=" * 60)
print("✅ ОПЕРАЦИИ ЗАВЕРШЕНЫ")
print("=" * 60)


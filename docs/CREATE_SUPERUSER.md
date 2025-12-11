# ✅ СОЗДАНИЕ СУПЕРПОЛЬЗОВАТЕЛЯ (АДМИНИСТРАТОРА)

## 🎯 ЦЕЛЬ

**Создать суперпользователя с ролью ADMIN для доступа к админке Django.**

---

## ✅ ШАГ 1: Создать администратора через Python

**На сервере:**

```bash
cd /root/ringo-uchet/backend

docker compose -f docker-compose.prod.yml exec -T api python -c "
import os
import django
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'ringo_backend.settings.prod')
django.setup()

from users.models import User, UserRole

# Создать суперпользователя
admin, created = User.objects.get_or_create(
    phone='79187020987',  # ЗАМЕНИТЕ НА ВАШ ТЕЛЕФОН!
    defaults={
        'email': 'admin@ringoouchet.ru',
        'first_name': 'Администратор',
        'last_name': 'Системы',
        'role': UserRole.ADMIN,
        'is_active': True,
        'is_staff': True,
        'is_superuser': True,
    }
)

admin.set_password('alik123')  # ЗАМЕНИТЕ НА ВАШ ПАРОЛЬ!
admin.is_staff = True
admin.is_superuser = True
admin.role = UserRole.ADMIN
admin.save()

if created:
    print(f'✅ Создан суперпользователь: {admin.phone}')
else:
    print(f'✅ Обновлен до суперпользователя: {admin.phone}')

print(f'   Email: {admin.email}')
print(f'   Роль: {admin.role}')
print(f'   is_staff: {admin.is_staff}')
print(f'   is_superuser: {admin.is_superuser}')

print('\n=== Все пользователи ===')
for u in User.objects.all():
    print(f'- Телефон: {u.phone or \"НЕТ\"}, Email: {u.email}, Роль: {u.role}, Staff: {u.is_staff}, Superuser: {u.is_superuser}')
"
```

**ЗАМЕНИТЕ:**
- `79187020987` на ваш телефон (или другой)
- `alik123` на ваш пароль

---

## ✅ ШАГ 2: Проверить создание

**На сервере:**

```bash
cd /root/ringo-uchet/backend

docker compose -f docker-compose.prod.yml exec -T api python manage.py shell << 'PYTHON'
from users.models import User

print("=== Суперпользователи ===")
for u in User.objects.filter(is_superuser=True):
    print(f"- {u.phone or u.email} - Роль: {u.role} - Staff: {u.is_staff} - Superuser: {u.is_superuser}")

print("\n=== Все пользователи ===")
for u in User.objects.all():
    print(f"- {u.phone or 'НЕТ'} ({u.email}) - Роль: {u.role}, Staff: {u.is_staff}, Superuser: {u.is_superuser}")
PYTHON
```

---

## ✅ ШАГ 3: Вход в админку

**Откройте в браузере:**
- `https://ringoouchet.ru/admin/`

**Войдите с:**
- Телефон (или email): ваш телефон
- Пароль: ваш пароль

---

**Выполните ШАГ 1 и пришлите результат!**


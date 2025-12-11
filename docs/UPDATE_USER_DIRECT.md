# ✅ ОБНОВЛЕНИЕ ПОЛЬЗОВАТЕЛЯ: Прямое выполнение

## ✅ СПОСОБ 1: Выполнить Python код напрямую

**На сервере:**

```bash
cd /root/ringo-uchet/backend

docker compose -f docker-compose.prod.yml exec -T api python -c "
import os
import django
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'ringo_backend.settings.prod')
django.setup()

from users.models import User

user = User.objects.filter(email='alikhan2102@mail.eu').first()

if user:
    user.phone = '79187020987'
    user.set_password('alik123')
    user.save()
    print(f'✅ Обновлен: Телефон: {user.phone}, Email: {user.email}, Роль: {user.role}')
else:
    print('❌ Пользователь не найден')

print('\n=== Все пользователи ===')
for u in User.objects.all():
    print(f'- Телефон: {u.phone or \"НЕТ\"}, Email: {u.email}, Роль: {u.role}')
"
```

---

## ✅ СПОСОБ 2: Через manage.py shell

**На сервере:**

```bash
cd /root/ringo-uchet/backend

docker compose -f docker-compose.prod.yml exec -T api python manage.py shell << 'PYTHON'
from users.models import User

user = User.objects.filter(email='alikhan2102@mail.eu').first()

if user:
    user.phone = '79187020987'
    user.set_password('alik123')
    user.save()
    print(f'✅ Обновлен: Телефон: {user.phone}, Email: {user.email}, Роль: {user.role}')
else:
    print('❌ Пользователь не найден')

print('\n=== Все пользователи ===')
for u in User.objects.all():
    print(f'- Телефон: {u.phone or "НЕТ"}, Email: {u.email}, Роль: {u.role}')
PYTHON
```

---

**Выполните один из способов!**


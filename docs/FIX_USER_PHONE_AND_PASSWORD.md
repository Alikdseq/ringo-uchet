# ✅ ИСПРАВЛЕНИЕ: Пользователь без телефона

## ❌ ПРОБЛЕМА

**В базе есть пользователь, но:**
- ❌ Телефон: `None`
- ✅ Email: `alikhan2102@mail.eu`
- ✅ Роль: `manager`

**Проблема:** Вход идет по телефону, а телефона нет!

---

## ✅ ШАГ 1: Обновить пользователя - добавить телефон и пароль

**На сервере:**

```bash
cd /root/ringo-uchet/backend

# Создать скрипт
cat > /tmp/update_user.py << 'PYTHON'
import os
import django
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'ringo_backend.settings.prod')
django.setup()

from users.models import User

# Найти пользователя по email
user = User.objects.filter(email='alikhan2102@mail.eu').first()

if user:
    # Установить телефон
    user.phone = '79991234567'  # ЗАМЕНИТЕ НА ВАШ РЕАЛЬНЫЙ ТЕЛЕФОН!
    # Установить пароль
    user.set_password('admin123')  # ЗАМЕНИТЕ НА ВАШ ПАРОЛЬ!
    user.save()
    print(f"✅ Обновлен пользователь:")
    print(f"   Телефон: {user.phone}")
    print(f"   Email: {user.email}")
    print(f"   Роль: {user.role}")
else:
    print("❌ Пользователь не найден")

# Показать всех пользователей
print("\n=== Все пользователи ===")
for u in User.objects.all():
    print(f"- Телефон: {u.phone or 'НЕТ'}, Email: {u.email}, Роль: {u.role}")
PYTHON

# Запустить
docker compose -f docker-compose.prod.yml exec -T api python /tmp/update_user.py
```

**ВАЖНО: ЗАМЕНИТЕ:**
- `79991234567` на ваш реальный телефон
- `admin123` на ваш реальный пароль

---

## ✅ ШАГ 2: Или создать нового пользователя с телефоном

**На сервере:**

```bash
cd /root/ringo-uchet/backend

# Создать скрипт для нового пользователя
cat > /tmp/create_user.py << 'PYTHON'
import os
import django
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'ringo_backend.settings.prod')
django.setup()

from users.models import User, UserRole

# Создать нового пользователя с телефоном
user, created = User.objects.get_or_create(
    phone='79991234567',  # ЗАМЕНИТЕ НА ВАШ ТЕЛЕФОН!
    defaults={
        'email': 'alikhan2102@mail.eu',
        'first_name': 'Admin',
        'last_name': 'User',
        'role': UserRole.ADMIN,
        'is_active': True,
        'is_staff': True,
        'is_superuser': True,
    }
)

user.set_password('admin123')  # ЗАМЕНИТЕ НА ВАШ ПАРОЛЬ!
user.save()

if created:
    print(f"✅ Создан новый пользователь: {user.phone}")
else:
    print(f"✅ Обновлен пользователь: {user.phone}")

print(f"\n=== Все пользователи ===")
for u in User.objects.all():
    print(f"- Телефон: {u.phone or 'НЕТ'}, Email: {u.email}, Роль: {u.role}")
PYTHON

# Запустить
docker compose -f docker-compose.prod.yml exec -T api python /tmp/create_user.py
```

---

## ✅ ШАГ 3: Тест логина

**После обновления:**

```bash
curl -k -X POST https://ringoouchet.ru/api/v1/token/ \
  -H "Content-Type: application/json" \
  -d '{"phone":"ВАШ_ТЕЛЕФОН","password":"ВАШ_ПАРОЛЬ"}' \
  2>&1 | grep -E "token|error|detail|access"
```

**Должно вернуть токены!**

---

**Выполните ШАГ 1 или ШАГ 2 и пришлите результат!**


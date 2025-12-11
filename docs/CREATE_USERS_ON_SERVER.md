# ✅ СОЗДАНИЕ ПОЛЬЗОВАТЕЛЕЙ НА СЕРВЕРЕ

## 🎯 ПРОБЛЕМА

**На сервере БД пустая - нет пользователей!**

---

## ✅ ШАГ 1: Проверить пользователей на сервере

**На сервере:**

```bash
cd /root/ringo-uchet/backend

# Проверить пользователей (без TTY)
docker compose -f docker-compose.prod.yml exec -T api python manage.py shell << 'PYTHON'
from users.models import User
users = User.objects.all()
print(f"Всего пользователей: {users.count()}")
for user in users:
    print(f"- Телефон: {user.phone}, Email: {user.email or 'нет'}, Роль: {user.role}, Активен: {user.is_active}")
PYTHON
```

**Пришлите вывод!**

---

## ✅ ШАГ 2: Создать администратора

**На сервере:**

```bash
cd /root/ringo-uchet/backend

# Создать суперпользователя
docker compose -f docker-compose.prod.yml exec -T api python manage.py createsuperuser
```

**Введите:**
- Телефон (например: `79991234567`)
- Email (опционально)
- Пароль (дважды)

---

## ✅ ШАГ 3: Или создать пользователя через скрипт

**На сервере:**

```bash
cd /root/ringo-uchet/backend

# Создать скрипт
cat > /tmp/create_user.py << 'PYTHON'
import os
import django
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'ringo_backend.settings.prod')
django.setup()

from users.models import User, UserRole

# Создать администратора
admin, created = User.objects.get_or_create(
    phone='79991234567',  # ЗАМЕНИТЕ НА ВАШ ТЕЛЕФОН
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

if created:
    admin.set_password('admin123')  # ЗАМЕНИТЕ НА ВАШ ПАРОЛЬ
    admin.save()
    print(f"✅ Создан администратор: {admin.phone}")
else:
    print(f"ℹ️ Администратор уже существует: {admin.phone}")
    admin.set_password('admin123')  # Обновить пароль
    admin.save()
    print(f"✅ Пароль обновлен")

# Создать оператора (пример)
operator, created = User.objects.get_or_create(
    phone='79991234568',  # ЗАМЕНИТЕ НА ТЕЛЕФОН ОПЕРАТОРА
    defaults={
        'email': 'operator@ringoouchet.ru',
        'first_name': 'Оператор',
        'last_name': 'Тестовый',
        'role': UserRole.OPERATOR,
        'is_active': True,
    }
)

if created:
    operator.set_password('operator123')  # ЗАМЕНИТЕ НА ПАРОЛЬ
    operator.save()
    print(f"✅ Создан оператор: {operator.phone}")
else:
    print(f"ℹ️ Оператор уже существует: {operator.phone}")

# Показать всех пользователей
print("\n=== Все пользователи ===")
for user in User.objects.all():
    print(f"- {user.phone} ({user.role}) - Активен: {user.is_active}")
PYTHON

# Запустить скрипт
docker compose -f docker-compose.prod.yml exec -T api python /tmp/create_user.py
```

**ЗАМЕНИТЕ:**
- `79991234567` на ваш реальный телефон
- `admin123` на ваш реальный пароль
- `79991234568` на телефон оператора (если нужно)

---

## ✅ ШАГ 4: Проверить что пользователи созданы

**На сервере:**

```bash
cd /root/ringo-uchet/backend

docker compose -f docker-compose.prod.yml exec -T api python manage.py shell << 'PYTHON'
from users.models import User
users = User.objects.all()
print(f"Всего пользователей: {users.count()}")
for user in users:
    print(f"- Телефон: {user.phone}, Роль: {user.role}, Активен: {user.is_active}")
PYTHON
```

---

## ✅ ШАГ 5: Тест логина

**На сервере:**

```bash
curl -k -X POST https://ringoouchet.ru/api/v1/token/ \
  -H "Content-Type: application/json" \
  -H "Origin: https://ringoouchet.ru" \
  -d '{"phone":"79991234567","password":"admin123"}' \
  2>&1 | grep -E "< HTTP|token|error|detail|access"
```

**Должно вернуть токены!**

---

**Выполните ШАГИ 1-5!**


# ✅ ИСПРАВЛЕНИЕ: Логин возвращает 500 вместо 401

## ✅ ЧТО ИСПРАВЛЕНО

1. **Обработка ошибок в `CustomTokenObtainPairView`** - теперь ValidationError возвращает 401 ✅
2. **CORS_ALLOW_ALL_ORIGINS=true** - включено ✅

---

## ✅ ШАГ 1: Загрузить исправленный код на сервер

**На вашем компьютере:**

```powershell
# Если используете git
cd C:\ringo-uchet
git add backend/users/views.py
git commit -m "Fix: Return 401 instead of 500 for invalid credentials"
git push

# Или просто скопировать файл на сервер
scp backend/users/views.py root@91.229.90.72:/root/ringo-uchet/backend/users/views.py
```

**На сервере:**

```bash
cd /root/ringo-uchet/backend

# Если используете git
git pull

# Или убедиться что файл обновлен
cat users/views.py | grep -A 5 "ValidationError"
```

---

## ✅ ШАГ 2: Пересобрать Docker образ (если нужно)

**На сервере:**

```bash
cd /root/ringo-uchet/backend

# Проверить как собирается образ
cat Dockerfile | head -10

# Если используется Dockerfile, пересобрать:
docker compose -f docker-compose.prod.yml build api

# Перезапустить
docker compose -f docker-compose.prod.yml up -d api

# Подождать
sleep 5
```

**Или если код монтируется как volume:**

```bash
# Просто перезапустить
docker compose -f docker-compose.prod.yml restart api
```

---

## ✅ ШАГ 3: Проверить пользователей в базе

**На сервере:**

```bash
cd /root/ringo-uchet/backend

docker compose -f docker-compose.prod.yml exec api python manage.py shell << 'PYTHON'
from users.models import User
users = User.objects.all()
print(f"Всего пользователей: {users.count()}")
for user in users:
    print(f"- Телефон: {user.phone}, Email: {user.email or 'нет'}, Роль: {user.role}, Активен: {user.is_active}")
PYTHON
```

**Пришлите вывод!**

---

## ✅ ШАГ 4: Тест логина

**На сервере:**

```bash
# С правильными данными
curl -k -X POST https://ringoouchet.ru/api/v1/token/ \
  -H "Content-Type: application/json" \
  -H "Origin: https://ringoouchet.ru" \
  -d '{"phone":"89187020987","password":"alik123"}' \
  -v 2>&1 | grep -E "< HTTP|token|error|detail|access"
```

**Должно быть:**
- 200 OK с токенами (если данные верные)
- 401 Unauthorized (если данные неверные) ✅

---

**Выполните ШАГИ 1-4!**


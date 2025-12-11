# 🔧 ИСПРАВЛЕНИЕ: API не отвечает на curl внутри контейнера

## ✅ ЧТО РАБОТАЕТ
- Контейнеры запущены
- Логи в порядке  
- Контейнер API запущен

## ❌ ПРОБЛЕМА
`curl http://localhost:8000/api/health/` не возвращает ответ

---

## 🔍 ПРИЧИНЫ И РЕШЕНИЯ

### Причина 1: curl не установлен в контейнере

**Проверка:**
```bash
docker compose -f docker-compose.prod.yml exec api which curl
```

**Если не найден, установите:**
```bash
docker compose -f docker-compose.prod.yml exec api apt-get update
docker compose -f docker-compose.prod.yml exec api apt-get install -y curl
```

---

### Причина 2: API не запустился внутри контейнера

**Проверка процессов:**
```bash
docker compose -f docker-compose.prod.yml exec api ps aux | grep gunicorn
```

**Должен показать процесс gunicorn**

---

### Причина 3: Порт 8000 не слушается

**Проверка:**
```bash
docker compose -f docker-compose.prod.yml exec api netstat -tulpn | grep 8000
# или
docker compose -f docker-compose.prod.yml exec api ss -tulpn | grep 8000
```

---

### Причина 4: Health endpoint не существует

**Проверка напрямую через Python:**
```bash
docker compose -f docker-compose.prod.yml exec api python manage.py shell
```

**В Python shell:**
```python
from django.test import Client
client = Client()
response = client.get('/api/health/')
print(response.status_code)
print(response.content)
exit()
```

---

## 🚀 БЫСТРОЕ РЕШЕНИЕ

### Вариант 1: Использовать Python requests вместо curl

```bash
docker compose -f docker-compose.prod.yml exec api python -c "import requests; print(requests.get('http://localhost:8000/api/health/').text)"
```

### Вариант 2: Проверить снаружи контейнера

```bash
curl http://localhost:8001/api/health/
```

**Если это работает, значит API работает, просто curl не установлен в контейнере**

---

## ✅ ПРОВЕРКА СНАРУЖИ

**Самый важный тест - проверить API снаружи:**

```bash
curl http://127.0.0.1:8001/api/health/
# или с вашего IP
curl http://ВАШ_IP:8001/api/health/
```

**Если это работает - значит всё ОК! API доступен на порту 8001**

---

## 📝 ВАЖНО

**curl внутри контейнера может не работать, но это НЕ значит, что API не работает!**

**Главное - проверить снаружи контейнера на порту 8001.**


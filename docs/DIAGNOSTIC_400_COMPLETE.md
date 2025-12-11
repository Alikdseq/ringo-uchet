# 🔍 ПОЛНАЯ ДИАГНОСТИКА: 400 Bad Request

## 🎯 ЦЕЛЬ
Найти корень проблемы с помощью комплексной проверки.

---

## 📋 ДИАГНОСТИКА - ВЫПОЛНЯЙТЕ ПО ПОРЯДКУ

### ПРОВЕРКА 1: Какой docker-compose файл используется

```bash
cd ~/ringo-uchet/backend
ls -la docker-compose*.yml
docker compose -f docker-compose.prod.yml ps
```

**Запишите результат!**

---

### ПРОВЕРКА 2: Содержимое .env файла

```bash
cd ~/ringo-uchet/backend
cat .env | grep -E "ALLOWED|DJANGO_ALLOWED|CSRF"
```

**Покажите результат!**

---

### ПРОВЕРКА 3: Переменные окружения в контейнере

```bash
docker compose -f docker-compose.prod.yml exec api env | grep -E "ALLOWED|DJANGO_ALLOWED|CSRF|SETTINGS"
```

**Что показывает? Запишите!**

---

### ПРОВЕРКА 4: Логи API контейнера (последние ошибки)

```bash
docker compose -f docker-compose.prod.yml logs api | grep -i "error\|allowed\|disallowed" | tail -20
```

**Покажите все ошибки!**

---

### ПРОВЕРКА 5: Проверка настроек Django в контейнере

```bash
docker compose -f docker-compose.prod.yml exec api python manage.py shell -c "from django.conf import settings; print('ALLOWED_HOSTS:', settings.ALLOWED_HOSTS)"
```

**Покажет, что видит Django!**

---

### ПРОВЕРКА 6: Какой docker-compose файл реально используется

```bash
cd ~/ringo-uchet/backend
cat docker-compose.prod.yml | grep -A 5 "api:" | head -10
```

**Покажет конфигурацию API сервиса.**

---

### ПРОВЕРКА 7: Проверка Nginx проксирования

```bash
curl -v -H "Host: ringoouchet.ru" http://127.0.0.1:8001/api/health/
```

**Проверка напрямую к API без Nginx.**

---

## ✅ ВЫПОЛНИТЕ ВСЕ ПРОВЕРКИ

**Скопируйте результаты всех 7 проверок и отправьте мне - я найду проблему!**


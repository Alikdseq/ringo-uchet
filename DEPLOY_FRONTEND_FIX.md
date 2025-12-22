# 🚀 Деплой исправления TypeScript на production (ringoouchet.ru)

## ✅ Что исправлено
Исправлена ошибка TypeScript в `frontend/src/app/(app)/orders/[orderId]/page.tsx` - переменная `order` использовалась до объявления.

---

## 📋 Команды для деплоя

### Вариант 1: Если фронтенд в том же docker-compose на сервере

**На вашем компьютере (PowerShell):**
```powershell
# 1. Подключиться к серверу
ssh root@91.229.90.72
```

**На сервере:**
```bash
# 2. Перейти в корень проекта
cd ~/ringo-uchet

# 3. Обновить код из репозитория
git pull origin master

# 4. Пересобрать только frontend
docker compose -f docker-compose.prod.yml build --no-cache frontend

# 5. Перезапустить frontend
docker compose -f docker-compose.prod.yml up -d frontend

# 6. Проверить логи
docker compose -f docker-compose.prod.yml logs frontend --tail 50

# 7. Проверить статус
docker compose -f docker-compose.prod.yml ps frontend
```

---

### Вариант 2: Если фронтенд деплоится отдельно (Vercel/Netlify/etc)

**На вашем компьютере:**
```powershell
# 1. Закоммитить исправление
git add frontend/src/app/(app)/orders/[orderId]/page.tsx
git commit -m "Fix: исправлена ошибка TypeScript - переменная order использовалась до объявления"
git push origin master

# 2. Если используется CI/CD - он автоматически задеплоит
# Если нет - выполните команды из Варианта 1 на сервере
```

---

### Вариант 3: Быстрая команда (все одной строкой)

**На сервере (после SSH подключения):**
```bash
cd ~/ringo-uchet && git pull origin master && docker compose -f docker-compose.prod.yml build --no-cache frontend && docker compose -f docker-compose.prod.yml up -d frontend && sleep 10 && docker compose -f docker-compose.prod.yml logs frontend --tail 30
```

---

## 🔍 Проверка после деплоя

1. **Откройте сайт:** https://ringoouchet.ru
2. **Откройте DevTools (F12)** → вкладка **Console**
3. **Проверьте:** не должно быть ошибок компиляции TypeScript
4. **Перейдите на страницу заявки:** например `/orders/[любой-id]`
5. **Убедитесь:** страница загружается без ошибок

---

## ⚠️ Если что-то пошло не так

### Проверить логи frontend:
```bash
docker compose -f docker-compose.prod.yml logs frontend --tail 100
```

### Перезапустить frontend:
```bash
docker compose -f docker-compose.prod.yml restart frontend
```

### Если сборка падает с ошибкой:
```bash
# Проверить, что файл исправлен
cat ~/ringo-uchet/frontend/src/app/\(app\)/orders/\[orderId\]/page.tsx | grep -A 5 "isOrderOperator"

# Должно показать код после useQuery, а не до
```

---

## 📝 Минимальный набор команд (скопировать и выполнить)

```bash
ssh root@91.229.90.72
cd ~/ringo-uchet
git pull origin master
docker compose -f docker-compose.prod.yml build --no-cache frontend
docker compose -f docker-compose.prod.yml up -d frontend
exit
```

**Время выполнения:** 5-10 минут


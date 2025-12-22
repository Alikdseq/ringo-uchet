# Быстрый деплой исправления на production

## Если деплой через Docker на сервере

### Вариант 1: SSH на сервер и пересборка

```bash
# 1. Подключиться к серверу
ssh user@ringoouchet.ru

# 2. Перейти в папку проекта
cd /path/to/ringo-uchet

# 3. Остановить frontend
docker-compose stop frontend

# 4. Пересобрать frontend с исправлением
docker-compose build --no-cache frontend

# 5. Запустить frontend
docker-compose up -d frontend

# 6. Проверить логи
docker-compose logs -f frontend
```

### Вариант 2: Локально собрать и задеплоить

```bash
# На вашем локальном компьютере:

# 1. Перейти в папку проекта
cd C:\ringo-uchet

# 2. Пересобрать frontend локально (для проверки)
docker-compose build --no-cache frontend

# 3. Если сборка успешна, закоммитить изменения
git add frontend/src/app/(app)/orders/[orderId]/page.tsx
git commit -m "Fix: исправлена ошибка TypeScript - переменная order использовалась до объявления"

# 4. Запушить на сервер
git push

# 5. На сервере (через SSH):
ssh user@ringoouchet.ru
cd /path/to/ringo-uchet
git pull
docker-compose build --no-cache frontend
docker-compose up -d frontend
```

## Если деплой через CI/CD (GitHub Actions / GitLab CI)

```bash
# 1. Закоммитить исправление
git add frontend/src/app/(app)/orders/[orderId]/page.tsx
git commit -m "Fix: исправлена ошибка TypeScript в OrderDetailPage"

# 2. Запушить в репозиторий
git push origin main  # или master, или ваша ветка

# CI/CD автоматически соберет и задеплоит
```

## Если деплой вручную через файлы

```bash
# 1. Локально собрать проект
cd C:\ringo-uchet\frontend
npm install
npm run build

# 2. Скопировать исправленный файл на сервер
scp frontend/src/app/(app)/orders/[orderId]/page.tsx user@ringoouchet.ru:/path/to/project/frontend/src/app/(app)/orders/[orderId]/

# 3. На сервере пересобрать
ssh user@ringoouchet.ru
cd /path/to/project/frontend
npm run build
# или если через Docker:
cd /path/to/project
docker-compose restart frontend
```

## Быстрая проверка после деплоя

1. Откройте `https://ringoouchet.ru` в браузере
2. Откройте DevTools (F12) → Console
3. Проверьте, что нет ошибок TypeScript/компиляции
4. Перейдите на страницу заявки (например `/orders/[какой-то-id]`)
5. Убедитесь, что страница загружается без ошибок

## Минимальный набор команд (если уже знаете путь к проекту на сервере)

```bash
ssh user@ringoouchet.ru "cd /path/to/ringo-uchet && docker-compose build --no-cache frontend && docker-compose up -d frontend"
```

---

**Важно:** Замените `user@ringoouchet.ru` и `/path/to/ringo-uchet` на ваши реальные данные для доступа к серверу.


# ✅ ИСПРАВЛЕНИЕ: Контейнер не читает .env файл

## ❌ ПРОБЛЕМА НАЙДЕНА!

**В контейнере:**
```
DJANGO_ALLOWED_HOSTS=91.229.90.72,localhost,127.0.0.1
CORS_ALLOWED_ORIGINS=http://91.229.90.72,https://ваш-домен.ru
```

**В .env файле:**
```
DJANGO_ALLOWED_HOSTS=ringoouchet.ru,www.ringoouchet.ru,91.229.90.72
```

**Контейнер НЕ видит обновленный .env файл!**

---

## ✅ РЕШЕНИЕ

### ШАГ 1: Проверить и исправить .env (убрать плейсхолдер)

```bash
cd ~/ringo-uchet/backend
nano .env
```

**Найдите строку с `ваш-домен.ru` и замените на `ringoouchet.ru`:**

**Если есть:**
```env
CORS_ALLOWED_ORIGINS=http://91.229.90.72,https://ваш-домен.ru
```

**Замените на:**
```env
CORS_ALLOWED_ORIGINS=http://ringoouchet.ru,http://www.ringoouchet.ru,http://91.229.90.72
```

**Сохраните:** `Ctrl + O`, `Enter`, `Ctrl + X`

---

### ШАГ 2: Полностью пересоздать контейнеры

**Остановить и удалить контейнеры:**

```bash
cd ~/ringo-uchet/backend
docker compose -f docker-compose.prod.yml down
```

**Запустить заново:**

```bash
docker compose -f docker-compose.prod.yml up -d --build
```

**Подождите 30 секунд для полного запуска.**

---

### ШАГ 3: Проверить переменные в контейнере

```bash
docker compose -f docker-compose.prod.yml exec api env | grep -E "DJANGO_ALLOWED|CORS_ALLOWED"
```

**Должно показать:**
```
DJANGO_ALLOWED_HOSTS=ringoouchet.ru,www.ringoouchet.ru,91.229.90.72
CORS_ALLOWED_ORIGINS=http://ringoouchet.ru,http://www.ringoouchet.ru,http://91.229.90.72
```

---

### ШАГ 4: Проверка API

```bash
curl http://ringoouchet.ru/api/health/
```

**Должен вернуть JSON или 200, но НЕ 400!**

---

## ✅ ВЫПОЛНИТЕ ЭТИ ШАГИ

**После выполнения напишите результат!**


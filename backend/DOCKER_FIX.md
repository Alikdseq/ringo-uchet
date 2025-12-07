# Исправление ошибок сборки Docker для Debian Trixie

## Проблема
В Debian Trixie (новая версия Debian) пакеты `libgdk-pixbuf2.0-0` и `libgdk-pixbuf2.0-dev` были заменены на:
- `libgdk-pixbuf-xlib-2.0-0`
- `libgdk-pixbuf-xlib-2.0-dev`

## Решение
Dockerfile обновлен с правильными пакетами для Debian Trixie.

## Пересборка образов

### Вариант 1: Пересборка без кэша (рекомендуется)
```bash
cd backend
docker compose build --no-cache
```

### Вариант 2: Пересборка с очисткой кэша
```bash
cd backend
docker compose down
docker system prune -f
docker compose build
```

### Вариант 3: Пересборка из корня проекта
```bash
docker compose build --no-cache
```

## Проверка
После успешной сборки запустите контейнеры:
```bash
docker compose up -d
```

## Примечания
- Если используете старую версию Debian (Bookworm или старше), можно вернуть старые пакеты
- Для совместимости с разными версиями Debian можно использовать условную установку пакетов в Dockerfile


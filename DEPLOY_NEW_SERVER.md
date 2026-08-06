# Деплой на новый сервер ringoouchet.ru (89.169.38.5)

## 1. DNS в Beget

```
ringoouchet.ru      A    89.169.38.5
www.ringoouchet.ru  A    89.169.38.5
```

Почтовые MX/TXT/CNAME для Beget — не трогать.

Проверка:
```bash
nslookup ringoouchet.ru
# Address: 89.169.38.5
```

---

## 2. Подготовка сервера (Ubuntu)

```bash
ssh root@89.169.38.5

apt update && apt upgrade -y
apt install -y git docker.io docker-compose-plugin

systemctl enable docker
systemctl start docker

mkdir -p /opt/ringo-uchet
cd /opt/ringo-uchet
```

Скопируйте проект на сервер (git clone или scp):
```bash
git clone <ваш-репозиторий> /opt/ringo-uchet
cd /opt/ringo-uchet
```

---

## 3. Секреты

```bash
cp .env.prod.example .env.prod
nano .env.prod
```

Обязательно смените:
- `DJANGO_SECRET_KEY`
- `POSTGRES_PASSWORD` (один пароль для Postgres и Django)
- `MINIO_ROOT_PASSWORD` / `AWS_SECRET_ACCESS_KEY`

В `.env.prod` должен быть **только** `POSTGRES_PASSWORD` (не разные `DB_PASSWORD` и `POSTGRES_PASSWORD`).

---

## 3.1. Если ошибка: password authentication failed

### Корень (исправлено в коде)
Старый Windows-хак выставлял `PGPASSWORD=''` и URL-кодировал пароль (`!!` → `%21%21`).
На Linux libpq/psycopg2 из‑за этого слал **неверный** пароль, хотя в `env` был правильный `POSTGRES_PASSWORD`.

### На сервере после `git pull`

1. В `.env.prod` используйте пароль **без** `! # $ \`` (или в кавычках).
2. Имена переменных Django: `DJANGO_SECRET_KEY`, `DJANGO_ALLOWED_HOSTS` (не `SECRET_KEY` / `ALLOWED_HOSTS`).
3. Сбросьте volume БД (если данных ещё нет) и пересоберите:

```bash
cd /opt/ringo-uchet
git pull
# отредактируйте .env.prod — POSTGRES_PASSWORD без спецсимволов
docker compose -f docker-compose.prod.yml --env-file .env.prod down -v
docker compose -f docker-compose.prod.yml --env-file .env.prod up -d --build
docker compose -f docker-compose.prod.yml --env-file .env.prod logs -f django-api
```

Проверка подключения:
```bash
docker compose -f docker-compose.prod.yml --env-file .env.prod run --rm --entrypoint python django-api -c "
import os, django
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'ringo_backend.settings.prod')
django.setup()
from django.db import connection
connection.ensure_connection()
print('DB OK', connection.settings_dict['USER'], connection.settings_dict['HOST'])
"
```

---

## 4. Первый запуск (HTTP, до SSL)

```bash
chmod +x scripts/deploy-prod.sh
./scripts/deploy-prod.sh
```

Или вручную:
```bash
export NGINX_CONF=prod-init.conf
docker compose -f docker-compose.prod.yml --env-file .env.prod up -d --build
```

Проверка:
```bash
curl http://89.169.38.5/api/health/
curl http://ringoouchet.ru/api/health/
```

---

## 5. SSL (Let's Encrypt)

Когда DNS уже указывает на `89.169.38.5`:

```bash
docker compose -f docker-compose.prod.yml --env-file .env.prod \
  --profile ssl run --rm certbot
```

Переключить nginx на HTTPS:
```bash
export NGINX_CONF=prod.conf
docker compose -f docker-compose.prod.yml --env-file .env.prod up -d nginx
```

Проверка:
```bash
curl https://ringoouchet.ru/api/health/
```

Автообновление сертификата (cron, раз в сутки):
```bash
0 3 * * * cd /opt/ringo-uchet && docker compose -f docker-compose.prod.yml --env-file .env.prod --profile ssl run --rm certbot renew && NGINX_CONF=prod.conf docker compose -f docker-compose.prod.yml --env-file .env.prod up -d nginx
```

---

## 6. Создание администратора

```bash
docker compose -f docker-compose.prod.yml --env-file .env.prod \
  exec django-api python manage.py createsuperuser
```

---

## 7. Обновление после изменений в коде

```bash
cd /opt/ringo-uchet
git pull
docker compose -f docker-compose.prod.yml --env-file .env.prod up -d --build
```

Только frontend:
```bash
docker compose -f docker-compose.prod.yml --env-file .env.prod up -d --build frontend nginx
```

---

## Структура production

| Сервис | Назначение |
|--------|------------|
| `nginx` | 80/443, прокси на frontend + API |
| `frontend` | Next.js |
| `django-api` | Django + Gunicorn |
| `celery` / `celery-beat` | Фоновые задачи |
| `db` | PostgreSQL |
| `redis` | Кэш / Celery |
| `minio` | Файлы (только localhost:9000) |

---

## Файлы конфигурации

| Файл | Назначение |
|------|------------|
| `.env.prod` | Секреты и домен (не в git) |
| `docker-compose.prod.yml` | Полный prod-стек |
| `infra/nginx/prod-init.conf` | HTTP до SSL |
| `infra/nginx/prod.conf` | HTTPS после certbot |

---

## Локальная разработка

Локально по-прежнему:
```bash
docker compose up -d
# http://localhost
```

Production-конфиги на localhost не влияют.

# EMERGENCY RUNBOOK

Краткое руководство для экстренных ситуаций. В стрессовой ситуации память подводит.

## 📍 Где лежат бэкапы

**PostgreSQL бэкапы:**
- S3 bucket: `ringo-backups-production` (или `ringo-backups-staging`)
- Путь: `s3://ringo-backups/postgres/full/`
- Формат: `ringo_YYYYMMDD_HHMMSS.sql.gz`
- Частота: Ежедневно в 02:00 UTC

**WAL архивы:**
- S3 bucket: `ringo-backups-production`
- Путь: `s3://ringo-backups/postgres/wal/`
- Хранятся последние 7 дней

**Медиафайлы:**
- S3 bucket: `ringo-media-production` (или `ringo-media-staging`)
- Путь: `s3://ringo-media/media/`
- Версионирование: **Включено** (можно восстановить любую версию)

## 🔄 Команда восстановления БД

```bash
# 1. Скачать последний бэкап
aws s3 cp s3://ringo-backups/postgres/full/latest.sql.gz /tmp/restore.sql.gz

# Или конкретный бэкап
aws s3 cp s3://ringo-backups/postgres/full/ringo_20240115_020000.sql.gz /tmp/restore.sql.gz

# 2. Восстановить
./infra/backup/scripts/restore-postgres.sh /tmp/restore.sql.gz ringo

# 3. Проверить
psql -h $DB_HOST -U $DB_USER -d ringo -c "SELECT COUNT(*) FROM orders;"
```

## 📞 Контакты поддержки хостинга

**DigitalOcean:**
- Support Portal: https://cloud.digitalocean.com/support
- Email: support@digitalocean.com
- Phone: +1 (646) 513-5095
- Status Page: https://status.digitalocean.com/

**AWS:**
- Support Center: https://console.aws.amazon.com/support/
- Support Email: support@amazonaws.com
- Status Page: https://status.aws.amazon.com/

**Критический инцидент:**
- Открыть тикет с приоритетом "Critical" или "Urgent"
- Указать: "Production outage" или "Data loss"

## 🚀 Команда перезапуска сервисов

**Локально (Docker Compose):**
```bash
cd /path/to/ringo-uchet
docker compose restart django-api celery celery-beat
docker compose restart db redis  # если нужно
```

**Production (через SSH):**
```bash
# Перезапуск всех сервисов
ssh $PROD_HOST "cd /opt/ringo && docker compose restart"

# Или через systemd
ssh $PROD_HOST "systemctl restart ringo-api ringo-celery ringo-celery-beat"

# Проверка статуса
ssh $PROD_HOST "systemctl status ringo-api"
```

**Rollback к предыдущей версии:**
```bash
ssh $PROD_HOST "cd /opt/ringo && git checkout HEAD~1 && docker compose up -d --build"
```

## 🔍 Быстрая диагностика

**Проверка здоровья API:**
```bash
curl http://localhost:8001/api/health/
# или
curl https://api.ringo.example.com/api/health/
```

**Проверка подключения к БД:**
```bash
docker compose exec db psql -U ringo -d ringo -c "SELECT 1;"
```

**Проверка логов:**
```bash
docker compose logs django-api --tail 50
docker compose logs celery --tail 50
```

## ⚠️ Критические команды

**Остановить запись данных (при потере данных):**
```bash
docker compose stop django-api celery-worker
```

**Восстановить файл из S3 версии:**
```bash
# Список версий
aws s3api list-object-versions --bucket ringo-media --prefix media/orders/123/photo.jpg

# Восстановить конкретную версию
aws s3api get-object \
  --bucket ringo-media \
  --key media/orders/123/photo.jpg \
  --version-id VERSION_ID \
  restored-photo.jpg
```

## 📋 Контакты команды

**DevOps Lead:** [ЗАПОЛНИТЬ]
- Email: devops@ringo.example.com
- Phone: +7 XXX XXX-XX-XX

**Tech Lead:** [ЗАПОЛНИТЬ]
- Email: tech@ringo.example.com
- Phone: +7 XXX XXX-XX-XX

**On-Call:** [ЗАПОЛНИТЬ]
- Telegram: @ringo_oncall
- Slack: #ringo-alerts-critical

---

**Важно:** Этот файл должен быть доступен офлайн. Распечатайте или сохраните локально.


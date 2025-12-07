# Runbooks для аварийных ситуаций

Документация по действиям в аварийных ситуациях для Ringo Uchet.

## Контакты и эскалация

### Критические контакты

**DevOps Team:**
- Lead DevOps: [ИМЯ] - [ТЕЛЕФОН] - [EMAIL]
- Backup DevOps: [ИМЯ] - [ТЕЛЕФОН] - [EMAIL]

**Development Team:**
- Tech Lead: [ИМЯ] - [ТЕЛЕФОН] - [EMAIL]
- Backend Lead: [ИМЯ] - [ТЕЛЕФОН] - [EMAIL]

**Infrastructure Provider:**
- DigitalOcean Support: https://www.digitalocean.com/support
- AWS Support: https://aws.amazon.com/support/

**SLA и RTO/RPO:**
- **RTO (Recovery Time Objective)**: 4 часа
- **RPO (Recovery Point Objective)**: 24 часа (для критических данных - 1 час)
- **MTTR (Mean Time To Recovery)**: 2 часа

## Аварийные сценарии

### 1. Недоступность базы данных

**Симптомы:**
- API возвращает 500 ошибки
- Логи показывают ошибки подключения к БД
- Prometheus алерт: `DatabaseDown`

**Действия:**

1. **Проверка статуса БД:**
   ```bash
   # Проверка подключения
   psql -h $DB_HOST -p $DB_PORT -U $DB_USER -d $DB_NAME -c "SELECT 1;"
   
   # Проверка статуса через health check
   curl http://api:8000/api/health/
   ```

2. **Проверка логов:**
   ```bash
   docker logs postgres-backup
   docker logs django-api | grep -i database
   ```

3. **Перезапуск БД (если это не поможет, переходим к восстановлению):**
   ```bash
   docker-compose restart db
   # Или для production
   ssh $PROD_HOST "systemctl restart postgresql"
   ```

4. **Восстановление из бэкапа (если БД повреждена):**
   ```bash
   # Скачать последний бэкап из S3
   aws s3 cp s3://ringo-backups/postgres/full/latest.sql.gz /tmp/backup.sql.gz
   
   # Восстановить
   ./infra/backup/scripts/restore-postgres.sh /tmp/backup.sql.gz ringo
   ```

5. **Эскалация:**
   - Если восстановление не удалось → связаться с DevOps Lead
   - Если данные критически важны → связаться с Tech Lead

**Время восстановления:** 30 минут - 2 часа

---

### 2. Потеря данных в базе данных

**Симптомы:**
- Данные отсутствуют или повреждены
- Пользователи сообщают о пропавших заявках/данных
- Аудит логи показывают удаление данных

**Действия:**

1. **Остановить запись данных (если возможно):**
   ```bash
   # Перевести API в режим только чтения
   # Или остановить сервисы записи
   docker-compose stop django-api celery-worker
   ```

2. **Определить время потери данных:**
   ```bash
   # Проверить последний успешный бэкап
   aws s3 ls s3://ringo-backups/postgres/full/ --recursive | tail -5
   
   # Проверить WAL архивы
   ls -lah /backups/postgres/wal/
   ```

3. **Восстановление из бэкапа:**
   ```bash
   # Найти нужный бэкап (ближайший к времени до потери данных)
   BACKUP_FILE=$(aws s3 ls s3://ringo-backups/postgres/full/ | grep "2024-01-15" | tail -1 | awk '{print $4}')
   
   # Скачать и восстановить
   aws s3 cp s3://ringo-backups/postgres/full/$BACKUP_FILE /tmp/restore.sql.gz
   ./infra/backup/scripts/restore-postgres.sh /tmp/restore.sql.gz ringo
   ```

4. **Point-in-Time Recovery (если используется WAL):**
   ```bash
   # Восстановление до конкретного времени
   # Требует настройки PITR (Point-In-Time Recovery)
   # См. документацию PostgreSQL
   ```

5. **Восстановление из S3 версий (для медиафайлов):**
   ```bash
   # Восстановить конкретную версию файла
   aws s3api list-object-versions --bucket ringo-media --prefix media/orders/123/photo.jpg
   aws s3api get-object --bucket ringo-media --key media/orders/123/photo.jpg --version-id VERSION_ID restored.jpg
   ```

6. **Эскалация:**
   - Немедленно связаться с Tech Lead
   - Уведомить заказчика о потере данных (если RPO превышен)

**Время восстановления:** 1-4 часа (зависит от размера БД)

---

### 3. Недоступность API сервера

**Симптомы:**
- Все запросы к API возвращают ошибки
- Load balancer показывает unhealthy
- Prometheus алерт: `APIDown`

**Действия:**

1. **Проверка статуса серверов:**
   ```bash
   # Проверить статус через load balancer
   curl https://api.ringo.example.com/api/health/
   
   # Проверить статус каждого инстанса
   for host in api1 api2; do
     ssh $host "curl http://localhost:8000/api/health/"
   done
   ```

2. **Проверка логов:**
   ```bash
   # Логи API
   docker logs django-api --tail 100
   # Или для production
   ssh $PROD_HOST "journalctl -u ringo-api -n 100"
   ```

3. **Перезапуск сервисов:**
   ```bash
   # Локально
   docker-compose restart django-api
   
   # Production
   ssh $PROD_HOST "systemctl restart ringo-api"
   ```

4. **Масштабирование (если нагрузка высокая):**
   ```bash
   # Увеличить количество инстансов через Terraform
   cd infra/terraform
   terraform apply -var="api_instance_count=4"
   ```

5. **Rollback к предыдущей версии:**
   ```bash
   # Откатить Docker образ
   ssh $PROD_HOST "cd /opt/ringo && docker-compose pull && docker-compose up -d"
   ```

6. **Эскалация:**
   - Если проблема не решается за 15 минут → связаться с DevOps Lead
   - Если критично → связаться с Tech Lead

**Время восстановления:** 5-30 минут

---

### 4. Переполнение диска

**Симптомы:**
- Ошибки записи в БД/файлы
- Prometheus алерт: `CriticalDiskUsage`
- Логи показывают "No space left on device"

**Действия:**

1. **Проверка использования диска:**
   ```bash
   df -h
   du -sh /var/lib/postgresql/data/*
   du -sh /backups/postgres/*
   ```

2. **Очистка старых бэкапов:**
   ```bash
   # Удалить локальные бэкапы старше 7 дней
   find /backups/postgres -name "*.sql.gz" -mtime +7 -delete
   
   # Проверить S3 lifecycle policy (должна работать автоматически)
   ```

3. **Очистка старых WAL файлов:**
   ```bash
   # Удалить старые WAL архивы (если они уже в S3)
   find /backups/postgres/wal -name "*.wal" -mtime +7 -delete
   ```

4. **Очистка Docker:**
   ```bash
   docker system prune -a --volumes
   ```

5. **Очистка логов:**
   ```bash
   # Очистить старые логи
   journalctl --vacuum-time=7d
   ```

6. **Увеличение диска (если нужно):**
   ```bash
   # Через Terraform увеличить размер диска
   cd infra/terraform
   terraform apply -var="api_instance_size=s-4vcpu-8gb"
   ```

**Время восстановления:** 15-60 минут

---

### 5. Утечка секретов/компрометация

**Симптомы:**
- Подозрительная активность в логах
- Неожиданные изменения данных
- Алерты безопасности

**Действия:**

1. **Немедленно ротировать все секреты:**
   ```bash
   # Ротация Django SECRET_KEY
   ./infra/secrets/scripts/rotate-secrets.sh production
   
   # Ротация через GitHub Secrets
   gh secret set PROD_DJANGO_SECRET_KEY --body "$(openssl rand -hex 32)"
   ```

2. **Отозвать скомпрометированные ключи:**
   ```bash
   # Отозвать AWS ключи
   aws iam delete-access-key --access-key-id COMPROMISED_KEY
   
   # Отозвать JWT токены (через blacklist)
   # Django автоматически обработает через token_blacklist
   ```

3. **Проверить логи доступа:**
   ```bash
   # Проверить подозрительную активность
   grep "suspicious_ip" /var/log/nginx/access.log
   grep "unauthorized" /var/log/django-api.log
   ```

4. **Блокировать подозрительные IP:**
   ```bash
   # Добавить в firewall
   ufw deny from SUSPICIOUS_IP
   ```

5. **Уведомить команду:**
   - Немедленно связаться с Tech Lead и DevOps Lead
   - Уведомить заказчика (если затронуты пользовательские данные)

**Время восстановления:** 1-4 часа

---

### 6. Потеря S3 данных

**Симптомы:**
- Файлы недоступны
- Ошибки при загрузке/скачивании
- Версионирование показывает удаление

**Действия:**

1. **Проверить статус S3:**
   ```bash
   aws s3 ls s3://ringo-media/
   aws s3api get-bucket-versioning --bucket ringo-media
   ```

2. **Восстановить из версий:**
   ```bash
   # Список версий файла
   aws s3api list-object-versions --bucket ringo-media --prefix media/orders/123/
   
   # Восстановить конкретную версию
   aws s3api get-object --bucket ringo-media \
     --key media/orders/123/photo.jpg \
     --version-id VERSION_ID \
     restored-photo.jpg
   ```

3. **Восстановить из Glacier (если файлы архивированы):**
   ```bash
   # Запросить восстановление
   aws s3api restore-object \
     --bucket ringo-media \
     --key media/orders/123/photo.jpg \
     --version-id VERSION_ID \
     --restore-request '{"Days":7,"GlacierJobParameters":{"Tier":"Expedited"}}'
   ```

4. **Проверить lifecycle policy:**
   ```bash
   aws s3api get-bucket-lifecycle-configuration --bucket ringo-media
   ```

**Время восстановления:** 1-24 часа (зависит от размера и типа архива)

---

## Процедуры восстановления

### Восстановление из полного бэкапа

```bash
# 1. Остановить приложение
docker-compose stop django-api celery-worker

# 2. Скачать бэкап
aws s3 cp s3://ringo-backups/postgres/full/ringo_20240115_020000.sql.gz /tmp/restore.sql.gz

# 3. Восстановить
./infra/backup/scripts/restore-postgres.sh /tmp/restore.sql.gz ringo

# 4. Запустить приложение
docker-compose start django-api celery-worker

# 5. Проверить
curl http://localhost:8000/api/health/
```

### Тестирование восстановления

```bash
# Еженедельный тест восстановления
./infra/backup/scripts/test-restore.sh latest
```

### Point-in-Time Recovery (PITR)

Требует настройки continuous archiving и WAL архивирования. См. документацию PostgreSQL.

## Мониторинг и алерты

### Критические метрики

- Database connections > 95%
- Disk usage > 95%
- API latency > 1s
- Error rate > 10%
- Backup failures

### Каналы уведомлений

- Slack: `#ringo-alerts-critical`
- Telegram: группа DevOps
- Email: oncall@ringo.example.com

## Плановое обслуживание

### Ежедневные задачи

- Проверка успешности бэкапов
- Проверка алертов
- Мониторинг использования ресурсов

### Еженедельные задачи

- Тест восстановления из бэкапа
- Проверка retention policy
- Анализ логов безопасности

### Ежемесячные задачи

- Disaster recovery drill
- Обзор и обновление runbooks
- Проверка RTO/RPO метрик

## Дополнительные ресурсы

- [PostgreSQL Backup Documentation](https://www.postgresql.org/docs/current/backup.html)
- [AWS S3 Versioning](https://docs.aws.amazon.com/AmazonS3/latest/userguide/Versioning.html)
- [DigitalOcean Backup Guide](https://www.digitalocean.com/community/tutorials/how-to-back-up-restore-and-migrate-postgresql-databases)


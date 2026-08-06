# Быстрый деплой на production — см. DEPLOY_NEW_SERVER.md

**Сервер:** `89.169.38.5`  
**Домен:** `https://ringoouchet.ru`

```bash
ssh root@89.169.38.5
cd /opt/ringo-uchet
cp .env.prod.example .env.prod   # заполнить секреты
./scripts/deploy-prod.sh
```

Полная инструкция: [DEPLOY_NEW_SERVER.md](./DEPLOY_NEW_SERVER.md)

---

## Быстрое обновление frontend

```bash
ssh root@89.169.38.5 "cd /opt/ringo-uchet && git pull && docker compose -f docker-compose.prod.yml --env-file .env.prod up -d --build frontend nginx"
```

## Проверка

1. `https://ringoouchet.ru`
2. `https://ringoouchet.ru/api/health/`
3. Вход в систему, открытие заявки


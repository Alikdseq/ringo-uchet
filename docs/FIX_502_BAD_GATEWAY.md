# 🔧 ИСПРАВЛЕНИЕ ОШИБКИ 502 BAD GATEWAY

## 🔴 ПРОБЛЕМА

**Ошибка:** `GET https://ringoouchet.ru/api/v1/orders/ 502 (Bad Gateway)`

**Причина:** Nginx не может подключиться к backend API серверу.

---

## 🔍 ДИАГНОСТИКА

### ШАГ 1: Проверить статус контейнеров

**На сервере:**

```bash
cd ~/ringo-uchet/backend
docker compose -f docker-compose.prod.yml ps
```

**Что должно быть:**
- `backend-api-1` - статус `Up`
- `backend-db-1` - статус `Up (healthy)`
- `backend-redis-1` - статус `Up (healthy)`

**Если контейнеры не запущены:**
```bash
docker compose -f docker-compose.prod.yml up -d
sleep 15
docker compose -f docker-compose.prod.yml ps
```

---

### ШАГ 2: Проверить логи API контейнера

**На сервере:**

```bash
cd ~/ringo-uchet/backend
docker compose -f docker-compose.prod.yml logs api --tail 50
```

**Что искать:**
- Ошибки запуска
- Проблемы с подключением к БД
- Ошибки импорта модулей

---

### ШАГ 3: Проверить что API отвечает локально

**На сервере:**

```bash
# Проверить health endpoint
curl http://localhost:8001/api/health/

# Должен вернуть: {"status": "ok"}

# Если не работает, проверить порт
netstat -tulpn | grep 8001

# Или проверить через Docker
docker compose -f docker-compose.prod.yml exec api curl http://localhost:8000/api/health/
```

---

### ШАГ 4: Проверить конфигурацию Nginx

**На сервере:**

```bash
# Проверить конфигурацию Nginx
sudo nginx -t

# Посмотреть конфигурацию для API
sudo cat /etc/nginx/sites-available/ringoouchet.ru
# Или
sudo cat /etc/nginx/conf.d/default.conf
```

**Что должно быть в конфигурации:**

```nginx
location /api/ {
    proxy_pass http://localhost:8001;
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
}
```

---

### ШАГ 5: Проверить логи Nginx

**На сервере:**

```bash
# Проверить ошибки Nginx
sudo tail -50 /var/log/nginx/error.log

# Проверить access логи
sudo tail -50 /var/log/nginx/access.log | grep api
```

---

## 🔧 РЕШЕНИЕ ПРОБЛЕМЫ

### РЕШЕНИЕ 1: Перезапустить контейнеры

**На сервере:**

```bash
cd ~/ringo-uchet/backend

# Остановить все контейнеры
docker compose -f docker-compose.prod.yml down

# Запустить заново
docker compose -f docker-compose.prod.yml up -d

# Подождать запуска
sleep 20

# Проверить статус
docker compose -f docker-compose.prod.yml ps

# Проверить что API работает
curl http://localhost:8001/api/health/
```

---

### РЕШЕНИЕ 2: Проверить что порт 8001 открыт

**На сервере:**

```bash
# Проверить что порт слушается
netstat -tulpn | grep 8001

# Должно быть что-то вроде:
# tcp  0  0  0.0.0.0:8001  0.0.0.0:*  LISTEN  <PID>/docker-proxy

# Если порт не слушается, проверить docker-compose.prod.yml
cd ~/ringo-uchet/backend
cat docker-compose.prod.yml | grep -A 5 "ports:"
```

**Должно быть:**
```yaml
ports:
  - "8001:8000"
```

---

### РЕШЕНИЕ 3: Исправить конфигурацию Nginx

**На сервере:**

```bash
# Найти конфигурационный файл
sudo find /etc/nginx -name "*.conf" -type f | xargs grep -l "ringoouchet.ru"

# Отредактировать конфигурацию
sudo nano /etc/nginx/sites-available/ringoouchet.ru
# Или
sudo nano /etc/nginx/conf.d/default.conf
```

**Убедитесь что есть правильная секция для API:**

```nginx
server {
    listen 80;
    listen [::]:80;
    server_name ringoouchet.ru www.ringoouchet.ru;

    # Редирект на HTTPS
    return 301 https://$server_name$request_uri;
}

server {
    listen 443 ssl http2;
    listen [::]:443 ssl http2;
    server_name ringoouchet.ru www.ringoouchet.ru;

    # SSL сертификаты
    ssl_certificate /etc/letsencrypt/live/ringoouchet.ru/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/ringoouchet.ru/privkey.pem;

    # Статические файлы фронтенда
    root /var/www/ringo-uchet;
    index index.html;

    # API проксирование
    location /api/ {
        proxy_pass http://127.0.0.1:8001;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_cache_bypass $http_upgrade;
        proxy_read_timeout 300s;
        proxy_connect_timeout 75s;
    }

    # Статические файлы фронтенда
    location / {
        try_files $uri $uri/ /index.html;
    }
}
```

**После редактирования:**

```bash
# Проверить конфигурацию
sudo nginx -t

# Если все ОК, перезагрузить
sudo systemctl reload nginx
```

---

### РЕШЕНИЕ 4: Проверить что контейнер API запущен и здоров

**На сервере:**

```bash
cd ~/ringo-uchet/backend

# Проверить статус
docker compose -f docker-compose.prod.yml ps api

# Проверить логи
docker compose -f docker-compose.prod.yml logs api --tail 100

# Проверить healthcheck
docker compose -f docker-compose.prod.yml exec api curl -f http://localhost:8000/api/health/
```

**Если контейнер не запускается:**

```bash
# Посмотреть детальные логи
docker compose -f docker-compose.prod.yml logs api

# Попробовать запустить вручную
docker compose -f docker-compose.prod.yml up api
```

---

### РЕШЕНИЕ 5: Проверить подключение к БД

**На сервере:**

```bash
cd ~/ringo-uchet/backend

# Проверить что БД работает
docker compose -f docker-compose.prod.yml exec db psql -U ringo_user -d ringo_prod -c "SELECT version();"

# Проверить подключение из API контейнера
docker compose -f docker-compose.prod.yml exec api python manage.py dbshell
```

**Если БД не работает:**

```bash
# Перезапустить БД
docker compose -f docker-compose.prod.yml restart db

# Подождать
sleep 10

# Проверить статус
docker compose -f docker-compose.prod.yml ps db
```

---

## 🚀 БЫСТРОЕ ИСПРАВЛЕНИЕ (ВСЕ СРАЗУ)

**На сервере выполните все команды подряд:**

```bash
cd ~/ringo-uchet/backend && \
docker compose -f docker-compose.prod.yml ps && \
docker compose -f docker-compose.prod.yml restart api && \
sleep 15 && \
curl http://localhost:8001/api/health/ && \
sudo nginx -t && \
sudo systemctl reload nginx && \
echo "✅ Проверка завершена"
```

---

## ✅ ПРОВЕРКА ПОСЛЕ ИСПРАВЛЕНИЯ

### ШАГ 1: Проверить что API работает локально

**На сервере:**

```bash
curl http://localhost:8001/api/health/
```

Должен вернуть: `{"status": "ok"}`

### ШАГ 2: Проверить что API работает через Nginx

**На сервере:**

```bash
curl https://ringoouchet.ru/api/health/
```

Должен вернуть: `{"status": "ok"}`

### ШАГ 3: Проверить в браузере

**На вашем компьютере:**

1. Откройте `https://ringoouchet.ru`
2. Откройте DevTools (F12)
3. Перейдите на вкладку Network
4. Попробуйте выполнить действие, которое вызывает запрос к API
5. Проверьте что запросы возвращают 200 OK вместо 502

---

## 🔍 ДОПОЛНИТЕЛЬНАЯ ДИАГНОСТИКА

### Если ничего не помогло:

**На сервере:**

```bash
# 1. Проверить все контейнеры
cd ~/ringo-uchet/backend
docker compose -f docker-compose.prod.yml ps -a

# 2. Проверить логи всех сервисов
docker compose -f docker-compose.prod.yml logs --tail 50

# 3. Проверить сеть Docker
docker network ls
docker network inspect ringo-uchet_backend_ringo-net

# 4. Проверить что порты открыты
ss -tulpn | grep -E "8001|8000"

# 5. Проверить firewall
sudo iptables -L -n | grep 8001
sudo ufw status
```

---

## 📋 ЧЕКЛИСТ ИСПРАВЛЕНИЯ

- [ ] Контейнеры запущены (`docker compose ps`)
- [ ] API отвечает локально (`curl http://localhost:8001/api/health/`)
- [ ] Порт 8001 слушается (`netstat -tulpn | grep 8001`)
- [ ] Nginx конфигурация правильная (`sudo nginx -t`)
- [ ] Nginx перезагружен (`sudo systemctl reload nginx`)
- [ ] API работает через Nginx (`curl https://ringoouchet.ru/api/health/`)
- [ ] Нет ошибок в логах (`docker compose logs api`)

---

**Начните с ШАГА 1 - проверьте статус контейнеров!** 🚀


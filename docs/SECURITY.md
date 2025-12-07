# Руководство по безопасности Ringo Uchet

Комплексная документация по безопасности проекта.

## 1. HTTPS (Let's Encrypt / ACM), HSTS, TLS 1.2+

### Настройка Let's Encrypt

**Автоматическая настройка через Certbot:**

```bash
# Установка сертификата
./infra/security/certbot-setup.sh api.ringo.example.com admin@ringo.example.com

# Автоматическое обновление настроено через systemd timer
systemctl status certbot.timer
```

**Ручная настройка:**

```bash
certbot certonly --nginx -d api.ringo.example.com --email admin@ringo.example.com
```

### Настройка Nginx

Конфигурация находится в `infra/nginx/nginx-ssl.conf`:

- **TLS версии**: TLSv1.2 и TLSv1.3
- **Cipher suites**: Современные, безопасные шифры
- **HSTS**: Включен с `max-age=31536000; includeSubDomains; preload`
- **Дополнительные заголовки безопасности**: X-Frame-Options, X-Content-Type-Options, CSP

### Использование ACM (AWS Certificate Manager)

Если используется AWS Load Balancer:

1. Создайте сертификат в ACM
2. Привяжите к Load Balancer
3. SSL termination происходит на LB
4. Nginx получает трафик по HTTP от LB

### Проверка SSL

```bash
# Проверка сертификата
openssl s_client -connect api.ringo.example.com:443 -servername api.ringo.example.com

# Проверка через SSL Labs
# https://www.ssllabs.com/ssltest/analyze.html?d=api.ringo.example.com
```

## 2. WAF/Firewall правила, IP allowlist для admin endpoints

### Firewall (UFW)

**Настройка:**

```bash
./infra/security/firewall-rules.sh
```

**Правила:**
- SSH (22) - разрешен
- HTTP (80) - разрешен
- HTTPS (443) - разрешен
- PostgreSQL (5432) - только внутренняя сеть (10.0.0.0/8)
- Redis (6379) - только внутренняя сеть (10.0.0.0/8)
- Все остальные порты - заблокированы

### IP Allowlist для Admin

**Настройка через переменные окружения:**

```env
ADMIN_ALLOWED_IPS=127.0.0.1,10.0.0.0/8,YOUR_OFFICE_IP,YOUR_VPN_IP
```

**Поддерживаемые форматы:**
- Одиночные IP: `192.168.1.1`
- CIDR нотация: `10.0.0.0/8`
- Несколько адресов через запятую

**Nginx конфигурация:**

В `infra/nginx/nginx-ssl.conf` настроен блок для `/admin/`:

```nginx
location /admin/ {
    allow 127.0.0.1;
    allow 10.0.0.0/8;
    deny all;
    ...
}
```

### Rate Limiting

**Nginx rate limiting:**

```nginx
limit_req_zone $binary_remote_addr zone=api_limit:10m rate=10r/s;
limit_req_zone $binary_remote_addr zone=login_limit:10m rate=5r/m;
```

**Защита от ботов:**

Блокируются подозрительные User-Agent:
- curl без User-Agent
- wget
- python requests без User-Agent
- сканеры

## 3. Pen-test чеклист: OWASP API, SQLi, XSS, auth bypass, SSRF

### OWASP API Top 10

#### API1:2019 Broken Object Level Authorization

**Защита:**
- ✅ Проверка прав доступа на уровне объекта
- ✅ Использование Django permissions
- ✅ Проверка в views через `has_object_permission`

**Тестирование:**
```bash
# Попытка доступа к чужому объекту
curl -H "Authorization: Bearer $TOKEN" https://api.ringo.example.com/api/v1/orders/123/
# Должен вернуть 403 если order не принадлежит пользователю
```

#### API2:2019 Broken Authentication

**Защита:**
- ✅ JWT токены с коротким временем жизни (15 минут)
- ✅ Refresh token rotation
- ✅ Token blacklist
- ✅ Rate limiting на `/api/token/` endpoint

**Тестирование:**
```bash
# Брутфорс атака на логин
for i in {1..100}; do
  curl -X POST https://api.ringo.example.com/api/v1/token/ \
    -d "phone=+79991234567&password=wrong"
done
# Должен быть заблокирован после нескольких попыток
```

#### API3:2019 Excessive Data Exposure

**Защита:**
- ✅ Сериализаторы показывают только необходимые поля
- ✅ PII данные не возвращаются в API ответах
- ✅ Фильтрация чувствительных данных в логах

**Тестирование:**
```bash
# Проверка, что пароли не возвращаются
curl -H "Authorization: Bearer $TOKEN" https://api.ringo.example.com/api/v1/users/me/
# Должен вернуть данные без password поля
```

#### API4:2019 Lack of Resources & Rate Limiting

**Защита:**
- ✅ Rate limiting на уровне Nginx
- ✅ Rate limiting на уровне Django (DRF throttling)
- ✅ Ограничение размера запросов (50MB)

**Тестирование:**
```bash
# Отправка большого запроса
dd if=/dev/zero bs=100M count=1 | curl -X POST \
  https://api.ringo.example.com/api/v1/orders/ \
  -H "Authorization: Bearer $TOKEN" \
  --data-binary @-
# Должен быть отклонен
```

#### API5:2019 Broken Function Level Authorization

**Защита:**
- ✅ Проверка ролей через декораторы `@role_required`
- ✅ Проверка permissions в views
- ✅ Admin endpoints защищены IP allowlist

**Тестирование:**
```bash
# Попытка доступа к admin endpoint без прав
curl -H "Authorization: Bearer $OPERATOR_TOKEN" \
  https://api.ringo.example.com/api/v1/reports/summary/
# Должен вернуть 403
```

#### API6:2019 Mass Assignment

**Защита:**
- ✅ Использование сериализаторов с явным указанием полей
- ✅ Запрет на изменение критичных полей через API

**Тестирование:**
```bash
# Попытка изменить role через API
curl -X PATCH https://api.ringo.example.com/api/v1/users/123/ \
  -H "Authorization: Bearer $TOKEN" \
  -d '{"role": "admin"}'
# Должен игнорировать поле role
```

#### API7:2019 Security Misconfiguration

**Защита:**
- ✅ DEBUG=False в production
- ✅ ALLOWED_HOSTS настроен правильно
- ✅ CORS настроен правильно
- ✅ Security headers настроены

**Тестирование:**
```bash
# Проверка security headers
curl -I https://api.ringo.example.com/api/v1/
# Должны присутствовать: Strict-Transport-Security, X-Frame-Options, etc.
```

#### API8:2019 Injection

**Защита:**
- ✅ SQL Injection: Django ORM (защита от SQLi)
- ✅ XSS: Middleware для проверки входных данных
- ✅ Command Injection: Валидация входных данных

**Тестирование:**
```bash
# SQL Injection попытка
curl "https://api.ringo.example.com/api/v1/orders/?search=' OR '1'='1"
# Должен быть заблокирован middleware

# XSS попытка
curl "https://api.ringo.example.com/api/v1/orders/?search=<script>alert(1)</script>"
# Должен быть заблокирован middleware
```

#### API9:2019 Improper Assets Management

**Защита:**
- ✅ Версионирование API через `/api/v1/`
- ✅ Документация API актуальна
- ✅ Устаревшие версии отключены

#### API10:2019 Insufficient Logging & Monitoring

**Защита:**
- ✅ Audit logging всех критичных действий
- ✅ Security logging подозрительной активности
- ✅ Мониторинг через Prometheus и Sentry
- ✅ Алерты на подозрительную активность

### SQL Injection

**Защита:**
- ✅ Django ORM (автоматическая защита)
- ✅ Middleware для обнаружения SQLi попыток
- ✅ Параметризованные запросы

**Тестирование:**
```bash
# Попытки SQL injection
curl "https://api.ringo.example.com/api/v1/orders/?id=1' OR '1'='1"
curl "https://api.ringo.example.com/api/v1/orders/?id=1; DROP TABLE orders;"
# Должны логироваться как подозрительные
```

### XSS (Cross-Site Scripting)

**Защита:**
- ✅ Middleware для проверки входных данных
- ✅ Content-Security-Policy header
- ✅ X-XSS-Protection header
- ✅ Валидация и санитизация данных

**Тестирование:**
```bash
# Попытки XSS
curl "https://api.ringo.example.com/api/v1/orders/?search=<script>alert(1)</script>"
curl "https://api.ringo.example.com/api/v1/orders/?search=javascript:alert(1)"
# Должны быть заблокированы
```

### Authentication Bypass

**Защита:**
- ✅ JWT токены с подписью
- ✅ Проверка токенов на каждом запросе
- ✅ Token blacklist для отозванных токенов
- ✅ Rate limiting на endpoints аутентификации

**Тестирование:**
```bash
# Попытка подделки токена
curl -H "Authorization: Bearer fake_token" \
  https://api.ringo.example.com/api/v1/orders/
# Должен вернуть 401

# Попытка доступа без токена
curl https://api.ringo.example.com/api/v1/orders/
# Должен вернуть 401
```

### SSRF (Server-Side Request Forgery)

**Защита:**
- ✅ Middleware для проверки URL параметров
- ✅ Блокировка доступа к внутренним IP адресам
- ✅ Валидация URL перед запросами

**Тестирование:**
```bash
# Попытки SSRF
curl "https://api.ringo.example.com/api/v1/webhook/?url=http://127.0.0.1:5432"
curl "https://api.ringo.example.com/api/v1/webhook/?url=http://169.254.169.254/latest/meta-data/"
# Должны быть заблокированы
```

## 4. Data Privacy: PII encryption, log scrubbing, retention 90 дней

### PII Encryption

**Шифрование чувствительных данных:**

Используется модуль `backend/audit/encryption.py`:

```python
from audit.encryption import encrypt_field, decrypt_field

# Шифрование
encrypted_value = encrypt_field("sensitive_data")

# Расшифровка
decrypted_value = decrypt_field(encrypted_value)
```

**Настройка:**

```env
ENCRYPTION_KEY=your-32-byte-base64-key
```

### Log Scrubbing

**Автоматическая очистка PII из логов:**

Middleware `PIIScrubbingMiddleware` автоматически удаляет:
- Email адреса
- Телефонные номера
- Кредитные карты
- SSN
- Пароли и токены

**Поля, которые очищаются:**
- password
- token
- secret
- api_key
- credit_card
- phone
- email

**Пример:**

До очистки:
```
User logged in: john@example.com, phone: +79991234567
```

После очистки:
```
User logged in: [EMAIL_REDACTED], phone: [PHONE_REDACTED]
```

### Log Retention (90 дней)

**Настройка через Vector:**

В `infra/monitoring/vector/vector.yml`:

```yaml
sinks:
  opensearch:
    index: ringo-logs-%Y.%m.%d
    # Retention через index lifecycle management
```

**Настройка через OpenSearch:**

```json
{
  "policy": {
    "phases": {
      "delete": {
        "min_age": "90d"
      }
    }
  }
}
```

**Проверка:**

```bash
# Проверить старые индексы
curl http://localhost:9200/_cat/indices/ringo-logs-*?v

# Удалить старые индексы вручную (если нужно)
curl -X DELETE http://localhost:9200/ringo-logs-2024-01-01
```

## Чеклист безопасности

### Перед production деплоем

- [ ] HTTPS настроен и работает
- [ ] HSTS включен
- [ ] TLS 1.2+ настроен
- [ ] Firewall правила применены
- [ ] IP allowlist для admin настроен
- [ ] Rate limiting настроен
- [ ] Security headers настроены
- [ ] PII scrubbing работает
- [ ] Log retention настроен
- [ ] Pen-test выполнен
- [ ] Все уязвимости исправлены

### Регулярные проверки

- [ ] Ежемесячный security audit
- [ ] Проверка обновлений зависимостей
- [ ] Проверка логов безопасности
- [ ] Тестирование восстановления из бэкапа
- [ ] Обновление сертификатов SSL

## Дополнительные ресурсы

- [OWASP API Security Top 10](https://owasp.org/www-project-api-security/)
- [OWASP Top 10](https://owasp.org/www-project-top-ten/)
- [Django Security](https://docs.djangoproject.com/en/stable/topics/security/)
- [SSL Labs SSL Test](https://www.ssllabs.com/ssltest/)


# Security Infrastructure для Ringo Uchet

Комплексная система безопасности проекта.

## Компоненты

### 1. HTTPS (Let's Encrypt / ACM)

**Let's Encrypt:**
- Автоматическая установка через Certbot
- Автоматическое обновление через systemd timer
- Скрипт: `certbot-setup.sh`

**ACM (AWS Certificate Manager):**
- Использование при работе через AWS Load Balancer
- SSL termination на LB

### 2. Firewall и WAF

**UFW Firewall:**
- Скрипт настройки: `firewall-rules.sh`
- Правила для портов
- Блокировка неразрешенных соединений

**Nginx WAF:**
- Rate limiting
- Блокировка подозрительных User-Agent
- IP allowlist для admin endpoints

### 3. Security Middleware

**Защита от атак:**
- SQL Injection Protection
- XSS Protection
- SSRF Protection
- IP Allowlist для admin

**PII Scrubbing:**
- Автоматическая очистка PII из логов
- Шифрование чувствительных данных

### 4. Pen-test Checklist

Документация для проведения penetration testing:
- `docs/PENTEST_CHECKLIST.md` - детальный чеклист
- `docs/SECURITY.md` - общее руководство по безопасности

## Быстрый старт

### Настройка HTTPS

```bash
# Let's Encrypt
./infra/security/certbot-setup.sh api.ringo.example.com admin@ringo.example.com

# Проверка
openssl s_client -connect api.ringo.example.com:443
```

### Настройка Firewall

```bash
./infra/security/firewall-rules.sh
```

### Настройка IP Allowlist

```env
ADMIN_ALLOWED_IPS=127.0.0.1,10.0.0.0/8,YOUR_OFFICE_IP
```

## Документация

- [Security Guide](../docs/SECURITY.md) - Полное руководство по безопасности
- [Pen-test Checklist](../docs/PENTEST_CHECKLIST.md) - Чеклист для penetration testing

## Регулярные проверки

- Ежемесячный security audit
- Проверка обновлений зависимостей
- Обновление SSL сертификатов
- Проверка логов безопасности


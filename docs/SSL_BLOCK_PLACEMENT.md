# 📍 ГДЕ РАЗМЕСТИТЬ БЛОК ДЛЯ CERTBOT

## ✅ ОТВЕТ

**Перед блоком `location / {`** (первый блок location в HTTP сервере).

---

## 📝 ПРИМЕР

```nginx
server {
    listen 80;
    server_name ringoouchet.ru www.ringoouchet.ru 91.229.90.72;

    # ДОБАВЬТЕ ЗДЕСЬ - ПЕРЕД location / {
    location /.well-known/acme-challenge/ {
        root /var/www/certbot;
    }

    # ЭТОТ БЛОК УЖЕ ЕСТЬ
    location / {
        root /var/www/ringo-uchet;
        ...
    }

    location /api/ {
        ...
    }
}
```

---

**Важно:** Блок для Certbot должен быть **ПЕРВЫМ** блоком location, чтобы Nginx обрабатывал его до других.


# ✅ НАСТРОЙКА SSL ДЛЯ ringoouchet.ru

## 🎯 ЦЕЛЬ
Настроить HTTPS, чтобы редирект 301 работал правильно.

---

## 📋 ШАГ 1: Проверить текущую конфигурацию Nginx

```bash
sudo cat /etc/nginx/sites-available/ringo-uchet | head -50
```

**Покажет текущую конфигурацию.**

---

## 📋 ШАГ 2: Обновить Nginx для получения SSL

```bash
sudo nano /etc/nginx/sites-available/ringo-uchet
```

**Нужно добавить блок для Certbot (/.well-known/acme-challenge/)**

---

## 📋 ШАГ 3: Создать директорию для Certbot

```bash
sudo mkdir -p /var/www/certbot
sudo chmod -R 755 /var/www/certbot
```

---

## 📋 ШАГ 4: Перезагрузить Nginx

```bash
sudo nginx -t
sudo systemctl reload nginx
```

---

## 📋 ШАГ 5: Получить SSL сертификат

```bash
sudo certbot certonly --webroot -w /var/www/certbot -d ringoouchet.ru -d www.ringoouchet.ru
```

**Следуйте инструкциям Certbot.**

---

**Начнем с шага 1 - покажите текущую конфигурацию Nginx!**


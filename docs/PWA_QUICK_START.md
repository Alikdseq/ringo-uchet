# ⚡ БЫСТРЫЙ СТАРТ РАЗВЕРТЫВАНИЯ PWA

Это краткая версия полного руководства. Для детальной информации см. [PWA_DEPLOYMENT_GUIDE.md](./PWA_DEPLOYMENT_GUIDE.md)

## 🎯 Минимальные требования

- VPS сервер (Ubuntu 22.04+)
- Домен с настроенным DNS
- SSH доступ к серверу
- Flutter SDK на локальном компьютере

## 📝 Быстрая установка (5 шагов)

### 1. Подготовка сервера

```bash
# На сервере
sudo apt update && sudo apt upgrade -y
sudo apt install -y docker.io docker-compose-plugin nginx certbot python3-certbot-nginx
sudo usermod -aG docker $USER
```

### 2. Настройка DNS

В панели управления домена создайте A запись:
```
@ → YOUR_SERVER_IP
```

### 3. Клонирование проекта

```bash
# На сервере
cd ~
git clone YOUR_REPO_URL ringo-uchet
cd ringo-uchet/backend
nano .env  # Настройте переменные окружения (см. полное руководство)
```

### 4. Сборка и развертывание Flutter Web

```bash
# На локальном компьютере
cd mobile
flutter build web --release --base-href /
scp -r build/web/* ringo@YOUR_SERVER_IP:/var/www/ringo-uchet/
```

### 5. Настройка Nginx и SSL

```bash
# На сервере
sudo certbot --nginx -d your-domain.com
sudo systemctl reload nginx
```

## ✅ Проверка

1. Откройте: `https://your-domain.com`
2. Проверьте API: `https://your-domain.com/api/health/`
3. Проверьте манифест: `https://your-domain.com/manifest.json`

## 📚 Полная документация

См. [PWA_DEPLOYMENT_GUIDE.md](./PWA_DEPLOYMENT_GUIDE.md) для детальных инструкций.


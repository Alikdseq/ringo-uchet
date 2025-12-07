# ✅ ДЕЙСТВИЕ 3: УСТАНОВКА DOCKER, NGINX И CERTBOT

## 🎯 ЦЕЛЬ
Установить необходимое ПО для работы приложения.

---

## 📋 ШАГ 1: УСТАНОВКА DOCKER

**Выполните команды по порядку в SSH терминале:**

### 1.1 Удаление старых версий (если есть)

```bash
sudo apt remove -y docker docker-engine docker.io containerd runc
```

### 1.2 Установка зависимостей

```bash
sudo apt install -y ca-certificates curl gnupg lsb-release
```

### 1.3 Добавление GPG ключа Docker

```bash
sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
```

### 1.4 Настройка репозитория

```bash
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
```

### 1.5 Установка Docker

```bash
sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
```

⏱️ **Займет 2-3 минуты**

### 1.6 Проверка установки

```bash
sudo docker --version
sudo docker compose version
```

**Должно показать версии (например: Docker version 24.x.x)**

### 1.7 Добавление root в группу docker

```bash
sudo usermod -aG docker root
```

**Для root это не обязательно, но полезно.**

---

## 📋 ШАГ 2: УСТАНОВКА NGINX

### 2.1 Установка

```bash
sudo apt install -y nginx
```

⏱️ **Займет 30 секунд**

### 2.2 Включение автозапуска

```bash
sudo systemctl enable nginx
sudo systemctl start nginx
```

### 2.3 Проверка статуса

```bash
sudo systemctl status nginx
```

**Должно показать: `active (running)`**

Для выхода из просмотра статуса нажмите: `Q`

---

## 📋 ШАГ 3: УСТАНОВКА CERTBOT (для SSL)

### 3.1 Установка

```bash
sudo apt install -y certbot python3-certbot-nginx
```

⏱️ **Займет 1 минуту**

### 3.2 Проверка установки

```bash
certbot --version
```

**Должно показать версию (например: certbot 2.x.x)**

---

## ✅ ПРОВЕРКА ВСЕГО

**Выполните команды для проверки:**

```bash
docker --version
docker compose version
nginx -v
certbot --version
```

**Все должно показать версии без ошибок.**

---

## ⏭️ СЛЕДУЮЩИЙ ШАГ

**После выполнения напишите:**
- ✅ **"Готово, все установлено"** - перейдем к настройке домена

---

**Статус:** ⏳ Установка необходимого ПО

**Время выполнения:** 5-7 минут


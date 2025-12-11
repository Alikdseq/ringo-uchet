# 🔍 ПРОВЕРКА: Несоответствие endpoint для входа

## ❌ ПРОБЛЕМА

**Flutter использует `/auth/login/`, но API использует `/api/token/`!**

**Нужно проверить какой endpoint правильный.**

---

## 🔍 ПРОВЕРКА 1: Логи Nginx Access (POST запросы)

```bash
sudo tail -200 /var/log/nginx/ringo-uchet-access.log | grep -i "POST\|auth\|token\|login"
```

**Ищите POST запросы при попытке входа - увидите какой endpoint используется!**

---

## 🔍 ПРОВЕРКА 2: Логи Nginx Error

```bash
sudo tail -100 /var/log/nginx/ringo-uchet-error.log
```

**Ищите ошибки 404 или 500 при POST запросах.**

---

## 🔍 ПРОВЕРКА 3: Проверить endpoint API

**API использует `/api/token/`. Проверим:**

```bash
curl -X POST https://ringoouchet.ru/api/token/ \
  -H "Content-Type: application/json" \
  -H "Origin: https://ringoouchet.ru" \
  -d '{"phone": "test", "password": "test"}' -v
```

**Что возвращает?**

---

**Выполните проверки 1-2 и отправьте логи!**


# ✅ ИСПРАВЛЕНИЕ: Мобильный использует кэш

## ❌ ПРОБЛЕМА

- На ПК работает ✅
- На телефоне не работает ❌
- POST запросы не доходят

**Причина: мобильный браузер использует закэшированную старую версию!**

---

## ✅ РЕШЕНИЕ

### ШАГ 1: Очистить кэш на мобильном (быстрое решение)

**На телефоне:**

1. Откройте настройки браузера
2. Найдите "Очистить данные" / "Очистить кэш" / "История"
3. Очистите кэш и cookies для `ringoouchet.ru`
4. Или используйте режим инкогнито/приватный режим

**Попробуйте войти еще раз!**

---

### ШАГ 2: Пересобрать и загрузить Flutter Web (если шаг 1 не помог)

**На вашем компьютере:**

```powershell
cd C:\ringo-uchet\mobile
flutter clean
flutter build web --release --base-href /
```

**Затем скопировать на сервер:**

```powershell
cd build
Compress-Archive -Path web\* -DestinationPath web-build.zip
scp web-build.zip root@91.229.90.72:~/web-build-new.zip
```

**На сервере:**

```bash
cd ~
rm -rf /var/www/ringo-uchet/*
unzip -o web-build-new.zip -d /var/www/ringo-uchet/
sudo chown -R www-data:www-data /var/www/ringo-uchet
```

---

**Начните с ШАГА 1 - очистите кэш на телефоне!**


# Команды для деплоя на сервер (исправленные)

## 1. Проверьте реальный путь веб-директории

```bash
# Проверьте конфигурацию Nginx
sudo cat /etc/nginx/sites-enabled/* | grep "root"

# Или проверьте, что существует
ls -la /var/www/ringo-uchet/
```

## 2. Вариант A: Если файлы должны быть в /var/www/ringo-uchet/ (корень)

```bash
# Создать backup текущей версии (если существует)
if [ -d "/var/www/ringo-uchet" ]; then
    sudo cp -r /var/www/ringo-uchet /var/www/ringo-uchet-backup-$(date +%Y%m%d-%H%M%S)
fi

# Создать директорию если не существует
sudo mkdir -p /var/www/ringo-uchet

# Распаковать новую версию
sudo unzip -o ~/web-build-latest.zip -d /tmp/web-new

# Заменить файлы
sudo rm -rf /var/www/ringo-uchet/*
sudo mv /tmp/web-new/* /var/www/ringo-uchet/

# Установить правильные права
sudo chown -R www-data:www-data /var/www/ringo-uchet
sudo chmod -R 755 /var/www/ringo-uchet

# Перезагрузить Nginx
sudo systemctl reload nginx

# Удалить временные файлы
rm -rf /tmp/web-new
rm ~/web-build-latest.zip
```

## 3. Вариант B: Если файлы должны быть в /var/www/ringo-uchet/web/

```bash
# Создать backup текущей версии (если существует)
if [ -d "/var/www/ringo-uchet/web" ]; then
    sudo cp -r /var/www/ringo-uchet/web /var/www/ringo-uchet/web-backup-$(date +%Y%m%d-%H%M%S)
fi

# Создать директорию если не существует
sudo mkdir -p /var/www/ringo-uchet/web

# Распаковать новую версию
sudo unzip -o ~/web-build-latest.zip -d /tmp/web-new

# Заменить файлы
sudo rm -rf /var/www/ringo-uchet/web/*
sudo mv /tmp/web-new/* /var/www/ringo-uchet/web/

# Установить правильные права
sudo chown -R www-data:www-data /var/www/ringo-uchet/web
sudo chmod -R 755 /var/www/ringo-uchet/web

# Перезагрузить Nginx
sudo systemctl reload nginx

# Удалить временные файлы
rm -rf /tmp/web-new
rm ~/web-build-latest.zip
```

## 4. Быстрая проверка после деплоя

```bash
# Проверить что файлы на месте
ls -la /var/www/ringo-uchet/  # или /var/www/ringo-uchet/web/

# Проверить права
sudo ls -la /var/www/ringo-uchet/ | head -5

# Проверить статус Nginx
sudo systemctl status nginx

# Проверить логи если что-то не работает
sudo tail -f /var/log/nginx/error.log
```


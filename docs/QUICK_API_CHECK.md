# 🔍 БЫСТРАЯ ПРОВЕРКА: Почему API не работает на телефоне

## ✅ ШАГ 1: Проверить API и CORS (на сервере)

**На сервере выполните ВСЮ эту команду:**

```bash
echo "=== 1. API через HTTPS ===" && curl -k https://ringoouchet.ru/api/health/ && echo -e "\n" && echo "=== 2. CORS заголовки ===" && curl -k -I -H "Origin: https://ringoouchet.ru" https://ringoouchet.ru/api/health/ 2>&1 | grep -i "access-control" && echo "=== 3. Nginx /api/ конфиг ===" && sudo cat /etc/nginx/sites-available/ringo-uchet | grep -A 10 "location /api/"
```

**Пришлите ВЕСЬ вывод!**

---

## ✅ ШАГ 2: Создать тестовую страницу (на сервере)

**На сервере:**

```bash
cat > /tmp/test-api.html << 'ENDOFFILE'
<!DOCTYPE html>
<html>
<head>
    <title>Тест API</title>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
</head>
<body>
    <h1>🔍 Тест API</h1>
    <button onclick="test()">Тест API</button>
    <div id="result"></div>
    <script>
    async function test() {
        const el = document.getElementById('result');
        el.innerHTML = '⏳ Тестирую...';
        try {
            const response = await fetch('https://ringoouchet.ru/api/health/');
            const data = await response.json();
            el.innerHTML = '✅ Успех!<br><pre>' + JSON.stringify(data, null, 2) + '</pre>';
        } catch (error) {
            el.innerHTML = '❌ Ошибка: ' + error.message;
        }
    }
    </script>
</body>
</html>
ENDOFFILE

sudo cp /tmp/test-api.html /var/www/ringo-uchet/test-api.html
sudo chown www-data:www-data /var/www/ringo-uchet/test-api.html
echo "✅ Страница создана!"
```

---

## ✅ ШАГ 3: Проверить на телефоне

**На телефоне откройте:**
- `https://ringoouchet.ru/test-api.html`
- Нажмите "Тест API"
- **Скажите что показало!**

---

**Выполните ШАГИ 1-3 и пришлите результаты!**


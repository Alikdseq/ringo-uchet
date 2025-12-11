# 🔧 ПОЛНОЕ РЕШЕНИЕ: API не работает на телефоне

## 🎯 ЦЕЛЬ

**Убедиться что API доступен на телефоне через домен!**

---

## ✅ ШАГ 1: Проверить API доступность

**На сервере выполните ВСЕ команды:**

```bash
echo "=== 1. API через HTTPS домен ==="
curl -k https://ringoouchet.ru/api/health/ && echo ""

echo -e "\n=== 2. Проверка CORS заголовков ==="
curl -k -I -H "Origin: https://ringoouchet.ru" https://ringoouchet.ru/api/health/ 2>&1 | grep -i "access-control"

echo -e "\n=== 3. Проверка Nginx прокси /api/ ==="
sudo cat /etc/nginx/sites-available/ringo-uchet | grep -A 10 "location /api/"
```

**Пришлите результаты всех трех!**

---

## ✅ ШАГ 2: Создать диагностическую страницу

**На сервере:**

```bash
cat > /tmp/test-api.html << 'EOF'
<!DOCTYPE html>
<html>
<head>
    <title>Тест API</title>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <style>
        body { font-family: Arial; padding: 20px; }
        .test { margin: 15px 0; padding: 15px; border: 1px solid #ddd; }
        .success { color: green; }
        .error { color: red; }
        button { padding: 10px 20px; margin: 5px; }
        pre { background: #f5f5f5; padding: 10px; overflow-x: auto; }
    </style>
</head>
<body>
    <h1>🔍 Диагностика API</h1>
    
    <div class="test">
        <h3>Тест 1: API Health</h3>
        <button onclick="test1()">Проверить</button>
        <div id="result1"></div>
    </div>
    
    <div class="test">
        <h3>Тест 2: CORS Preflight</h3>
        <button onclick="test2()">Проверить</button>
        <div id="result2"></div>
    </div>
    
    <script>
    async function test1() {
        const el = document.getElementById('result1');
        el.innerHTML = '⏳ Тестирую...';
        try {
            const response = await fetch('https://ringoouchet.ru/api/health/');
            const data = await response.json();
            el.innerHTML = `<span class="success">✅ Успех!</span><br>
                Статус: ${response.status}<br>
                <pre>${JSON.stringify(data, null, 2)}</pre>`;
        } catch (error) {
            el.innerHTML = `<span class="error">❌ Ошибка!</span><br>
                ${error.message}`;
        }
    }
    
    async function test2() {
        const el = document.getElementById('result2');
        el.innerHTML = '⏳ Тестирую...';
        try {
            const response = await fetch('https://ringoouchet.ru/api/v1/auth/login/', {
                method: 'OPTIONS',
                headers: {
                    'Origin': window.location.origin,
                    'Access-Control-Request-Method': 'POST',
                    'Access-Control-Request-Headers': 'Content-Type',
                }
            });
            const corsOrigin = response.headers.get('Access-Control-Allow-Origin');
            const corsMethods = response.headers.get('Access-Control-Allow-Methods');
            el.innerHTML = `<span class="success">✅ Preflight успешен!</span><br>
                Статус: ${response.status}<br>
                Allow-Origin: ${corsOrigin || 'НЕТ'}<br>
                Allow-Methods: ${corsMethods || 'НЕТ'}`;
        } catch (error) {
            el.innerHTML = `<span class="error">❌ Ошибка preflight!</span><br>
                ${error.message}<br>
                <strong>ЭТО ПРОБЛЕМА!</strong>`;
        }
    }
    </script>
</body>
</html>
EOF

sudo cp /tmp/test-api.html /var/www/ringo-uchet/test-api.html
sudo chown www-data:www-data /var/www/ringo-uchet/test-api.html
sudo chmod 644 /var/www/ringo-uchet/test-api.html

echo "✅ Страница создана: https://ringoouchet.ru/test-api.html"
```

---

## ✅ ШАГ 3: Проверить CORS настройки Django

**На сервере:**

```bash
cd /root/ringo-uchet/backend
echo "=== CORS переменные в контейнере ==="
docker compose -f docker-compose.prod.yml exec api env | grep -E "CORS|ALLOWED" | sort
```

**Пришлите вывод!**

---

## ✅ ШАГ 4: На телефоне

**Откройте на телефоне:**
1. `https://ringoouchet.ru/test-api.html`
2. Выполните оба теста
3. **Пришлите скриншоты или результаты!**

---

**Выполните ШАГИ 1-3 и пришлите результаты!**


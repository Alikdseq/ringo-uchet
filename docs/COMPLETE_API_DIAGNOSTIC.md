# 🔍 ПОЛНАЯ ДИАГНОСТИКА: API не работает на телефоне

## ❌ ПРОБЛЕМА

**Flutter работает, но API не доступен на телефоне!**

---

## ✅ ПРОВЕРКА 1: API через домен (на сервере)

**На сервере:**

```bash
echo "=== 1. API через HTTPS домен ==="
curl -k -v https://ringoouchet.ru/api/health/ 2>&1 | grep -E "HTTP|status|healthy|error"

echo -e "\n=== 2. API через HTTP домен ==="
curl -L -v http://ringoouchet.ru/api/health/ 2>&1 | grep -E "HTTP|status|healthy|error"

echo -e "\n=== 3. API локально ==="
curl -s http://localhost:8001/api/health/ | head -3
```

**Пришлите результаты всех трех проверок!**

---

## ✅ ПРОВЕРКА 2: Nginx конфигурация для /api/

**На сервере:**

```bash
echo "=== Конфигурация Nginx для /api/ ==="
sudo cat /etc/nginx/sites-available/ringo-uchet | grep -A 15 "location /api/"
```

**Что должно быть:**
```nginx
location /api/ {
    proxy_pass http://127.0.0.1:8001;
    ...
}
```

**Пришлите вывод!**

---

## ✅ ПРОВЕРКА 3: CORS заголовки

**На сервере:**

```bash
echo "=== CORS заголовки от API ==="
curl -k -I -H "Origin: https://ringoouchet.ru" https://ringoouchet.ru/api/health/ 2>&1 | grep -i "access-control"
```

**Должны быть заголовки:**
- `Access-Control-Allow-Origin`
- `Access-Control-Allow-Methods`

**Пришлите вывод!**

---

## ✅ ПРОВЕРКА 4: Django CORS настройки

**На сервере:**

```bash
cd /root/ringo-uchet/backend
echo "=== CORS переменные окружения ==="
docker compose -f docker-compose.prod.yml exec api env | grep -E "CORS|ALLOWED"
```

**Пришлите вывод!**

---

## ✅ ПРОВЕРКА 5: Django логи при запросе

**На сервере (в одном терминале):**

```bash
cd /root/ringo-uchet/backend
docker compose -f docker-compose.prod.yml logs api -f
```

**В другом терминале на телефоне попробуйте войти!**

**Ищите ошибки в логах!**

---

## 🔧 РЕШЕНИЕ: Создать диагностическую страницу

**На сервере:**

```bash
cat > /var/www/ringo-uchet/test-api.html << 'EOF'
<!DOCTYPE html>
<html>
<head>
    <title>Тест API</title>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <style>
        body { font-family: Arial; padding: 20px; max-width: 800px; margin: 0 auto; }
        .test { margin: 15px 0; padding: 15px; border: 1px solid #ddd; border-radius: 5px; }
        .success { color: green; }
        .error { color: red; }
        button { padding: 10px 20px; margin: 5px; cursor: pointer; }
        pre { background: #f5f5f5; padding: 10px; overflow-x: auto; }
    </style>
</head>
<body>
    <h1>🔍 Диагностика API подключения</h1>
    
    <div class="test">
        <h3>Тест 1: API Health через HTTPS</h3>
        <button onclick="test1()">Проверить</button>
        <div id="result1"></div>
    </div>
    
    <div class="test">
        <h3>Тест 2: API Health через HTTP</h3>
        <button onclick="test2()">Проверить</button>
        <div id="result2"></div>
    </div>
    
    <div class="test">
        <h3>Тест 3: CORS заголовки</h3>
        <button onclick="test3()">Проверить</button>
        <div id="result3"></div>
    </div>
    
    <div class="test">
        <h3>Тест 4: Логин эндпоинт (OPTIONS preflight)</h3>
        <button onclick="test4()">Проверить</button>
        <div id="result4"></div>
    </div>
    
    <script>
    async function test1() {
        const el = document.getElementById('result1');
        el.innerHTML = '⏳ Тестирую...';
        try {
            const response = await fetch('https://ringoouchet.ru/api/health/');
            const data = await response.json();
            el.innerHTML = `<span class="success">✅ Успех!</span><br>
                <strong>Статус:</strong> ${response.status}<br>
                <pre>${JSON.stringify(data, null, 2)}</pre>`;
        } catch (error) {
            el.innerHTML = `<span class="error">❌ Ошибка!</span><br>
                <strong>Ошибка:</strong> ${error.message}<br>
                <strong>Тип:</strong> ${error.name}`;
        }
    }
    
    async function test2() {
        const el = document.getElementById('result2');
        el.innerHTML = '⏳ Тестирую...';
        try {
            const response = await fetch('http://ringoouchet.ru/api/health/');
            const data = await response.json();
            el.innerHTML = `<span class="success">✅ Успех!</span><br>
                <strong>Статус:</strong> ${response.status}<br>
                <pre>${JSON.stringify(data, null, 2)}</pre>`;
        } catch (error) {
            el.innerHTML = `<span class="error">❌ Ошибка!</span><br>
                <strong>Ошибка:</strong> ${error.message}`;
        }
    }
    
    async function test3() {
        const el = document.getElementById('result3');
        el.innerHTML = '⏳ Тестирую...';
        try {
            const response = await fetch('https://ringoouchet.ru/api/health/', {
                method: 'OPTIONS',
                headers: {
                    'Origin': window.location.origin,
                    'Access-Control-Request-Method': 'GET',
                }
            });
            el.innerHTML = `<span class="success">✅ Успех!</span><br>
                <strong>Статус:</strong> ${response.status}<br>
                <strong>Заголовки:</strong><br>
                <pre>${JSON.stringify([...response.headers.entries()], null, 2)}</pre>`;
        } catch (error) {
            el.innerHTML = `<span class="error">❌ Ошибка!</span><br>
                <strong>Ошибка:</strong> ${error.message}`;
        }
    }
    
    async function test4() {
        const el = document.getElementById('result4');
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
            el.innerHTML = `<span class="success">✅ Preflight успешен!</span><br>
                <strong>Статус:</strong> ${response.status}<br>
                <strong>CORS заголовки:</strong><br>
                <pre>Allow-Origin: ${response.headers.get('Access-Control-Allow-Origin') || 'НЕТ'}
Allow-Methods: ${response.headers.get('Access-Control-Allow-Methods') || 'НЕТ'}
Allow-Headers: ${response.headers.get('Access-Control-Allow-Headers') || 'НЕТ'}</pre>`;
        } catch (error) {
            el.innerHTML = `<span class="error">❌ Ошибка preflight!</span><br>
                <strong>Ошибка:</strong> ${error.message}<br>
                <strong>Это может быть причиной проблемы!</strong>`;
        }
    }
    </script>
</body>
</html>
EOF

sudo chown www-data:www-data /var/www/ringo-uchet/test-api.html
sudo chmod 644 /var/www/ringo-uchet/test-api.html
```

**На телефоне откройте:** `https://ringoouchet.ru/test-api.html`

**Выполните все 4 теста и пришлите результаты!**

---

**Выполните все проверки и пришлите результаты!**


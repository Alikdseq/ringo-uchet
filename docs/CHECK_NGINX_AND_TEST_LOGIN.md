# ✅ ПРОВЕРКА: Тест API работает, но логин нет?

## 🎯 ЦЕЛЬ

**Выяснить почему тест API работает, а логин не работает!**

---

## ✅ ШАГ 1: Проверить конфигурацию Nginx

**На сервере:**

```bash
echo "=== Конфигурация Nginx для /api/ ==="
sudo cat /etc/nginx/sites-available/ringo-uchet | grep -A 15 "location /api/"
```

**Пришлите вывод!**

---

## ✅ ШАГ 2: Проверить CORS для OPTIONS запросов

**На сервере:**

```bash
echo "=== Тест OPTIONS (preflight) ==="
curl -k -v -X OPTIONS \
  -H "Origin: https://ringoouchet.ru" \
  -H "Access-Control-Request-Method: POST" \
  -H "Access-Control-Request-Headers: Content-Type" \
  https://ringoouchet.ru/api/v1/auth/login/ 2>&1 | grep -E "< HTTP|< access-control|access-control"
```

**Пришлите вывод!**

---

## ✅ ШАГ 3: Тест логина (на телефоне)

**На телефоне откройте:**

```html
https://ringoouchet.ru/test-login.html
```

**Создайте эту страницу на сервере:**

```bash
cat > /tmp/test-login.html << 'EOF'
<!DOCTYPE html>
<html>
<head>
    <title>Тест Логин</title>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <style>
        body { font-family: Arial; padding: 20px; }
        input { padding: 10px; margin: 5px; width: 200px; }
        button { padding: 10px 20px; margin: 5px; }
        .result { margin-top: 20px; padding: 10px; border: 1px solid #ddd; }
        .success { color: green; }
        .error { color: red; }
        pre { background: #f5f5f5; padding: 10px; overflow-x: auto; }
    </style>
</head>
<body>
    <h1>🔍 Тест Логина</h1>
    <input type="text" id="phone" placeholder="Телефон" value=""><br>
    <input type="password" id="password" placeholder="Пароль" value=""><br>
    <button onclick="testLogin()">Войти</button>
    <div id="result" class="result"></div>
    
    <script>
    async function testLogin() {
        const el = document.getElementById('result');
        const phone = document.getElementById('phone').value;
        const password = document.getElementById('password').value;
        
        el.innerHTML = '⏳ Вход...';
        
        try {
            // Сначала проверим OPTIONS
            const optionsResponse = await fetch('https://ringoouchet.ru/api/v1/auth/login/', {
                method: 'OPTIONS',
                headers: {
                    'Origin': window.location.origin,
                    'Access-Control-Request-Method': 'POST',
                    'Access-Control-Request-Headers': 'Content-Type',
                }
            });
            
            console.log('OPTIONS Status:', optionsResponse.status);
            console.log('CORS Headers:', {
                origin: optionsResponse.headers.get('Access-Control-Allow-Origin'),
                methods: optionsResponse.headers.get('Access-Control-Allow-Methods'),
            });
            
            // Теперь POST запрос
            const response = await fetch('https://ringoouchet.ru/api/v1/auth/login/', {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                },
                credentials: 'include',
                body: JSON.stringify({
                    phone: phone || 'test',
                    password: password || 'test'
                })
            });
            
            const data = await response.json();
            
            el.innerHTML = `
                <span class="success">✅ Запрос отправлен!</span><br>
                <strong>Статус:</strong> ${response.status}<br>
                <strong>Ответ:</strong><br>
                <pre>${JSON.stringify(data, null, 2)}</pre>
            `;
        } catch (error) {
            el.innerHTML = `
                <span class="error">❌ Ошибка!</span><br>
                <strong>Ошибка:</strong> ${error.message}<br>
                <strong>Тип:</strong> ${error.name}<br>
                <strong>Стек:</strong><br>
                <pre>${error.stack}</pre>
            `;
        }
    }
    </script>
</body>
</html>
EOF

sudo cp /tmp/test-login.html /var/www/ringo-uchet/test-login.html
sudo chown www-data:www-data /var/www/ringo-uchet/test-login.html
echo "✅ Страница создана: https://ringoouchet.ru/test-login.html"
```

---

## ✅ ШАГ 4: Проверить логи Django при попытке входа

**На сервере (в одном терминале):**

```bash
cd /root/ringo-uchet/backend
docker compose -f docker-compose.prod.yml logs api -f --tail=50
```

**В другом терминале или на телефоне попробуйте войти!**

**Ищите ошибки!**

---

**Выполните ШАГИ 1-4 и пришлите результаты!**


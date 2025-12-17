#!/bin/bash
# Скрипт для проверки включен ли gzip на сервере

echo "========================================"
echo "  Проверка gzip на сервере"
echo "========================================"
echo ""

# Проверка 1: Проверить конфигурацию Nginx
echo "1. Проверка конфигурации Nginx..."
if grep -q "gzip on" /etc/nginx/nginx.conf 2>/dev/null || grep -r "gzip on" /etc/nginx/sites-enabled/ 2>/dev/null; then
    echo "   ✅ gzip найден в конфигурации"
else
    echo "   ❌ gzip НЕ найден в конфигурации"
fi

# Проверка 2: Проверить заголовки через curl
echo ""
echo "2. Проверка заголовков ответа сервера..."
echo "   Выполните на ЛОКАЛЬНОМ компьютере:"
echo "   curl -H 'Accept-Encoding: gzip' -I https://your-domain.com/main.dart.js"
echo ""
echo "   Ищите строку: content-encoding: gzip"
echo ""

# Проверка 3: Проверить размер ответа
echo "3. Сравнение размера с gzip и без:"
echo "   Без gzip: curl -I https://your-domain.com/main.dart.js | grep content-length"
echo "   С gzip:   curl -H 'Accept-Encoding: gzip' -I https://your-domain.com/main.dart.js | grep content-length"
echo ""
echo "   Если gzip работает, размер с gzip должен быть меньше"
echo ""

# Проверка 4: Быстрая проверка через curl (если есть домен)
if [ ! -z "$1" ]; then
    DOMAIN="$1"
    echo "4. Проверка для домена: $DOMAIN"
    RESPONSE=$(curl -s -H "Accept-Encoding: gzip" -I "https://$DOMAIN/main.dart.js" 2>/dev/null)
    
    if echo "$RESPONSE" | grep -qi "content-encoding: gzip"; then
        echo "   ✅ gzip РАБОТАЕТ!"
        echo ""
        echo "   Размер без gzip:"
        curl -s -I "https://$DOMAIN/main.dart.js" 2>/dev/null | grep -i "content-length" || echo "   (не указан)"
        echo ""
        echo "   Размер с gzip:"
        curl -s -H "Accept-Encoding: gzip" -I "https://$DOMAIN/main.dart.js" 2>/dev/null | grep -i "content-length" || echo "   (не указан)"
    else
        echo "   ❌ gzip НЕ работает!"
        echo "   Нужно настроить gzip в конфигурации Nginx"
    fi
fi

echo ""
echo "========================================"


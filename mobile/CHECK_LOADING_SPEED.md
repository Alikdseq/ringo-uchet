# ⚡ Проверка скорости загрузки сайта

## 🔍 Способ 1: Через браузер DevTools (самый точный)

### Шаги:

1. Откройте сайт: `https://ringoouchet.ru`
2. Нажмите `F12` (или `Ctrl+Shift+I`) - откроется DevTools
3. Перейдите на вкладку **Network** (Сеть)
4. Обновите страницу (`F5` или `Ctrl+R`)
5. Посмотрите на:
   - **Время загрузки** (Load time) - внизу внизу панели
   - **Размер файлов** - должен быть сжатым благодаря gzip
   - **Время до первого байта** (TTFB)

### Что проверять:

✅ **Полное время загрузки** (Load): должно быть **< 3 секунд**
✅ **Размер main.dart.js**: должен быть **~1.2-1.5 MB** (с gzip), а не 4 MB
✅ **Content-Encoding: gzip** - должно быть в заголовках

---

## 🔍 Способ 2: Онлайн инструменты (рекомендуется)

### PageSpeed Insights (от Google):

1. Перейдите: https://pagespeed.web.dev/
2. Введите: `https://ringoouchet.ru`
3. Нажмите "Analyze"
4. Проверьте:
   - **Performance Score** - должно быть **> 80**
   - **First Contentful Paint (FCP)** - должно быть **< 1.8s**
   - **Largest Contentful Paint (LCP)** - должно быть **< 2.5s**

### GTmetrix:

1. Перейдите: https://gtmetrix.com/
2. Введите: `https://ringoouchet.ru`
3. Нажмите "Test your site"
4. Проверьте:
   - **PageSpeed Score** - должно быть **> 85**
   - **YSlow Score** - должно быть **> 85**
   - **Fully Loaded Time** - должно быть **< 3s**

### Pingdom:

1. Перейдите: https://tools.pingdom.com/
2. Введите: `https://ringoouchet.ru`
3. Выберите сервер (ближайший к России)
4. Нажмите "Test Now"
5. Проверьте:
   - **Performance Grade** - должно быть **> 85**
   - **Load Time** - должно быть **< 2s**

---

## 🔍 Способ 3: Через curl (командная строка)

### На вашем компьютере (PowerShell):

```powershell
# Проверка времени загрузки
Measure-Command { Invoke-WebRequest -Uri "https://ringoouchet.ru" -UseBasicParsing }

# Проверка размера с gzip
$response = Invoke-WebRequest -Uri "https://ringoouchet.ru/main.dart.js" -Headers @{"Accept-Encoding" = "gzip"} -UseBasicParsing
$response.Headers["Content-Length"]
$response.Headers["Content-Encoding"]
```

### На сервере (SSH):

```bash
# Время загрузки
time curl -s -o /dev/null https://ringoouchet.ru

# Размер файла с gzip
curl -H "Accept-Encoding: gzip" -I https://ringoouchet.ru/main.dart.js | grep -i "content-length\|content-encoding"

# Детальная информация о времени
curl -w "@-" -o /dev/null -s https://ringoouchet.ru <<'EOF'
     time_namelookup:  %{time_namelookup}\n
        time_connect:  %{time_connect}\n
     time_appconnect:  %{time_appconnect}\n
    time_pretransfer:  %{time_pretransfer}\n
       time_redirect:  %{time_redirect}\n
  time_starttransfer:  %{time_starttransfer}\n
                     ----------\n
          time_total:  %{time_total}\n
EOF
```

---

## 🔍 Способ 4: Chrome Lighthouse (встроен в браузер)

1. Откройте сайт: `https://ringoouchet.ru`
2. Нажмите `F12` → вкладка **Lighthouse**
3. Выберите:
   - ✅ Performance
   - ✅ Mobile (или Desktop)
4. Нажмите "Analyze page load"
5. Проверьте результаты:
   - **Performance Score** - должно быть **> 80**
   - **First Contentful Paint** - должно быть **< 1.8s**
   - **Largest Contentful Paint** - должно быть **< 2.5s**
   - **Time to Interactive** - должно быть **< 3.8s**

---

## 📊 Ожидаемые результаты

### После оптимизаций:

✅ **Полное время загрузки**: **1-3 секунды**
✅ **First Contentful Paint**: **< 1.8 секунд**
✅ **Размер с gzip**: **~1.2-1.5 MB** (вместо 4 MB)
✅ **Performance Score**: **> 80**

### Что должно быть быстро:

- ✅ HTML загружается мгновенно
- ✅ JavaScript файлы сжаты (gzip)
- ✅ Кэширование работает
- ✅ Нет блокирующих ресурсов

---

## 🚀 Быстрая проверка (1 минута)

### Вариант 1: DevTools (30 секунд)

1. Откройте `https://ringoouchet.ru`
2. `F12` → Network → `F5`
3. Посмотрите время загрузки внизу

### Вариант 2: PageSpeed Insights (1 минута)

1. https://pagespeed.web.dev/
2. Введите `https://ringoouchet.ru`
3. Нажмите "Analyze"
4. Посмотрите Performance Score

---

## 🔧 Если скорость медленная

### Проверьте:

1. **gzip включен?**
   ```bash
   curl -H "Accept-Encoding: gzip" -I https://ringoouchet.ru/main.dart.js | grep content-encoding
   ```

2. **Кэширование работает?**
   - В DevTools → Network → посмотрите заголовки ответа
   - Должно быть: `Cache-Control: public, immutable`

3. **Размер файлов?**
   - `main.dart.js` должен быть ~1.2-1.5 MB с gzip
   - Без gzip ~4 MB - это нормально, но gzip должен сжать

---

## ✅ Итог

Используйте **PageSpeed Insights** или **Chrome DevTools** для быстрой проверки. Это даст полную картину скорости загрузки!


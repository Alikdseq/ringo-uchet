# Оптимизация размера веб-сборки Flutter

## Размер сборки
- **С canvaskit (Skia рендерер):** ~30 МБ
- **Без canvaskit (HTML рендерер):** ~4 МБ ✅ (рекомендуется)

**Важно:** По умолчанию скрипты удаляют canvaskit для минимального размера. Если нужна лучшая производительность рендеринга, можно использовать canvaskit.

## Команды для оптимизированной сборки

### Базовая команда (уже оптимизирована):
```bash
flutter build web --release --tree-shake-icons
```

### Дополнительные флаги для уменьшения размера:
```bash
flutter build web --release --tree-shake-icons --no-sound-null-safety
```

## Оптимизации на уровне кода

### 1. Условная загрузка зависимостей для веб

Некоторые пакеты не нужны на веб (например, sqflite, некоторые Firebase функции).
Используйте условные импорты:

```dart
import 'package:flutter/foundation.dart' show kIsWeb;

// В коде:
if (!kIsWeb) {
  // Мобильные специфичные функции
}
```

### 2. Оптимизация зависимостей

✅ **Уже оптимизировано:**
- `sqflite` - используется условный импорт, исключается из веб-сборки
- Зависимости разделены на веб и мобильные через условные импорты

**Дополнительные рекомендации:**
- Некоторые Firebase функции могут быть опциональны для веб
- `flutter_secure_storage` работает на веб через IndexedDB (оптимально)

### 3. Сжатие ресурсов

Убедитесь, что все изображения оптимизированы:
- Используйте WebP формат вместо PNG где возможно
- Сжимайте изображения перед добавлением в проект
- Используйте lazy loading для изображений

## Серверная оптимизация (важно!)

### Включить gzip/brotli сжатие на сервере

Размер файлов уменьшится на 60-80% при сжатии:

#### Nginx:
```nginx
location / {
    gzip on;
    gzip_vary on;
    gzip_min_length 1024;
    gzip_types text/plain text/css text/xml text/javascript application/x-javascript application/xml+rss application/javascript application/json application/wasm;
    gzip_disable "MSIE [1-6]\.";
    
    # Brotli (если установлен)
    brotli on;
    brotli_comp_level 6;
    brotli_types text/plain text/css text/xml text/javascript application/x-javascript application/xml+rss application/javascript application/json application/wasm;
}
```

#### Apache (.htaccess):
```apache
<IfModule mod_deflate.c>
    AddOutputFilterByType DEFLATE text/html text/plain text/xml text/css text/javascript application/javascript application/json application/wasm
</IfModule>
```

## Анализ размера сборки

### Проверьте размер после сборки:
```bash
# Windows PowerShell
Get-ChildItem -Path build\web -Recurse | Measure-Object -Property Length -Sum | Select-Object @{Name="Size(MB)";Expression={[math]::Round($_.Sum / 1MB, 2)}}

# Linux/Mac
du -sh build/web
```

### Основные файлы которые влияют на размер:
- `main.dart.js` - основной JS файл (самый большой)
- `flutter.js` - Flutter runtime
- `assets/` - изображения, шрифты, иконки

## Дополнительные рекомендации

1. **Минификация уже включена** в release сборке
2. **Tree shaking** работает автоматически для неиспользуемого кода
3. **Используйте кэширование** - Service Worker уже настроен
4. **Lazy loading** - экраны загружаются по требованию (IndexedStack)

## Проверка результата

После оптимизации размер должен быть:
- Без сжатия: ~5-6 МБ
- С gzip: ~2-3 МБ (передаваемый размер)
- С brotli: ~1.5-2 МБ (передаваемый размер)


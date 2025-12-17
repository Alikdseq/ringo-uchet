#!/bin/bash
# Скрипт для оптимизированной сборки веб-версии приложения (Linux/Mac)

set -e

echo "========================================"
echo "  Оптимизированная сборка веб-версии"
echo "========================================"
echo ""

# Переходим в директорию проекта
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$SCRIPT_DIR/.."

# Очистка предыдущей сборки
echo "Очистка предыдущей сборки..."
rm -rf build/web

# Получение зависимостей
echo "Получение зависимостей..."
flutter pub get

# Оптимизированная сборка веб-версии
echo "Сборка веб-версии с оптимизациями..."
echo "Флаги: --release --tree-shake-icons"
flutter build web --release --tree-shake-icons

# Удалить canvaskit для использования HTML рендерера (экономия ~26 МБ)
echo "Удаление canvaskit (использование HTML рендерера для меньшего размера)..."
if [ -d "build/web/canvaskit" ]; then
    rm -rf build/web/canvaskit
    echo "  Canvaskit удален (экономия ~26 МБ)"
fi

# Удалить debug символы и NOTICES файлы
echo "Удаление debug символов и NOTICES файлов..."
find build/web -name "*.symbols" -type f -delete 2>/dev/null || true
find build/web -name "NOTICES*" -type f -delete 2>/dev/null || true
echo "  Debug файлы удалены"

# Анализ размера
echo ""
echo "========================================"
echo "  Анализ размера сборки"
echo "========================================"

if [ -d "build/web" ]; then
    # Общий размер
    TOTAL_SIZE=$(du -sh build/web | cut -f1)
    echo "Общий размер: $TOTAL_SIZE"
    echo ""
    
    # Размер по типам файлов
    echo "Размер по типам файлов:"
    JS_SIZE=$(find build/web -name "*.js" -type f -exec du -ch {} + | tail -1 | cut -f1)
    JS_COUNT=$(find build/web -name "*.js" -type f | wc -l)
    echo "  JS файлы: $JS_SIZE ($JS_COUNT файлов)"
    
    if [ -d "build/web/assets" ]; then
        ASSETS_SIZE=$(du -sh build/web/assets | cut -f1)
        echo "  Assets: $ASSETS_SIZE"
    fi
    
    # Топ 10 самых больших файлов
    echo ""
    echo "Топ 10 самых больших файлов:"
    find build/web -type f -exec du -h {} + | sort -rh | head -10 | while read size file; do
        relative_path=${file#build/web/}
        echo "  $size - $relative_path"
    done
fi

echo ""
echo "========================================"
echo "  Сборка завершена успешно!"
echo "========================================"
echo ""
echo "Важно: Для максимального уменьшения размера"
echo "включите gzip/brotli сжатие на сервере!"
echo "Подробности: WEB_BUILD_OPTIMIZATION.md"


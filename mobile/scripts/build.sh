#!/bin/bash
# Скрипт для сборки приложения

set -e

FLAVOR=${1:-dev}
BUILD_TYPE=${2:-debug}

echo "Building Flutter app..."
echo "Flavor: $FLAVOR"
echo "Build type: $BUILD_TYPE"

# Очистка
flutter clean

# Установка зависимостей
flutter pub get

# Генерация кода
flutter pub run build_runner build --delete-conflicting-outputs

# Анализ кода
flutter analyze

# Запуск тестов
flutter test

# Сборка
if [ "$BUILD_TYPE" == "release" ]; then
  if [ "$FLAVOR" == "prod" ]; then
    # Android AAB для Google Play
    flutter build appbundle --release --flavor prod -t lib/main_prod.dart
    
    # iOS для App Store
    flutter build ios --release --flavor prod -t lib/main_prod.dart
  else
    flutter build apk --release --flavor $FLAVOR -t lib/main_${FLAVOR}.dart
  fi
else
  flutter build apk --debug --flavor $FLAVOR -t lib/main_${FLAVOR}.dart
fi

echo "Build completed successfully!"


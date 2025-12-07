# Ringo Uchet Mobile

Мобильное приложение для системы учёта аренды спецтехники.

## Структура проекта

```
mobile/
├── lib/
│   ├── core/           # Основные компоненты (network, storage, theme)
│   ├── features/       # Функциональные модули (auth, orders, catalog)
│   ├── shared/         # Общие компоненты (widgets, models, utils)
│   └── main_*.dart     # Точки входа для разных flavors
├── test/               # Тесты
│   ├── unit/          # Unit тесты
│   ├── widget/        # Widget тесты
│   └── integration/   # Integration тесты
├── fastlane/          # Fastlane конфигурация
└── docs/              # Документация
```

## Установка

```bash
# Установка зависимостей
flutter pub get

# Генерация кода
flutter pub run build_runner build --delete-conflicting-outputs
```

## Запуск

```bash
# Dev flavor
flutter run --flavor dev -t lib/main_dev.dart

# Stage flavor
flutter run --flavor stage -t lib/main_stage.dart

# Prod flavor
flutter run --flavor prod -t lib/main_prod.dart
```

## Тестирование

```bash
# Все тесты
flutter test

# Unit тесты
flutter test test/unit

# Widget тесты
flutter test test/widget

# Integration тесты
flutter test integration_test

# С покрытием
flutter test --coverage
```

## Сборка

```bash
# Debug APK
flutter build apk --debug --flavor dev -t lib/main_dev.dart

# Release APK
flutter build apk --release --flavor prod -t lib/main_prod.dart

# Release AAB
flutter build appbundle --release --flavor prod -t lib/main_prod.dart

# iOS Release
flutter build ios --release --flavor prod -t lib/main_prod.dart
```

## Fastlane

```bash
# Установка
cd mobile
bundle install

# Сборка
fastlane android release_aab
fastlane ios release
```

## CI/CD

GitHub Actions автоматически:
- Запускает тесты при каждом PR
- Собирает артефакты при push в main

## Документация

- [Fastlane README](fastlane/README.md)

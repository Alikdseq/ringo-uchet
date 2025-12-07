# Fastlane для Ringo Uchet Mobile

## Установка

```bash
cd mobile
bundle install
```

## Использование

### Android

```bash
# Debug сборка
fastlane android debug

# Release APK
fastlane android release_apk

# Release AAB
fastlane android release_aab
```

### iOS

```bash
# Debug сборка
fastlane ios debug

# Release сборка для iOS
fastlane ios release
```

### Общие команды

```bash
# Запуск тестов
fastlane test

# Анализ кода
fastlane analyze

# Проверка линтера
fastlane lint

# Полная проверка перед релизом
fastlane pre_release
```

## Настройка

1. Обновите `Appfile` с вашими данными (package name, app identifier, team ID)


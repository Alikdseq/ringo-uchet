# PowerShell скрипт для сборки приложения

param(
    [string]$Flavor = "dev",
    [string]$BuildType = "debug"
)

Write-Host "Building Flutter app..."
Write-Host "Flavor: $Flavor"
Write-Host "Build type: $BuildType"

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
if ($BuildType -eq "release") {
    if ($Flavor -eq "prod") {
        # Android AAB для Google Play
        flutter build appbundle --release --flavor prod -t lib/main_prod.dart
        
        # iOS для App Store
        flutter build ios --release --flavor prod -t lib/main_prod.dart
    } else {
        flutter build apk --release --flavor $Flavor -t lib/main_${Flavor}.dart
    }
} else {
    flutter build apk --debug --flavor $Flavor -t lib/main_${Flavor}.dart
}

Write-Host "Build completed successfully!"


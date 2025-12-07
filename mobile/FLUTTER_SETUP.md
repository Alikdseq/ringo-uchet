# 🚀 Настройка Flutter проекта

## Предварительные требования

1. **Установите Flutter SDK** (>= 3.0.0):
   - Скачайте с https://flutter.dev/docs/get-started/install
   - Добавьте в PATH
   - Проверьте: `flutter doctor`

2. **Установите зависимости**:
   ```bash
   cd mobile
   flutter pub get
   ```

3. **Запустите code generation**:
   ```bash
   flutter pub run build_runner build --delete-conflicting-outputs
   ```

## 🔧 Настройка Flavors

### Android

1. Создайте файлы `google-services.json` для каждого flavor:
   - `android/app/google-services-dev.json`
   - `android/app/google-services-stage.json`
   - `android/app/google-services-prod.json`

2. В `android/app/build.gradle` уже настроены flavors:
   - `dev` - com.ringo.mobile.dev
   - `stage` - com.ringo.mobile.stage
   - `prod` - com.ringo.mobile

### iOS

1. Создайте конфигурационные схемы в Xcode для каждого flavor
2. Добавьте `GoogleService-Info.plist` для каждого flavor:
   - `ios/Runner/GoogleService-Info-Dev.plist`
   - `ios/Runner/GoogleService-Info-Stage.plist`
   - `ios/Runner/GoogleService-Info-Prod.plist`

## 🔥 Настройка Firebase

1. Создайте Firebase проект на https://console.firebase.google.com
2. Добавьте Android приложение с package names:
   - `com.ringo.mobile.dev` (dev)
   - `com.ringo.mobile.stage` (stage)
   - `com.ringo.mobile` (prod)
3. Добавьте iOS приложение
4. Скачайте конфигурационные файлы и разместите их согласно инструкциям выше
5. Включите:
   - Cloud Messaging (FCM)
   - Crashlytics
   - Analytics (опционально)

## 🏃 Запуск приложения

### Development
```bash
flutter run --flavor dev -t lib/main_dev.dart
```

### Staging
```bash
flutter run --flavor stage -t lib/main_stage.dart
```

### Production
```bash
flutter run --flavor prod -t lib/main_prod.dart
```

## 📱 Сборка для релиза

### Android APK
```bash
flutter build apk --flavor prod -t lib/main_prod.dart
```

### Android App Bundle (для Google Play)
```bash
flutter build appbundle --flavor prod -t lib/main_prod.dart
```

### iOS
```bash
flutter build ios --flavor prod -t lib/main_prod.dart
```

## 🧪 Тестирование

```bash
flutter test
```

## 📦 Структура проекта

```
lib/
├── core/              # Основные утилиты
│   ├── config/        # Конфигурация flavors, Firebase
│   ├── constants/     # Константы, цвета статусов
│   ├── errors/        # Обработка ошибок
│   ├── network/       # Dio клиент, interceptors
│   ├── storage/        # Secure storage, Hive, SQLite
│   └── theme/         # Темы, локализация
├── features/          # Feature modules
│   ├── auth/
│   ├── orders/
│   ├── catalog/
│   ├── finance/
│   └── notifications/
└── shared/            # Общие компоненты
    ├── widgets/
    ├── models/
    └── utils/
```

## ✅ Проверка готовности

После настройки проверьте:

- [ ] Flutter установлен: `flutter doctor`
- [ ] Зависимости установлены: `flutter pub get`
- [ ] Code generation выполнен: `flutter pub run build_runner build`
- [ ] Firebase настроен (для stage/prod)
- [ ] Flavors работают: `flutter run --flavor dev`

## 🐛 Решение проблем

### Ошибка: "Package not found"
```bash
flutter clean
flutter pub get
```

### Ошибка: "Build failed"
```bash
flutter clean
flutter pub get
flutter pub run build_runner build --delete-conflicting-outputs
```

### Ошибка: Firebase не инициализируется
- Проверьте наличие `google-services.json` / `GoogleService-Info.plist`
- Проверьте правильность package name / bundle ID
- Убедитесь, что Firebase проект создан


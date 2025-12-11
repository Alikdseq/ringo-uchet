import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'main_dev.dart' as dev;
import 'main_windows.dart' as windows;
import 'main_web.dart' as web;

/// Точка входа по умолчанию
/// Автоматически выбирает правильную версию в зависимости от платформы
/// Для запуска с другими flavors используйте:
/// - flutter run --flavor dev -t lib/main_dev.dart
/// - flutter run --flavor stage -t lib/main_stage.dart
/// - flutter run --flavor prod -t lib/main_prod.dart
void main() {
  // Для Web используем специальную версию
  if (kIsWeb) {
    web.main();
  } 
  // Для Windows используем специальную версию
  else if (Platform.isWindows) {
    windows.main();
  } else {
    // Для Android/iOS используем стандартную версию
    dev.main();
  }
}

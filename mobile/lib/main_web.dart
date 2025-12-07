import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import 'core/config/app_config.dart';
import 'core/network/dio_client.dart';
import 'app.dart';

/// Версия main для Web платформы
/// Ограничения: Firebase, SQLite, некоторые плагины могут работать не полностью
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Инициализация Hive для Web (используем память)
  try {
    // На web используем in-memory хранилище
    // Hive.init(null) инициализирует Hive без файловой системы
    Hive.init(null);
  } catch (e) {
    debugPrint('Hive initialization error (non-critical): $e');
    // Продолжаем работу даже если Hive не инициализирован
  }

  // Firebase инициализация пропускается на web для dev режима
  // (можно добавить позже при необходимости)

  runApp(
    ProviderScope(
      overrides: [
        // Переопределяем конфигурацию для dev flavor
        appConfigProvider.overrideWithValue(AppConfig.dev),
      ],
      child: const RingoApp(),
    ),
  );
}


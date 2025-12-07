import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import 'package:path_provider/path_provider.dart';
import 'core/config/app_config.dart';
import 'core/network/dio_client.dart';
import 'app.dart';

/// Версия main для Windows desktop
/// Некоторые функции могут быть ограничены (Firebase, SQLite, Secure Storage)
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Инициализация Hive для Windows
  try {
    final appDocDir = await getApplicationDocumentsDirectory();
    Hive.init(appDocDir.path);
  } catch (e) {
    // Если не удалось, используем временную директорию
    Hive.init((await getTemporaryDirectory()).path);
  }

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


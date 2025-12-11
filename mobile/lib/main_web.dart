import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import 'core/config/app_config.dart';
import 'core/network/dio_client.dart';
import 'core/storage/indexed_db_storage.dart';
import 'core/offline/cache_service.dart';
import 'app.dart';

/// Версия main для Web платформы
/// Ограничения: Firebase, SQLite, некоторые плагины могут работать не полностью
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Инициализация Hive для Web (используем память как fallback)
  try {
    // На web используем in-memory хранилище как fallback
    // Основное хранилище - IndexedDB через IndexedDbStorage
    Hive.init(null);
  } catch (e) {
    debugPrint('Hive initialization error (non-critical): $e');
    // Продолжаем работу даже если Hive не инициализирован
  }

  // Инициализация IndexedDB для постоянного хранения кэша на web
  try {
    final indexedDb = IndexedDbStorage();
    await indexedDb.init();
    debugPrint('IndexedDB initialized successfully');
  } catch (e) {
    debugPrint('IndexedDB initialization error (non-critical): $e');
    // Продолжаем работу с localStorage fallback
  }

  // Firebase инициализация пропускается на web для dev режима
  // (можно добавить позже при необходимости)

  runApp(
    ProviderScope(
      overrides: [
        // Используем production конфигурацию
        appConfigProvider.overrideWithValue(AppConfig.prod),
      ],
      child: const RingoApp(),
    ),
  );
}


import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:hive_flutter/hive_flutter.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as path;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../constants/app_constants.dart';

/// Провайдер local storage (Hive)
final localStorageProvider = Provider<LocalStorage>((ref) {
  return LocalStorage();
});

/// Провайдер SQLite database
final sqliteProvider = FutureProvider<Database>((ref) async {
  final dbPath = await getDatabasesPath();
  final db = await openDatabase(
    path.join(dbPath, 'ringo.db'),
    version: 2, // Увеличиваем версию для миграции
    onCreate: (db, version) async {
      // Создание таблиц для оффлайн очереди
      await db.execute('''
        CREATE TABLE offline_queue (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          action TEXT NOT NULL,
          endpoint TEXT NOT NULL,
          method TEXT NOT NULL,
          data TEXT NOT NULL,
          created_at INTEGER NOT NULL,
          retry_count INTEGER DEFAULT 0,
          error_message TEXT
        )
      ''');

      // Создание таблиц для кэша
      await db.execute('''
        CREATE TABLE cache (
          key TEXT PRIMARY KEY,
          value TEXT NOT NULL,
          expires_at INTEGER NOT NULL
        )
      ''');
    },
    onUpgrade: (db, oldVersion, newVersion) async {
      // Миграция с версии 1 на 2
      if (oldVersion < 2) {
        await db.execute('''
          ALTER TABLE offline_queue 
          ADD COLUMN retry_count INTEGER DEFAULT 0
        ''');
        await db.execute('''
          ALTER TABLE offline_queue 
          ADD COLUMN error_message TEXT
        ''');
      }
    },
  );
  return db;
});

/// Класс для работы с локальным хранилищем (Hive)
class LocalStorage {
  static const String _equipmentBox = 'equipment';
  static const String _servicesBox = 'services';
  static const String _materialsBox = 'materials';
  static const String _clientsBox = 'clients';

  /// Инициализация Hive
  Future<void> init() async {
    try {
      if (kIsWeb) {
        // На web Hive уже инициализирован в main_web.dart
        // Просто создаём box если нужно
      } else {
        await Hive.initFlutter();
      }
    } catch (e) {
      debugPrint('Hive init error (non-critical): $e');
      // Продолжаем работу даже если Hive не инициализирован
    }
  }

  /// Получить box для оборудования
  Future<Box> getEquipmentBox() async {
    if (!Hive.isBoxOpen(_equipmentBox)) {
      return await Hive.openBox(_equipmentBox);
    }
    return Hive.box(_equipmentBox);
  }

  /// Получить box для услуг
  Future<Box> getServicesBox() async {
    if (!Hive.isBoxOpen(_servicesBox)) {
      return await Hive.openBox(_servicesBox);
    }
    return Hive.box(_servicesBox);
  }

  /// Получить box для материалов
  Future<Box> getMaterialsBox() async {
    if (!Hive.isBoxOpen(_materialsBox)) {
      return await Hive.openBox(_materialsBox);
    }
    return Hive.box(_materialsBox);
  }

  /// Получить box для клиентов
  Future<Box> getClientsBox() async {
    if (!Hive.isBoxOpen(_clientsBox)) {
      return await Hive.openBox(_clientsBox);
    }
    return Hive.box(_clientsBox);
  }

  /// Сохранить кэш с временем истечения
  Future<void> saveCache(String key, dynamic value,
      {int? expirationHours}) async {
    final box = await getEquipmentBox(); // Используем любой box для кэша
    final expiration = DateTime.now()
        .add(Duration(
            hours: expirationHours ?? AppConstants.cacheExpirationHours))
        .millisecondsSinceEpoch;
    await box.put('${key}_expires', expiration);
    await box.put(key, value);
  }

  /// Получить кэш, если он не истёк
  Future<dynamic> getCache(String key) async {
    final box = await getEquipmentBox();
    final expiresAt = box.get('${key}_expires');
    if (expiresAt == null ||
        expiresAt > DateTime.now().millisecondsSinceEpoch) {
      return box.get(key);
    }
    // Кэш истёк, удаляем
    await box.delete(key);
    await box.delete('${key}_expires');
    return null;
  }

  /// Очистить весь кэш
  Future<void> clearCache() async {
    final boxes = [
      await getEquipmentBox(),
      await getServicesBox(),
      await getMaterialsBox(),
      await getClientsBox(),
    ];
    for (final box in boxes) {
      await box.clear();
    }
  }
}

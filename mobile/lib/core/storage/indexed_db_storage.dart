import 'dart:html' as html;
import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;

/// Сервис для работы с localStorage на web платформе
/// Используется для постоянного хранения кэша между сессиями
/// Использует localStorage как основное хранилище (проще и надежнее чем IndexedDB)
class IndexedDbStorage {
  /// Инициализация хранилища
  Future<void> init() async {
    if (!kIsWeb) return;
    // localStorage доступен сразу, инициализация не требуется
  }

  /// Сохранить данные
  Future<void> put(String key, dynamic value) async {
    if (!kIsWeb) return;

    try {
      html.window.localStorage[key] = jsonEncode(value);
    } catch (e) {
      debugPrint('Storage put error: $e');
      // Если localStorage переполнен, пытаемся очистить старые данные
      try {
        _cleanOldData();
        html.window.localStorage[key] = jsonEncode(value);
      } catch (e2) {
        debugPrint('Storage put error after cleanup: $e2');
      }
    }
  }

  /// Получить данные
  Future<dynamic> get(String key) async {
    if (!kIsWeb) return null;

    try {
      final data = html.window.localStorage[key];
      if (data != null) {
        return jsonDecode(data);
      }
      return null;
    } catch (e) {
      debugPrint('Storage get error: $e');
      return null;
    }
  }

  /// Удалить данные
  Future<void> delete(String key) async {
    if (!kIsWeb) return;

    try {
      html.window.localStorage.remove(key);
    } catch (e) {
      debugPrint('Storage delete error: $e');
    }
  }

  /// Очистить все данные
  Future<void> clear() async {
    if (!kIsWeb) return;

    try {
      html.window.localStorage.clear();
    } catch (e) {
      debugPrint('Storage clear error: $e');
    }
  }

  /// Очистка старых данных при переполнении
  void _cleanOldData() {
    try {
      // Удаляем самые старые записи кэша (по timestamp)
      final keys = html.window.localStorage.keys.toList();
      final cacheKeys = keys.where((k) => k.startsWith('orders') || k.startsWith('queue_')).toList();
      
      if (cacheKeys.length > 100) {
        // Удаляем половину самых старых записей
        cacheKeys.sort();
        for (int i = 0; i < cacheKeys.length ~/ 2; i++) {
          html.window.localStorage.remove(cacheKeys[i]);
        }
      }
    } catch (e) {
      debugPrint('Clean old data error: $e');
    }
  }
}


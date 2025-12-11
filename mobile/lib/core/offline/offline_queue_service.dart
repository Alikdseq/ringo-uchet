import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../storage/local_storage.dart';
import '../storage/indexed_db_storage.dart';

// Условный импорт для sqflite (не работает на web)
import 'package:sqflite/sqflite.dart' if (dart.library.html) 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Провайдер сервиса оффлайн очереди
final offlineQueueServiceProvider = Provider<OfflineQueueService>((ref) {
  return OfflineQueueService(ref);
});

/// Тип действия в очереди
enum OfflineActionType {
  createOrder,
  updateOrder,
  changeStatus,
  uploadPhoto,
  deleteOrder,
}

/// Модель элемента очереди
class OfflineQueueItem {
  final int? id;
  final OfflineActionType action;
  final String endpoint;
  final String method;
  final Map<String, dynamic> data;
  final DateTime createdAt;
  final int? retryCount;
  final String? errorMessage;

  const OfflineQueueItem({
    this.id,
    required this.action,
    required this.endpoint,
    required this.method,
    required this.data,
    required this.createdAt,
    this.retryCount,
    this.errorMessage,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'action': action.toString().split('.').last,
      'endpoint': endpoint,
      'method': method,
      'data': jsonEncode(data),
      'created_at': createdAt.millisecondsSinceEpoch,
      'retry_count': retryCount ?? 0,
      'error_message': errorMessage,
    };
  }

  factory OfflineQueueItem.fromJson(Map<String, dynamic> json) {
    final actionStr = json['action'] as String;
    OfflineActionType actionType;
    try {
      actionType = OfflineActionType.values.firstWhere(
        (e) => e.toString().split('.').last == actionStr,
      );
    } catch (e) {
      // Fallback на createOrder если не найдено
      actionType = OfflineActionType.createOrder;
    }

    return OfflineQueueItem(
      id: json['id'] as int?,
      action: actionType,
      endpoint: json['endpoint'] as String,
      method: json['method'] as String,
      data: jsonDecode(json['data'] as String) as Map<String, dynamic>,
      createdAt: DateTime.fromMillisecondsSinceEpoch(json['created_at'] as int),
      retryCount: json['retry_count'] as int?,
      errorMessage: json['error_message'] as String?,
    );
  }
}

/// Сервис для управления оффлайн очередью
class OfflineQueueService {
  final Ref _ref;
  IndexedDbStorage? _indexedDb;
  bool _indexedDbInitialized = false;
  int _nextId = 1;

  OfflineQueueService(this._ref) {
    if (kIsWeb) {
      _initIndexedDb();
    }
  }

  /// Инициализация IndexedDB для web
  Future<void> _initIndexedDb() async {
    if (!kIsWeb || _indexedDbInitialized) return;
    try {
      _indexedDb = IndexedDbStorage();
      await _indexedDb!.init();
      // Загружаем последний ID
      final lastId = await _indexedDb!.get('_queue_last_id') as int?;
      _nextId = (lastId ?? 0) + 1;
      _indexedDbInitialized = true;
    } catch (e) {
      // IndexedDB недоступен
    }
  }

  /// Получить базу данных
  Future<dynamic> _getDatabase() async {
    // На web используем IndexedDB
    if (kIsWeb) {
      if (!_indexedDbInitialized) {
        await _initIndexedDb();
      }
      if (_indexedDb == null) {
        throw UnsupportedError('IndexedDB не доступен на этой платформе');
      }
      return _indexedDb;
    }
    // На мобильных платформах используем SQLite
    final db = await _ref.read(sqliteProvider.future);
    return db;
  }

  /// Добавить действие в очередь
  Future<int> addToQueue({
    required OfflineActionType action,
    required String endpoint,
    required String method,
    required Map<String, dynamic> data,
  }) async {
    final item = OfflineQueueItem(
      action: action,
      endpoint: endpoint,
      method: method,
      data: data,
      createdAt: DateTime.now(),
    );

    if (kIsWeb && _indexedDbInitialized && _indexedDb != null) {
      // Используем IndexedDB для web
      final id = _nextId++;
      await _indexedDb!.put('_queue_last_id', _nextId);
      await _indexedDb!.put('queue_$id', item.toJson());
      return id;
    }

    // Используем SQLite для мобильных платформ
    final db = await _getDatabase();
    return await db.insert(
      'offline_queue',
      {
        'action': item.action.toString().split('.').last,
        'endpoint': item.endpoint,
        'method': item.method,
        'data': jsonEncode(item.data),
        'created_at': item.createdAt.millisecondsSinceEpoch,
        'retry_count': 0,
      },
    );
  }

  /// Получить все элементы очереди
  Future<List<OfflineQueueItem>> getQueueItems() async {
    if (kIsWeb && _indexedDbInitialized && _indexedDb != null) {
      // Используем IndexedDB для web
      final items = <OfflineQueueItem>[];
      try {
        // Получаем все ключи, начинающиеся с 'queue_'
        // Note: IndexedDB не поддерживает прямые запросы по префиксу,
        // поэтому используем localStorage как fallback или храним список ID
        final lastId = await _indexedDb!.get('_queue_last_id') as int? ?? 0;
        for (int i = 1; i <= lastId; i++) {
          final data = await _indexedDb!.get('queue_$i');
          if (data != null) {
            try {
              items.add(OfflineQueueItem.fromJson(data as Map<String, dynamic>));
            } catch (e) {
              // Пропускаем поврежденные записи
            }
          }
        }
        // Сортируем по времени создания
        items.sort((a, b) => a.createdAt.compareTo(b.createdAt));
        return items;
      } catch (e) {
        return [];
      }
    }

    // Используем SQLite для мобильных платформ
    final db = await _getDatabase();
    final results = await db.query(
      'offline_queue',
      orderBy: 'created_at ASC',
    );

    return results.map((json) => OfflineQueueItem.fromJson(json)).toList();
  }

  /// Получить элемент очереди по ID
  Future<OfflineQueueItem?> getQueueItem(int id) async {
    final db = await _getDatabase();
    final results = await db.query(
      'offline_queue',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );

    if (results.isEmpty) return null;
    return OfflineQueueItem.fromJson(results.first);
  }

  /// Удалить элемент из очереди
  Future<void> removeFromQueue(int id) async {
    if (kIsWeb && _indexedDbInitialized && _indexedDb != null) {
      // Используем IndexedDB для web
      await _indexedDb!.delete('queue_$id');
      return;
    }

    // Используем SQLite для мобильных платформ
    final db = await _getDatabase();
    await db.delete(
      'offline_queue',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Обновить количество попыток
  Future<void> updateRetryCount(int id, int retryCount, {String? errorMessage}) async {
    final db = await _getDatabase();
    await db.update(
      'offline_queue',
      {
        'retry_count': retryCount,
        if (errorMessage != null) 'error_message': errorMessage,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Очистить очередь
  Future<void> clearQueue() async {
    final db = await _getDatabase();
    await db.delete('offline_queue');
  }

  /// Получить количество элементов в очереди
  Future<int> getQueueCount() async {
    if (kIsWeb && _indexedDbInitialized && _indexedDb != null) {
      // Используем IndexedDB для web
      try {
        final items = await getQueueItems();
        return items.length;
      } catch (e) {
        return 0;
      }
    }
    
    if (kIsWeb) return 0; // На web без IndexedDB всегда 0
    
    try {
      final db = await _getDatabase();
      final result = await db.rawQuery('SELECT COUNT(*) as count FROM offline_queue');
      if (result.isEmpty) return 0;
      return result.first['count'] as int? ?? 0;
    } catch (e) {
      return 0;
    }
  }
}


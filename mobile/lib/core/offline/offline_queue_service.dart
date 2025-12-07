import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../storage/local_storage.dart';

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

  OfflineQueueService(this._ref);

  /// Получить базу данных
  Future<dynamic> _getDatabase() async {
    // На web используем заглушку, так как sqflite не работает
    if (kIsWeb) {
      throw UnsupportedError('SQLite не поддерживается на web платформе. Используйте Android эмулятор для полной функциональности.');
    }
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
    final db = await _getDatabase();
    final item = OfflineQueueItem(
      action: action,
      endpoint: endpoint,
      method: method,
      data: data,
      createdAt: DateTime.now(),
    );

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
    if (kIsWeb) return 0; // На web всегда 0
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


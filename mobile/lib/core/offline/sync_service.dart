import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../network/dio_client.dart';
import '../network/connectivity_service.dart';
import 'offline_queue_service.dart';

/// Провайдер сервиса синхронизации
final syncServiceProvider = Provider<SyncService>((ref) {
  return SyncService(ref);
});

/// Сервис для синхронизации оффлайн очереди
class SyncService {
  final Ref _ref;
  static const int maxRetries = 3;

  SyncService(this._ref);

  /// Синхронизировать очередь при появлении сети
  Future<void> syncQueue() async {
    final connectivityService = _ref.read(connectivityServiceProvider);
    final hasConnection = await connectivityService.hasConnection();

    if (!hasConnection) {
      return; // Нет подключения, синхронизация невозможна
    }

    final queueService = _ref.read(offlineQueueServiceProvider);
    final items = await queueService.getQueueItems();

    if (items.isEmpty) {
      return; // Очередь пуста
    }

    final dio = _ref.read(dioClientProvider);

    for (final item in items) {
      try {
        // Пытаемся выполнить запрос
        Response? response;
        
        switch (item.method.toUpperCase()) {
          case 'POST':
            response = await dio.post(
              item.endpoint,
              data: item.data,
            );
            break;
          case 'PATCH':
          case 'PUT':
            response = await dio.patch(
              item.endpoint,
              data: item.data,
            );
            break;
          case 'DELETE':
            response = await dio.delete(item.endpoint);
            break;
        }

        // Если запрос успешен, удаляем из очереди
        if (response != null && response.statusCode != null && response.statusCode! < 400) {
          await queueService.removeFromQueue(item.id!);
        }
      } on DioException catch (e) {
        // Обрабатываем ошибки сети
        if (e.type == DioExceptionType.connectionError ||
            e.type == DioExceptionType.connectionTimeout ||
            e.error is SocketException) {
          // Нет сети, оставляем в очереди
          final retryCount = (item.retryCount ?? 0) + 1;
          if (retryCount < maxRetries) {
            await queueService.updateRetryCount(
              item.id!,
              retryCount,
              errorMessage: 'Ошибка сети: ${e.message}',
            );
          } else {
            // Превышено количество попыток, оставляем с ошибкой
            await queueService.updateRetryCount(
              item.id!,
              retryCount,
              errorMessage: 'Превышено количество попыток',
            );
          }
        } else {
          // Другая ошибка (например, 400, 401, 403)
          // Удаляем из очереди, так как это не проблема сети
          await queueService.removeFromQueue(item.id!);
        }
      } catch (e) {
        // Неизвестная ошибка
        final retryCount = (item.retryCount ?? 0) + 1;
        if (retryCount < maxRetries) {
          await queueService.updateRetryCount(
            item.id!,
            retryCount,
            errorMessage: 'Ошибка: ${e.toString()}',
          );
        } else {
          await queueService.removeFromQueue(item.id!);
        }
      }
    }
  }

  /// Автоматическая синхронизация при появлении сети
  void startAutoSync() {
    final connectivityService = _ref.read(connectivityServiceProvider);
    connectivityService.statusStream.listen((status) {
      if (status == ConnectionStatus.connected) {
        syncQueue();
      }
    });
  }
}


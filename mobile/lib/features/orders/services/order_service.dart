import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/offline/offline_queue_service.dart';
import '../../../core/offline/cache_service.dart';
import '../../../core/errors/app_exception.dart';
import '../models/order_models.dart';

/// Провайдер сервиса заказов
final orderServiceProvider = Provider<OrderService>((ref) {
  final dio = ref.watch(dioClientProvider);
  return OrderService(dio, ref);
});

/// Сервис для работы с заказами
class OrderService {
  final Dio _dio;
  final Ref _ref;

  OrderService(this._dio, this._ref);

  /// Получить список заказов
  Future<List<Order>> getOrders({
    OrderStatus? status,
    String? search,
    int? page,
    int? pageSize,
    bool useCache = true,
  }) async {
    try {
      final queryParams = <String, dynamic>{};
      if (status != null) {
        queryParams['status'] = status.toString().split('.').last.toUpperCase();
      }
      if (search != null && search.isNotEmpty) {
        queryParams['search'] = search;
      }
      if (page != null) {
        queryParams['page'] = page;
      }
      if (pageSize != null) {
        queryParams['page_size'] = pageSize;
      }

      final response = await _dio.get('/orders/', queryParameters: queryParams);

      List<Order> orders;
      if (response.data is List) {
        orders = (response.data as List)
            .map((json) => Order.fromJson(json as Map<String, dynamic>))
            .toList();
      } else if (response.data is Map && response.data.containsKey('results')) {
        orders = (response.data['results'] as List)
            .map((json) => Order.fromJson(json as Map<String, dynamic>))
            .toList();
      } else {
        orders = [];
      }

      // Кэшируем результат
      if (useCache) {
        final cacheService = _ref.read(cacheServiceProvider);
        await cacheService.cacheOrders(orders.map((o) => o.toJson()).toList());
      }

      return orders;
    } on DioException catch (e) {
      // Если нет сети, пытаемся получить из кэша
      if (e.type == DioExceptionType.connectionError ||
          e.error is SocketException) {
        if (useCache) {
          final cacheService = _ref.read(cacheServiceProvider);
          final cached = await cacheService.getCachedOrders();
          if (cached != null) {
            return cached
                .map((json) => Order.fromJson(json as Map<String, dynamic>))
                .toList();
          }
        }
      }
      throw _handleError(e);
    } catch (e) {
      if (e is AppException) rethrow;
      throw AppException.unknown('Неизвестная ошибка: ${e.toString()}');
    }
  }

  /// Получить заказ по ID
  Future<Order> getOrder(String id) async {
    try {
      final response = await _dio.get('/orders/$id/');
      return Order.fromJson(response.data);
    } on DioException catch (e) {
      throw _handleError(e);
    } catch (e) {
      if (e is AppException) rethrow;
      throw AppException.unknown('Неизвестная ошибка: ${e.toString()}');
    }
  }

  /// Создать заказ
  Future<Order> createOrder(OrderRequest request) async {
    try {
      final requestData = request.toJson();
      // Логируем данные для отладки (можно убрать в продакшене)
      print('OrderRequest JSON: ${requestData}');
      print('OrderRequest items count: ${requestData['items']?.length ?? 0}');
      if (requestData['items'] != null && (requestData['items'] as List).isNotEmpty) {
        print('OrderRequest first item: ${requestData['items'][0]}');
      }
      final response = await _dio.post('/orders/', data: requestData);
      final order = Order.fromJson(response.data);

      // Обновляем кэш
      final cacheService = _ref.read(cacheServiceProvider);
      final cached = await cacheService.getCachedOrders();
      if (cached != null) {
        cached.insert(0, order.toJson());
        await cacheService.cacheOrders(cached);
      }

      return order;
    } on DioException catch (e) {
      // Логируем детали ошибки для отладки
      if (e.response != null) {
        print('Error response status: ${e.response?.statusCode}');
        print('Error response data: ${e.response?.data}');
        print('Error response headers: ${e.response?.headers}');
        // Детальная информация об ошибке валидации
        if (e.response?.statusCode == 400 || e.response?.statusCode == 422) {
          final errorData = e.response?.data;
          if (errorData is Map) {
            print('Validation errors:');
            errorData.forEach((key, value) {
              print('  $key: $value');
            });
          }
        }
      } else {
        print('DioException without response: ${e.message}');
        print('Error type: ${e.type}');
      }
      // Если нет сети, добавляем в очередь
      if (e.type == DioExceptionType.connectionError ||
          e.error is SocketException) {
        final queueService = _ref.read(offlineQueueServiceProvider);
        await queueService.addToQueue(
          action: OfflineActionType.createOrder,
          endpoint: '/orders/',
          method: 'POST',
          data: request.toJson(),
        );
        throw AppException.network(
            'Заказ добавлен в очередь для синхронизации');
      }
      throw _handleError(e);
    } catch (e) {
      if (e is AppException) rethrow;
      throw AppException.unknown('Неизвестная ошибка: ${e.toString()}');
    }
  }

  /// Обновить заказ
  Future<Order> updateOrder(String id, OrderRequest request) async {
    try {
      final response = await _dio.patch('/orders/$id/', data: request.toJson());
      return Order.fromJson(response.data);
    } on DioException catch (e) {
      throw _handleError(e);
    } catch (e) {
      if (e is AppException) rethrow;
      throw AppException.unknown('Неизвестная ошибка: ${e.toString()}');
    }
  }

  /// Изменить статус заказа
  Future<Order> changeOrderStatus(String id, OrderStatusRequest request) async {
    try {
      await _dio.patch('/orders/$id/status/', data: request.toJson());
      // Ответ содержит статус и логи, но нам нужен полный заказ
      final order = await getOrder(id);

      // Обновляем кэш
      final cacheService = _ref.read(cacheServiceProvider);
      final cached = await cacheService.getCachedOrders();
      if (cached != null) {
        final index = cached.indexWhere((o) => (o as Map)['id'] == id);
        if (index != -1) {
          cached[index] = order.toJson();
          await cacheService.cacheOrders(cached);
        }
      }

      return order;
    } on DioException catch (e) {
      // Если нет сети, добавляем в очередь
      if (e.type == DioExceptionType.connectionError ||
          e.error is SocketException) {
        final queueService = _ref.read(offlineQueueServiceProvider);
        await queueService.addToQueue(
          action: OfflineActionType.changeStatus,
          endpoint: '/orders/$id/status/',
          method: 'PATCH',
          data: request.toJson(),
        );
        throw AppException.network(
            'Изменение статуса добавлено в очередь для синхронизации');
      }
      throw _handleError(e);
    } catch (e) {
      if (e is AppException) rethrow;
      throw AppException.unknown('Неизвестная ошибка: ${e.toString()}');
    }
  }

  /// Получить предпросмотр расчёта стоимости
  Future<OrderPricePreviewResponse> getPricePreview(
      String id, OrderPricePreviewRequest request) async {
    try {
      final response = await _dio.post('/orders/$id/calculate/preview/',
          data: request.toJson());
      return OrderPricePreviewResponse.fromJson(response.data);
    } on DioException catch (e) {
      throw _handleError(e);
    } catch (e) {
      if (e is AppException) rethrow;
      throw AppException.unknown('Неизвестная ошибка: ${e.toString()}');
    }
  }

  /// Получить presigned URL для загрузки файла
  Future<Map<String, dynamic>> getUploadUrl(
      String id, String fileName, String contentType) async {
    try {
      final response = await _dio.post(
        '/orders/$id/attachments/',
        data: {
          'file_name': fileName,
          'content_type': contentType,
        },
      );
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw _handleError(e);
    } catch (e) {
      if (e is AppException) rethrow;
      throw AppException.unknown('Неизвестная ошибка: ${e.toString()}');
    }
  }

  /// Сгенерировать счёт
  Future<Map<String, dynamic>> generateInvoice(String id) async {
    try {
      final response = await _dio.post('/orders/$id/generate_invoice/');
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw _handleError(e);
    } catch (e) {
      if (e is AppException) rethrow;
      throw AppException.unknown('Неизвестная ошибка: ${e.toString()}');
    }
  }

  /// Завершить заявку с добавлением элементов номенклатуры
  Future<Order> completeOrder(String id, Map<String, dynamic> data) async {
    try {
      final response = await _dio.post('/orders/$id/complete/', data: data);
      final order = Order.fromJson(response.data);

      // Обновляем кэш
      final cacheService = _ref.read(cacheServiceProvider);
      final cached = await cacheService.getCachedOrders();
      if (cached != null) {
        final index = cached.indexWhere((o) => (o as Map)['id'] == id);
        if (index != -1) {
          cached[index] = order.toJson();
          await cacheService.cacheOrders(cached);
        }
      }

      return order;
    } on DioException catch (e) {
      throw _handleError(e);
    } catch (e) {
      if (e is AppException) rethrow;
      throw AppException.unknown('Неизвестная ошибка: ${e.toString()}');
    }
  }

  /// Получить PDF чек для завершенной заявки
  Future<List<int>> getReceipt(String id) async {
    try {
      final response = await _dio.get(
        '/orders/$id/receipt/',
        options: Options(
          responseType: ResponseType.bytes,
        ),
      );
      
      // Обрабатываем ответ в зависимости от типа данных
      if (response.data is List<int>) {
        return response.data as List<int>;
      } else if (response.data is List) {
        // Если пришел List, преобразуем в List<int>
        return (response.data as List).cast<int>();
      } else {
        throw AppException.unknown('Неожиданный формат ответа от сервера');
      }
    } on DioException catch (e) {
      throw _handleError(e);
    } catch (e) {
      if (e is AppException) rethrow;
      throw AppException.unknown('Неизвестная ошибка: ${e.toString()}');
    }
  }

  /// Удалить заказ
  Future<void> deleteOrder(String id) async {
    try {
      await _dio.delete('/orders/$id/');
    } on DioException catch (e) {
      throw _handleError(e);
    } catch (e) {
      if (e is AppException) rethrow;
      throw AppException.unknown('Неизвестная ошибка: ${e.toString()}');
    }
  }

  AppException _handleError(DioException error) {
    if (error.error is AppException) {
      return error.error as AppException;
    }

    switch (error.response?.statusCode) {
      case 400:
        return AppException.badRequest(
          _extractMessage(error.response?.data) ?? 'Неверный запрос',
        );
      case 401:
        return AppException.unauthorized('Требуется авторизация');
      case 403:
        return AppException.forbidden('Доступ запрещён');
      case 404:
        return AppException.notFound('Заказ не найден');
      case 422:
        return AppException.validation(
          _extractMessage(error.response?.data) ?? 'Ошибка валидации',
          _extractErrors(error.response?.data),
        );
      case 500:
      case 502:
      case 503:
        return AppException.server('Ошибка сервера');
      default:
        return AppException.network('Ошибка подключения к серверу');
    }
  }

  String? _extractMessage(dynamic data) {
    if (data is Map<String, dynamic>) {
      return data['detail'] as String? ?? data['message'] as String?;
    }
    return null;
  }

  Map<String, dynamic>? _extractErrors(dynamic data) {
    if (data is Map<String, dynamic> && data.containsKey('errors')) {
      return data['errors'] as Map<String, dynamic>?;
    }
    return null;
  }
}

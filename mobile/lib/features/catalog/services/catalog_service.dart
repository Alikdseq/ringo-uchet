import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/offline/cache_service.dart';
import '../../../core/errors/app_exception.dart';
import '../models/catalog_models.dart';

/// Провайдер сервиса каталога
final catalogServiceProvider = Provider<CatalogService>((ref) {
  final dio = ref.watch(dioClientProvider);
  return CatalogService(dio, ref);
});

/// Сервис для работы с каталогом
class CatalogService {
  final Dio _dio;
  final Ref _ref;

  CatalogService(this._dio, this._ref);

  /// Получить список техники
  Future<List<Equipment>> getEquipment({
    String? status,
    String? search,
  }) async {
    try {
      final queryParams = <String, dynamic>{};
      if (status != null) {
        queryParams['status'] = status;
      }
      if (search != null && search.isNotEmpty) {
        queryParams['search'] = search;
      }

      final response = await _dio.get('/equipment/', queryParameters: queryParams);
      
      List<Equipment> equipmentList;
      if (response.data is List) {
        equipmentList = (response.data as List)
            .map((json) => Equipment.fromJson(json as Map<String, dynamic>))
            .toList();
      } else if (response.data is Map && response.data.containsKey('results')) {
        equipmentList = (response.data['results'] as List)
            .map((json) => Equipment.fromJson(json as Map<String, dynamic>))
            .toList();
      } else {
        equipmentList = [];
      }

      // Кэшируем результат
      final cacheService = _ref.read(cacheServiceProvider);
      await cacheService.cacheEquipment(equipmentList.map((e) => e.toJson()).toList());

      return equipmentList;
    } on DioException catch (e) {
      // Если нет сети, пытаемся получить из кэша
      if (e.type == DioExceptionType.connectionError || e.error is SocketException) {
        final cacheService = _ref.read(cacheServiceProvider);
        final cached = await cacheService.getCachedEquipment();
        if (cached != null) {
          return cached
              .map((json) => Equipment.fromJson(json as Map<String, dynamic>))
              .toList();
        }
      }
      throw _handleError(e);
    } catch (e) {
      if (e is AppException) rethrow;
      throw AppException.unknown('Неизвестная ошибка: ${e.toString()}');
    }
  }

  /// Получить список услуг
  Future<List<ServiceItem>> getServices({
    int? category,
    String? search,
  }) async {
    try {
      final queryParams = <String, dynamic>{};
      if (category != null) {
        queryParams['category'] = category;
      }
      if (search != null && search.isNotEmpty) {
        queryParams['search'] = search;
      }

      final response = await _dio.get('/services/', queryParameters: queryParams);
      
      List<ServiceItem> servicesList;
      if (response.data is List) {
        servicesList = (response.data as List)
            .map((json) => ServiceItem.fromJson(json as Map<String, dynamic>))
            .toList();
      } else if (response.data is Map && response.data.containsKey('results')) {
        servicesList = (response.data['results'] as List)
            .map((json) => ServiceItem.fromJson(json as Map<String, dynamic>))
            .toList();
      } else {
        servicesList = [];
      }

      // Кэшируем результат
      final cacheService = _ref.read(cacheServiceProvider);
      await cacheService.cacheServices(servicesList.map((s) => s.toJson()).toList());

      return servicesList;
    } on DioException catch (e) {
      // Если нет сети, пытаемся получить из кэша
      if (e.type == DioExceptionType.connectionError || e.error is SocketException) {
        final cacheService = _ref.read(cacheServiceProvider);
        final cached = await cacheService.getCachedServices();
        if (cached != null) {
          return cached
              .map((json) => ServiceItem.fromJson(json as Map<String, dynamic>))
              .toList();
        }
      }
      throw _handleError(e);
    } catch (e) {
      if (e is AppException) rethrow;
      throw AppException.unknown('Неизвестная ошибка: ${e.toString()}');
    }
  }

  /// Получить список материалов
  Future<List<MaterialItem>> getMaterials({
    String? search,
    String? category,
  }) async {
    try {
      final queryParams = <String, dynamic>{};
      if (search != null && search.isNotEmpty) {
        queryParams['search'] = search;
      }
      if (category != null) {
        queryParams['category'] = category;
      }

      final response = await _dio.get('/materials/', queryParameters: queryParams);
      
      List<MaterialItem> materialsList;
      if (response.data is List) {
        materialsList = (response.data as List)
            .map((json) => MaterialItem.fromJson(json as Map<String, dynamic>))
            .toList();
      } else if (response.data is Map && response.data.containsKey('results')) {
        materialsList = (response.data['results'] as List)
            .map((json) => MaterialItem.fromJson(json as Map<String, dynamic>))
            .toList();
      } else {
        materialsList = [];
      }

      // Кэшируем результат
      final cacheService = _ref.read(cacheServiceProvider);
      await cacheService.cacheMaterials(materialsList.map((m) => m.toJson()).toList());

      return materialsList;
    } on DioException catch (e) {
      // Если нет сети, пытаемся получить из кэша
      if (e.type == DioExceptionType.connectionError || e.error is SocketException) {
        final cacheService = _ref.read(cacheServiceProvider);
        final cached = await cacheService.getCachedMaterials();
        if (cached != null) {
          return cached
              .map((json) => MaterialItem.fromJson(json as Map<String, dynamic>))
              .toList();
        }
      }
      throw _handleError(e);
    } catch (e) {
      if (e is AppException) rethrow;
      throw AppException.unknown('Неизвестная ошибка: ${e.toString()}');
    }
  }

  /// Получить список навесок
  Future<List<Attachment>> getAttachments({
    String? search,
  }) async {
    try {
      final queryParams = <String, dynamic>{};
      if (search != null && search.isNotEmpty) {
        queryParams['search'] = search;
      }

      final response = await _dio.get('/attachments/', queryParameters: queryParams);
      
      List<Attachment> attachmentsList;
      if (response.data is List) {
        attachmentsList = (response.data as List)
            .map((json) => Attachment.fromJson(json as Map<String, dynamic>))
            .toList();
      } else if (response.data is Map && response.data.containsKey('results')) {
        attachmentsList = (response.data['results'] as List)
            .map((json) => Attachment.fromJson(json as Map<String, dynamic>))
            .toList();
      } else {
        attachmentsList = [];
      }

      return attachmentsList;
    } on DioException catch (e) {
      throw _handleError(e);
    } catch (e) {
      if (e is AppException) rethrow;
      throw AppException.unknown('Неизвестная ошибка: ${e.toString()}');
    }
  }

  /// Получить список клиентов
  Future<List<Map<String, dynamic>>> getClients({
    String? search,
  }) async {
    try {
      final queryParams = <String, dynamic>{};
      if (search != null && search.isNotEmpty) {
        queryParams['search'] = search;
      }

      final response = await _dio.get('/clients/', queryParameters: queryParams);
      
      List<Map<String, dynamic>> clientsList;
      if (response.data is List) {
        clientsList = (response.data as List).cast<Map<String, dynamic>>();
      } else if (response.data is Map && response.data.containsKey('results')) {
        clientsList = (response.data['results'] as List).cast<Map<String, dynamic>>();
      } else {
        clientsList = [];
      }

      // Кэшируем результат
      final cacheService = _ref.read(cacheServiceProvider);
      await cacheService.cacheClients(clientsList);

      return clientsList;
    } on DioException catch (e) {
      // Если нет сети, пытаемся получить из кэша
      if (e.type == DioExceptionType.connectionError || e.error is SocketException) {
        final cacheService = _ref.read(cacheServiceProvider);
        final cached = await cacheService.getCachedClients();
        if (cached != null) {
          return cached.cast<Map<String, dynamic>>();
        }
      }
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
        return AppException.notFound('Ресурс не найден');
      case 500:
      case 502:
      case 503:
        return AppException.server('Ошибка сервера');
      default:
        return AppException.network('Ошибка подключения к серверу');
    }
  }

  /// Создать технику
  Future<Equipment> createEquipment({
    required String code,
    required String name,
    String? description,
    required double hourlyRate,
    double? dailyRate,
  }) async {
    try {
      final response = await _dio.post('/equipment/', data: {
        'code': code,
        'name': name,
        if (description != null) 'description': description,
        'hourly_rate': hourlyRate.toStringAsFixed(2),
        if (dailyRate != null) 'daily_rate': dailyRate.toStringAsFixed(2),
        'status': 'available',
      });
      final equipment = Equipment.fromJson(response.data as Map<String, dynamic>);
      
      // Мгновенно обновляем кэш - добавляем новое оборудование в начало списка
      final cacheService = _ref.read(cacheServiceProvider);
      final cached = await cacheService.getCachedEquipment();
      if (cached != null) {
        // Удаляем элемент с таким же ID, если он есть (на случай дубликатов)
        cached.removeWhere((e) => (e as Map)['id'] == equipment.id);
        // Добавляем новое оборудование в начало списка
        cached.insert(0, equipment.toJson());
        await cacheService.cacheEquipment(cached);
      } else {
        // Если кэша нет, создаем новый с этим оборудованием
        await cacheService.cacheEquipment([equipment.toJson()]);
      }
      
      return equipment;
    } on DioException catch (e) {
      throw _handleError(e);
    } catch (e) {
      if (e is AppException) rethrow;
      throw AppException.unknown('Неизвестная ошибка: ${e.toString()}');
    }
  }

  /// Обновить технику
  Future<Equipment> updateEquipment(
    int id, {
    String? code,
    String? name,
    String? description,
    double? hourlyRate,
    double? dailyRate,
  }) async {
    try {
      final data = <String, dynamic>{};
      if (code != null) data['code'] = code;
      if (name != null) data['name'] = name;
      if (description != null) data['description'] = description;
      if (hourlyRate != null) data['hourly_rate'] = hourlyRate.toStringAsFixed(2);
      if (dailyRate != null) data['daily_rate'] = dailyRate.toStringAsFixed(2);

      final response = await _dio.patch('/equipment/$id/', data: data);
      return Equipment.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw _handleError(e);
    } catch (e) {
      if (e is AppException) rethrow;
      throw AppException.unknown('Неизвестная ошибка: ${e.toString()}');
    }
  }

  /// Удалить технику
  Future<void> deleteEquipment(int id) async {
    try {
      await _dio.delete('/equipment/$id/');
    } on DioException catch (e) {
      throw _handleError(e);
    } catch (e) {
      if (e is AppException) rethrow;
      throw AppException.unknown('Неизвестная ошибка: ${e.toString()}');
    }
  }

  /// Создать услугу
  Future<ServiceItem> createService({
    required String name,
    double? price,
    int? categoryId,
  }) async {
    try {
      final response = await _dio.post('/services/', data: {
        'name': name,
        if (price != null) 'price': price.toStringAsFixed(2),
        if (categoryId != null) 'category_id': categoryId,
        'is_active': true,
      });
      final service = ServiceItem.fromJson(response.data as Map<String, dynamic>);
      
      // Мгновенно обновляем кэш - добавляем новую услугу в начало списка
      final cacheService = _ref.read(cacheServiceProvider);
      final cached = await cacheService.getCachedServices();
      if (cached != null) {
        // Удаляем элемент с таким же ID, если он есть (на случай дубликатов)
        cached.removeWhere((s) => (s as Map)['id'] == service.id);
        // Добавляем новую услугу в начало списка
        cached.insert(0, service.toJson());
        await cacheService.cacheServices(cached);
      } else {
        // Если кэша нет, создаем новый с этой услугой
        await cacheService.cacheServices([service.toJson()]);
      }
      
      return service;
    } on DioException catch (e) {
      throw _handleError(e);
    } catch (e) {
      if (e is AppException) rethrow;
      throw AppException.unknown('Неизвестная ошибка: ${e.toString()}');
    }
  }

  /// Обновить услугу
  Future<ServiceItem> updateService(
    int id, {
    String? name,
    double? price,
    int? categoryId,
  }) async {
    try {
      final data = <String, dynamic>{};
      if (name != null) data['name'] = name;
      if (price != null) data['price'] = price.toStringAsFixed(2);
      if (categoryId != null) data['category_id'] = categoryId;

      final response = await _dio.patch('/services/$id/', data: data);
      return ServiceItem.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw _handleError(e);
    } catch (e) {
      if (e is AppException) rethrow;
      throw AppException.unknown('Неизвестная ошибка: ${e.toString()}');
    }
  }

  /// Удалить услугу
  Future<void> deleteService(int id) async {
    try {
      await _dio.delete('/services/$id/');
    } on DioException catch (e) {
      throw _handleError(e);
    } catch (e) {
      if (e is AppException) rethrow;
      throw AppException.unknown('Неизвестная ошибка: ${e.toString()}');
    }
  }

  /// Создать материал
  Future<MaterialItem> createMaterial({
    required String name,
    required double price,
    required String unit,
    String? category,
  }) async {
    try {
      final response = await _dio.post('/materials/', data: {
        'name': name,
        'price': price.toStringAsFixed(2),
        'unit': unit,
        if (category != null) 'category': category,
        'is_active': true,
      });
      final material = MaterialItem.fromJson(response.data as Map<String, dynamic>);
      
      // Мгновенно обновляем кэш - добавляем новый материал в начало списка
      final cacheService = _ref.read(cacheServiceProvider);
      final cached = await cacheService.getCachedMaterials();
      if (cached != null) {
        // Удаляем элемент с таким же ID, если он есть (на случай дубликатов)
        cached.removeWhere((m) => (m as Map)['id'] == material.id);
        // Добавляем новый материал в начало списка
        cached.insert(0, material.toJson());
        await cacheService.cacheMaterials(cached);
      } else {
        // Если кэша нет, создаем новый с этим материалом
        await cacheService.cacheMaterials([material.toJson()]);
      }
      
      return material;
    } on DioException catch (e) {
      throw _handleError(e);
    } catch (e) {
      if (e is AppException) rethrow;
      throw AppException.unknown('Неизвестная ошибка: ${e.toString()}');
    }
  }

  /// Обновить материал
  Future<MaterialItem> updateMaterial(
    int id, {
    String? name,
    double? price,
    String? unit,
    String? category,
  }) async {
    try {
      final data = <String, dynamic>{};
      if (name != null) data['name'] = name;
      if (price != null) data['price'] = price.toStringAsFixed(2);
      if (unit != null) data['unit'] = unit;
      if (category != null) data['category'] = category;

      final response = await _dio.patch('/materials/$id/', data: data);
      return MaterialItem.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw _handleError(e);
    } catch (e) {
      if (e is AppException) rethrow;
      throw AppException.unknown('Неизвестная ошибка: ${e.toString()}');
    }
  }

  /// Удалить материал
  Future<void> deleteMaterial(int id) async {
    try {
      await _dio.delete('/materials/$id/');
    } on DioException catch (e) {
      throw _handleError(e);
    } catch (e) {
      if (e is AppException) rethrow;
      throw AppException.unknown('Неизвестная ошибка: ${e.toString()}');
    }
  }

  String? _extractMessage(dynamic data) {
    if (data is Map<String, dynamic>) {
      return data['detail'] as String? ?? data['message'] as String?;
    }
    return null;
  }
}


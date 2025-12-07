import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/errors/app_exception.dart';

/// Провайдер сервиса клиентов
final clientServiceProvider = Provider<ClientService>((ref) {
  final dio = ref.watch(dioClientProvider);
  return ClientService(dio);
});

/// Сервис для работы с клиентами
class ClientService {
  final Dio _dio;

  ClientService(this._dio);

  /// Создать клиента
  Future<Map<String, dynamic>> createClient({
    required String name,
    required String phone,
    String? address,
    String? email,
    String? contactPerson,
  }) async {
    try {
      final response = await _dio.post(
        '/clients/',
        data: {
          'name': name,
          'phone': phone,
          if (address != null && address.isNotEmpty) 'address': address,
          if (email != null && email.isNotEmpty) 'email': email,
          if (contactPerson != null && contactPerson.isNotEmpty) 'contact_person': contactPerson,
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


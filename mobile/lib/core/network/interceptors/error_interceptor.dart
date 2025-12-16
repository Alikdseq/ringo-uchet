import 'package:dio/dio.dart';
import '../../errors/app_exception.dart';

/// Interceptor для обработки ошибок API
class ErrorInterceptor extends Interceptor {
  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final exception = _handleError(err);
    handler.reject(
      DioException(
        requestOptions: err.requestOptions,
        error: exception,
        response: err.response,
        type: err.type,
      ),
    );
  }

  AppException _handleError(DioException error) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return AppException.timeout('Превышено время ожидания');

      case DioExceptionType.badResponse:
        return _handleResponseError(error.response);

      case DioExceptionType.cancel:
        return AppException.cancelled('Запрос отменён');

      case DioExceptionType.connectionError:
        return AppException.network('Ошибка подключения к серверу');

      default:
        return AppException.unknown('Неизвестная ошибка: ${error.message}');
    }
  }

  AppException _handleResponseError(Response? response) {
    if (response == null) {
      return AppException.unknown('Пустой ответ от сервера');
    }

    final statusCode = response.statusCode;
    final data = response.data;

    switch (statusCode) {
      case 400:
        return AppException.badRequest(
          _extractMessage(data) ?? 'Неверный запрос',
        );
      case 401:
        return AppException.unauthorized('Требуется авторизация');
      case 403:
        return AppException.forbidden('Доступ запрещён');
      case 404:
        return AppException.notFound('Ресурс не найден');
      case 422:
        return AppException.validation(
          _extractMessage(data) ?? 'Ошибка валидации',
          _extractErrors(data),
        );
      case 429:
        return AppException.rateLimit('Превышен лимит запросов');
      case 500:
      case 502:
      case 503:
        return AppException.server('Ошибка сервера');
      default:
        return AppException.unknown(
          'Ошибка $statusCode: ${_extractMessage(data) ?? 'Неизвестная ошибка'}',
        );
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


import 'package:dio/dio.dart';
import '../../constants/app_constants.dart';

/// Interceptor для повторных попыток запросов при ошибках
class RetryInterceptor extends Interceptor {
  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    // Повторяем только для сетевых ошибок и 5xx
    if (_shouldRetry(err)) {
      final retryCount = err.requestOptions.extra['retryCount'] ?? 0;

      if (retryCount < AppConstants.maxRetryAttempts) {
        err.requestOptions.extra['retryCount'] = retryCount + 1;

        // Экспоненциальная задержка: 1s, 2s, 4s
        await Future.delayed(Duration(seconds: 1 << retryCount));

        try {
          final response = await Dio().fetch(err.requestOptions);
          handler.resolve(response);
          return;
        } catch (e) {
          // Если повторная попытка не удалась, продолжаем с ошибкой
        }
      }
    }

    handler.next(err);
  }

  bool _shouldRetry(DioException error) {
    // Повторяем для сетевых ошибок
    if (error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.connectionError) {
      return true;
    }

    // Повторяем для 5xx ошибок
    final statusCode = error.response?.statusCode;
    if (statusCode != null && statusCode >= 500 && statusCode < 600) {
      return true;
    }

    return false;
  }
}


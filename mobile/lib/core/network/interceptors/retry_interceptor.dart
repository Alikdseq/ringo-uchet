import 'package:dio/dio.dart';
import '../../constants/app_constants.dart';

/// Interceptor для повторных попыток запросов при ошибках
/// Улучшено для работы на мобильном интернете
class RetryInterceptor extends Interceptor {
  final Dio? dio;

  RetryInterceptor({this.dio});

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    // Повторяем только для сетевых ошибок и 5xx
    if (_shouldRetry(err)) {
      final retryCount = err.requestOptions.extra['retryCount'] ?? 0;

      if (retryCount < AppConstants.maxRetryAttempts) {
        err.requestOptions.extra['retryCount'] = retryCount + 1;

        // Экспоненциальная задержка: 2s, 4s, 8s (увеличено для медленных соединений)
        final delaySeconds = 2 << retryCount;
        await Future.delayed(Duration(seconds: delaySeconds));

        try {
          // Используем переданный Dio клиент или создаем новый с увеличенными таймаутами
          final timeoutSeconds = (AppConstants.defaultTimeoutSeconds + (retryCount * 5)).toInt();
          final dioClient = dio ?? Dio(BaseOptions(
            connectTimeout: Duration(seconds: timeoutSeconds),
            receiveTimeout: Duration(seconds: timeoutSeconds),
          ));
          
          // Копируем requestOptions с увеличенными таймаутами
          final options = err.requestOptions.copyWith(
            connectTimeout: Duration(seconds: timeoutSeconds),
            receiveTimeout: Duration(seconds: timeoutSeconds),
          );
          
          final response = await dioClient.fetch(options);
          handler.resolve(response);
          return;
        } catch (e) {
          // Если повторная попытка не удалась, продолжаем с ошибкой
          if (e is DioException) {
            // Если это тоже ошибка сети, пробуем еще раз
            if (_shouldRetry(e) && retryCount < AppConstants.maxRetryAttempts - 1) {
              // Рекурсивно вызываем onError для следующей попытки
              e.requestOptions.extra['retryCount'] = retryCount + 1;
              onError(e, handler);
              return;
            }
          }
        }
      }
    }

    handler.next(err);
  }

  bool _shouldRetry(DioException error) {
    // Повторяем для сетевых ошибок
    if (error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.sendTimeout ||
        error.type == DioExceptionType.receiveTimeout ||
        error.type == DioExceptionType.connectionError) {
      return true;
    }

    // Повторяем для 5xx ошибок
    final statusCode = error.response?.statusCode;
    if (statusCode != null && statusCode >= 500 && statusCode < 600) {
      return true;
    }

    // Повторяем для 408 (Request Timeout) и 429 (Too Many Requests)
    if (statusCode == 408 || statusCode == 429) {
      return true;
    }

    return false;
  }
}


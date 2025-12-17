import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pretty_dio_logger/pretty_dio_logger.dart';
import '../config/app_config.dart';
import '../constants/app_constants.dart';
import 'interceptors/auth_interceptor.dart';
import 'interceptors/error_interceptor.dart';
import 'interceptors/retry_interceptor.dart';

/// Провайдер Dio клиента
/// ОПТИМИЗАЦИЯ ДЛЯ VPN: Адаптивные таймауты для медленных соединений
final dioClientProvider = Provider<Dio>((ref) {
  final config = ref.watch(appConfigProvider);
  final dio = Dio(
    BaseOptions(
      baseUrl: config.apiUrl,
      // Используем увеличенный таймаут для поддержки VPN/медленного интернета
      // При ошибке используется кэш, поэтому увеличенный таймаут не блокирует UI
      connectTimeout: const Duration(seconds: AppConstants.slowConnectionTimeoutSeconds),
      receiveTimeout: const Duration(seconds: AppConstants.slowConnectionTimeoutSeconds),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'Accept-Encoding': 'gzip, deflate', // Поддержка сжатия для уменьшения трафика
      },
      // Оптимизация: включаем HTTP/2 и сжатие
      persistentConnection: true,
      followRedirects: true,
      maxRedirects: 5,
    ),
  );

  // Interceptors
  dio.interceptors.add(AuthInterceptor(ref));
  dio.interceptors.add(ErrorInterceptor());
  dio.interceptors.add(RetryInterceptor(dio: dio)); // Передаем тот же Dio клиент для retry

  // Логирование только для dev/stage
  if (config.enableLogging) {
    dio.interceptors.add(
      PrettyDioLogger(
        requestHeader: true,
        requestBody: true,
        responseBody: true,
        responseHeader: false,
        error: true,
        compact: true,
        maxWidth: 90,
      ),
    );
  }

  return dio;
});

/// Провайдер конфигурации приложения
final appConfigProvider = Provider<AppConfig>((ref) {
  // Определяется через flavor в main_*.dart
  throw UnimplementedError('appConfigProvider must be overridden');
});


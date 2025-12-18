import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pretty_dio_logger/pretty_dio_logger.dart';
import '../config/app_config.dart';
import '../constants/app_constants.dart';
import 'interceptors/web_header_interceptor.dart';
import 'interceptors/auth_interceptor.dart';
import 'interceptors/error_interceptor.dart';
import 'interceptors/retry_interceptor.dart';

/// Провайдер Dio клиента
/// ОПТИМИЗАЦИЯ ДЛЯ VPN: Адаптивные таймауты для медленных соединений
final dioClientProvider = Provider<Dio>((ref) {
  final config = ref.watch(appConfigProvider);
  
  // Базовые заголовки
  final headers = <String, dynamic>{
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };
  
  // НЕ устанавливаем Accept-Encoding для веб-платформы
  // Браузер автоматически управляет этим заголовком и не позволяет его устанавливать вручную
  // На веб-платформе браузер сам добавляет Accept-Encoding, если поддерживает сжатие
  if (!kIsWeb) {
    headers['Accept-Encoding'] = 'gzip, deflate'; // Поддержка сжатия для мобильных платформ
  } else {
    // Явно убеждаемся что Accept-Encoding не установлен на веб
    headers.remove('Accept-Encoding');
  }
  
  final dio = Dio(
    BaseOptions(
      baseUrl: config.apiUrl,
      // Используем увеличенный таймаут для поддержки VPN/медленного интернета
      // При ошибке используется кэш, поэтому увеличенный таймаут не блокирует UI
      connectTimeout: const Duration(seconds: AppConstants.slowConnectionTimeoutSeconds),
      receiveTimeout: const Duration(seconds: AppConstants.slowConnectionTimeoutSeconds),
      headers: headers,
      // Оптимизация: включаем HTTP/2 и сжатие
      persistentConnection: true,
      followRedirects: true,
      maxRedirects: 5,
    ),
  );

  // Interceptors (порядок важен!)
  // 1. WebHeaderInterceptor - ПЕРВЫМ, чтобы гарантированно удалить небезопасные заголовки для веб
  dio.interceptors.add(WebHeaderInterceptor());
  // 2. AuthInterceptor - добавляет токены авторизации
  dio.interceptors.add(AuthInterceptor(ref));
  // 3. ErrorInterceptor - обрабатывает ошибки
  dio.interceptors.add(ErrorInterceptor());
  // 4. RetryInterceptor - повторяет запросы при ошибках
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


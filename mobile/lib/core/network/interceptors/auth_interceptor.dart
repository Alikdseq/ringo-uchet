import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../storage/secure_storage.dart';
import '../../../features/auth/providers/auth_providers.dart';
import '../dio_client.dart';

/// Interceptor для добавления JWT токена в заголовки и автоматического обновления
class AuthInterceptor extends Interceptor {
  final Ref ref;
  bool _isRefreshing = false;
  final List<_PendingRequest> _pendingRequests = [];

  AuthInterceptor(this.ref);

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    // Пропускаем auth endpoints, чтобы избежать циклических запросов
    if (options.path.contains('/token/') || options.path.contains('/auth/')) {
      handler.next(options);
      return;
    }

    // Удаляем Accept-Encoding для веб-платформы (браузер управляет этим автоматически)
    // WebHeaderInterceptor должен был уже удалить его, но на всякий случай удаляем здесь тоже
    if (kIsWeb) {
      options.headers.remove('Accept-Encoding');
      options.headers.remove('accept-encoding'); // На случай разного регистра
    }

    final storage = ref.read(secureStorageProvider);
    // Всегда читаем свежий токен из хранилища перед каждым запросом
    // Это гарантирует что используется актуальный токен
    final token = await storage.getAccessToken();

    if (token != null) {
      options.headers['Authorization'] = 'Bearer $token';
    }

    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    // Если 401, пытаемся обновить токен
    if (err.response?.statusCode == 401) {
      // Пропускаем auth endpoints
      if (err.requestOptions.path.contains('/token/') ||
          err.requestOptions.path.contains('/auth/')) {
        handler.next(err);
        return;
      }

      // Если уже обновляем токен, добавляем запрос в очередь
      if (_isRefreshing) {
        final completer = Completer<Response>();
        _pendingRequests.add(_PendingRequest(err.requestOptions, completer));

        try {
          final response = await completer.future;
          handler.resolve(response);
          return;
        } catch (e) {
          handler.next(err);
          return;
        }
      }

      _isRefreshing = true;

      try {
        final authNotifier = ref.read(authStateProvider.notifier);
        final refreshed = await authNotifier.refreshToken();

        if (refreshed) {
          // Обновляем токен в запросе
          final storage = ref.read(secureStorageProvider);
          final newToken = await storage.getAccessToken();
          
          if (newToken == null) {
            // Если токен не получен, отклоняем запросы
            for (final pending in _pendingRequests) {
              pending.completer.completeError(err);
            }
            _pendingRequests.clear();
            handler.next(err);
            return;
          }
          
          err.requestOptions.headers['Authorization'] = 'Bearer $newToken';
          
          // Удаляем Accept-Encoding для веб-платформы (браузер управляет этим автоматически)
          if (kIsWeb) {
            err.requestOptions.headers.remove('Accept-Encoding');
            err.requestOptions.headers.remove('accept-encoding'); // На случай разного регистра
          }

          // Повторяем оригинальный запрос
          try {
            // Используем тот же Dio клиент из провайдера (уже настроен с WebHeaderInterceptor)
            // Или создаем новый с правильными настройками для веб
            final dioClient = ref.read(dioClientProvider);
            final response = await dioClient.fetch(err.requestOptions);
            
            // Разрешаем все ожидающие запросы
            for (final pending in _pendingRequests) {
              pending.requestOptions.headers['Authorization'] = 'Bearer $newToken';
              
              // Удаляем Accept-Encoding для веб-платформы (браузер управляет этим автоматически)
              if (kIsWeb) {
                pending.requestOptions.headers.remove('Accept-Encoding');
                pending.requestOptions.headers.remove('accept-encoding'); // На случай разного регистра
              }
              try {
                final pendingResponse = await dioClient.fetch(pending.requestOptions);
                pending.completer.complete(pendingResponse);
              } catch (e) {
                pending.completer.completeError(e);
              }
            }
            _pendingRequests.clear();

            handler.resolve(response);
            return;
          } catch (e) {
            // Если повторный запрос не удался, отклоняем все ожидающие
            for (final pending in _pendingRequests) {
              pending.completer.completeError(e);
            }
            _pendingRequests.clear();
            handler.next(err);
            return;
          }
        } else {
          // Если refresh не удался (refresh token недействителен)
          // Пытаемся автоматический перелогин с сохраненными credentials
          try {
            final autoLoginSuccess = await authNotifier.attemptAutoLogin();
            
            if (autoLoginSuccess) {
              // Автоматический перелогин успешен - получаем новый токен
              final storage = ref.read(secureStorageProvider);
              final newToken = await storage.getAccessToken();
              
              if (newToken != null) {
                // Обновляем токен в оригинальном запросе
                err.requestOptions.headers['Authorization'] = 'Bearer $newToken';
                
                // Удаляем Accept-Encoding для веб-платформы
                if (kIsWeb) {
                  err.requestOptions.headers.remove('Accept-Encoding');
                  err.requestOptions.headers.remove('accept-encoding');
                }

                // Повторяем оригинальный запрос
                try {
                  final dioClient = ref.read(dioClientProvider);
                  final response = await dioClient.fetch(err.requestOptions);
                  
                  // Разрешаем все ожидающие запросы с новым токеном
                  for (final pending in _pendingRequests) {
                    pending.requestOptions.headers['Authorization'] = 'Bearer $newToken';
                    
                    if (kIsWeb) {
                      pending.requestOptions.headers.remove('Accept-Encoding');
                      pending.requestOptions.headers.remove('accept-encoding');
                    }
                    
                    try {
                      final pendingResponse = await dioClient.fetch(pending.requestOptions);
                      pending.completer.complete(pendingResponse);
                    } catch (e) {
                      pending.completer.completeError(e);
                    }
                  }
                  _pendingRequests.clear();

                  handler.resolve(response);
                  return;
                } catch (e) {
                  // Если повторный запрос не удался, отклоняем все ожидающие
                  for (final pending in _pendingRequests) {
                    pending.completer.completeError(e);
                  }
                  _pendingRequests.clear();
                  handler.next(err);
                  return;
                }
              }
            }
          } catch (e) {
            // Автоматический перелогин не удался - продолжаем с ошибкой
            debugPrint('Auto-login in interceptor failed: $e');
          }
          
          // Если автоматический перелогин не удался или токен не получен
          // Отклоняем все ожидающие запросы
          for (final pending in _pendingRequests) {
            pending.completer.completeError(err);
          }
          _pendingRequests.clear();
          
          // Пропускаем ошибку дальше - она будет обработана на уровне приложения
          handler.next(err);
          return;
        }
      } catch (e) {
        // Отклоняем все ожидающие запросы
        for (final pending in _pendingRequests) {
          pending.completer.completeError(e);
        }
        _pendingRequests.clear();
      } finally {
        _isRefreshing = false;
      }
    }

    handler.next(err);
  }
}

/// Вспомогательный класс для хранения ожидающих запросов
class _PendingRequest {
  final RequestOptions requestOptions;
  final Completer<Response> completer;

  _PendingRequest(this.requestOptions, this.completer);
}


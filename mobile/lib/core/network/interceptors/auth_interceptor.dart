import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../storage/secure_storage.dart';
import '../../../features/auth/providers/auth_providers.dart';

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
          err.requestOptions.headers['Authorization'] = 'Bearer $newToken';

          // Повторяем оригинальный запрос
          try {
            final dio = Dio();
            final response = await dio.fetch(err.requestOptions);
            
            // Разрешаем все ожидающие запросы
            for (final pending in _pendingRequests) {
              pending.requestOptions.headers['Authorization'] = 'Bearer $newToken';
              try {
                final pendingResponse = await dio.fetch(pending.requestOptions);
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
          }
        } else {
          // Если refresh не удался, отклоняем все ожидающие запросы
          for (final pending in _pendingRequests) {
            pending.completer.completeError(err);
          }
          _pendingRequests.clear();
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


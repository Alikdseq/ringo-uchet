import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/errors/app_exception.dart';
import '../models/auth_models.dart';

/// Провайдер сервиса аутентификации
final authServiceProvider = Provider<AuthService>((ref) {
  final dio = ref.watch(dioClientProvider);
  return AuthService(dio);
});

/// Сервис для работы с аутентификацией
class AuthService {
  final Dio _dio;

  AuthService(this._dio);

  /// Логин по телефону/email/username и паролю
  Future<AuthResponse> login(LoginRequest request) async {
    try {
      final response = await _dio.post(
        '/token/',
        data: {
          if (request.phone != null) 'phone': request.phone,
          if (request.email != null) 'email': request.email,
          if (request.username != null) 'username': request.username,
          'password': request.password,
          if (request.captchaToken != null) 'captcha_token': request.captchaToken,
        },
      );

      final authResponse = AuthResponse.fromJson(response.data);

      // НЕ делаем запрос /users/me/ здесь, так как токен еще не сохранен в SecureStorage
      // AuthInterceptor не сможет использовать новый токен
      // Запрос /users/me/ будет сделан в AuthNotifier после сохранения токена
      return authResponse;
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        throw AppException.unauthorized(
          _extractMessage(e.response?.data) ?? 'Неверный телефон/email или пароль',
        );
      } else if (e.response?.statusCode == 400) {
        throw AppException.badRequest(
          _extractMessage(e.response?.data) ?? 'Ошибка в данных запроса',
        );
      } else if (e.response?.statusCode == 429) {
        throw AppException.rateLimit('Слишком много попыток входа. Попробуйте позже');
      } else if (e.error is AppException) {
        throw e.error as AppException;
      } else {
        throw AppException.network('Ошибка подключения к серверу');
      }
    } catch (e) {
      if (e is AppException) rethrow;
      throw AppException.unknown('Неизвестная ошибка: ${e.toString()}');
    }
  }

  /// Отправка OTP на телефон
  Future<void> sendOTP(OTPRequest request) async {
    try {
      await _dio.post(
        '/auth/otp/send/',
        data: {
          'phone': request.phone,
          if (request.captchaToken != null) 'captcha_token': request.captchaToken,
        },
      );
    } on DioException catch (e) {
      if (e.response?.statusCode == 400) {
        throw AppException.badRequest(
          _extractMessage(e.response?.data) ?? 'Неверный номер телефона',
        );
      } else if (e.response?.statusCode == 429) {
        throw AppException.rateLimit('Слишком много запросов. Попробуйте позже');
      } else if (e.error is AppException) {
        throw e.error as AppException;
      } else {
        throw AppException.network('Ошибка подключения к серверу');
      }
    } catch (e) {
      if (e is AppException) rethrow;
      throw AppException.unknown('Неизвестная ошибка: ${e.toString()}');
    }
  }

  /// Верификация OTP и получение токенов
  Future<AuthResponse> verifyOTP(OTPVerifyRequest request) async {
    try {
      final response = await _dio.post(
        '/auth/otp/verify/',
        data: {
          'phone': request.phone,
          'code': request.code,
        },
      );

      final authResponse = AuthResponse.fromJson(response.data);

      // НЕ делаем запрос /users/me/ здесь, так как токен еще не сохранен в SecureStorage
      // AuthInterceptor не сможет использовать новый токен
      // Запрос /users/me/ будет сделан в AuthNotifier после сохранения токена
      return authResponse;
    } on DioException catch (e) {
      if (e.response?.statusCode == 400) {
        throw AppException.badRequest(
          _extractMessage(e.response?.data) ?? 'Неверный код подтверждения',
        );
      } else if (e.response?.statusCode == 401) {
        throw AppException.unauthorized('Код подтверждения неверен или истёк');
      } else if (e.error is AppException) {
        throw e.error as AppException;
      } else {
        throw AppException.network('Ошибка подключения к серверу');
      }
    } catch (e) {
      if (e is AppException) rethrow;
      throw AppException.unknown('Неизвестная ошибка: ${e.toString()}');
    }
  }

  /// Обновление access token
  Future<String> refreshToken(String refreshToken) async {
    try {
      final response = await _dio.post(
        '/token/refresh/',
        data: {'refresh': refreshToken},
      );

      final refreshResponse = RefreshTokenResponse.fromJson(response.data);
      return refreshResponse.access;
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        throw AppException.unauthorized('Refresh token недействителен');
      } else if (e.error is AppException) {
        throw e.error as AppException;
      } else {
        throw AppException.network('Ошибка подключения к серверу');
      }
    } catch (e) {
      if (e is AppException) rethrow;
      throw AppException.unknown('Неизвестная ошибка: ${e.toString()}');
    }
  }

  /// Выход из системы (отзыв токенов)
  Future<void> logout(String refreshToken) async {
    try {
      await _dio.post(
        '/token/blacklist/',
        data: {'refresh': refreshToken},
      );
    } on DioException catch (e) {
      // Игнорируем ошибки при logout, так как токены могут быть уже недействительны
      if (e.response?.statusCode != 401 && e.response?.statusCode != 400) {
        throw AppException.network('Ошибка при выходе из системы');
      }
    } catch (e) {
      if (e is AppException) rethrow;
      // Игнорируем другие ошибки при logout
    }
  }

  /// Получение информации о текущем пользователе
  Future<UserInfo> getCurrentUser() async {
    try {
      final response = await _dio.get('/users/me/');
      return UserInfo.fromJson(response.data);
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        throw AppException.unauthorized('Требуется авторизация');
      } else if (e.error is AppException) {
        throw e.error as AppException;
      } else {
        throw AppException.network('Ошибка подключения к серверу');
      }
    } catch (e) {
      if (e is AppException) rethrow;
      throw AppException.unknown('Неизвестная ошибка: ${e.toString()}');
    }
  }

  /// Регистрация нового пользователя
  Future<void> register({
    required String phone,
    required String password,
    required String firstName,
    required String lastName,
  }) async {
    try {
      final response = await _dio.post(
        '/users/register/',
        data: {
          'phone': phone,
          'password': password,
          'first_name': firstName,
          'last_name': lastName,
        },
      );
      // Проверяем успешный ответ
      if (response.statusCode != 201 && response.statusCode != 200) {
        throw AppException.badRequest('Ошибка регистрации: неожиданный статус ответа');
      }
    } on DioException catch (e) {
      // Извлекаем детальное сообщение об ошибке
      final errorMessage = _extractMessage(e.response?.data) ?? 
          (e.response?.data is Map ? 
            (e.response?.data as Map).values.join(', ') : 
            'Ошибка регистрации');
      
      if (e.response?.statusCode == 400) {
        // Проверяем, есть ли детали ошибки валидации
        if (e.response?.data is Map) {
          final data = e.response!.data as Map;
          // Если есть поля с ошибками, формируем детальное сообщение
          final fieldErrors = <String, dynamic>{};
          data.forEach((key, value) {
            if (key != 'detail' && key != 'message' && key != 'non_field_errors') {
              fieldErrors[key.toString()] = value;
            }
          });
          
          if (fieldErrors.isNotEmpty) {
            final fieldMessages = fieldErrors.entries
                .map((e) => '${e.key}: ${e.value is List ? (e.value as List).join(', ') : e.value}')
                .join('; ');
            throw AppException.badRequest('Ошибка валидации: $fieldMessages');
          }
        }
        throw AppException.badRequest(errorMessage);
      } else if (e.response?.statusCode == 409) {
        throw AppException.badRequest('Пользователь с таким телефоном уже существует');
      } else if (e.response?.statusCode == 500) {
        throw AppException.network('Ошибка сервера: $errorMessage');
      } else if (e.error is AppException) {
        throw e.error as AppException;
      } else {
        throw AppException.network('Ошибка подключения к серверу: ${e.message ?? errorMessage}');
      }
    } catch (e) {
      if (e is AppException) rethrow;
      throw AppException.unknown('Неизвестная ошибка: ${e.toString()}');
    }
  }

  String? _extractMessage(dynamic data) {
    if (data is Map<String, dynamic>) {
      return data['detail'] as String? ??
          data['message'] as String? ??
          (data['non_field_errors'] as List?)?.first as String?;
    }
    return null;
  }

  /// Смена пароля текущего пользователя
  Future<void> changePassword({
    required String oldPassword,
    required String newPassword,
    required String confirmPassword,
  }) async {
    try {
      await _dio.post(
        '/users/change-password/',
        data: {
          'old_password': oldPassword,
          'new_password': newPassword,
          'confirm_password': confirmPassword,
        },
      );
    } on DioException catch (e) {
      final message = _extractMessage(e.response?.data) ?? 'Не удалось изменить пароль';
      if (e.response?.statusCode == 400) {
        throw AppException.validation(message, e.response?.data as Map<String, dynamic>?);
      } else if (e.response?.statusCode == 401) {
        throw AppException.unauthorized('Требуется повторный вход в систему');
      } else {
        throw AppException.network(message);
      }
    } catch (e) {
      if (e is AppException) rethrow;
      throw AppException.unknown('Ошибка при смене пароля: ${e.toString()}');
    }
  }
}


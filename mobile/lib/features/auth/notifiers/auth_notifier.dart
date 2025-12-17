import 'dart:convert';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/storage/secure_storage.dart';
import '../../../core/errors/app_exception.dart';
import '../models/auth_models.dart';
import '../services/auth_service.dart';

/// Состояние аутентификации
class AuthState {
  final bool isAuthenticated;
  final bool isLoading;
  final UserInfo? user;
  final String? error;
  final AppException? exception;

  const AuthState({
    this.isAuthenticated = false,
    this.isLoading = false,
    this.user,
    this.error,
    this.exception,
  });

  AuthState copyWith({
    bool? isAuthenticated,
    bool? isLoading,
    UserInfo? user,
    String? error,
    AppException? exception,
    bool clearError = false,
    bool clearUser = false,
  }) {
    return AuthState(
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      isLoading: isLoading ?? this.isLoading,
      user: clearUser ? null : (user ?? this.user),
      error: clearError ? null : (error ?? this.error),
      exception: clearError ? null : (exception ?? this.exception),
    );
  }
}

/// Notifier для управления состоянием аутентификации
class AuthNotifier extends StateNotifier<AuthState> {
  final AuthService _authService;
  final SecureStorage _secureStorage;

  AuthNotifier(this._authService, this._secureStorage)
      : super(const AuthState()) {
    _checkAuthStatus();
  }

  /// Проверка статуса аутентификации при инициализации
  /// Проактивное обновление токенов: автоматически обновляем токены при открытии приложения
  /// Автоматический вход: если токены истекли, используем сохраненный пароль для входа
  Future<void> _checkAuthStatus() async {
    // СНАЧАЛА загружаем пользователя из кэша для мгновенного отображения (если есть)
    final cachedUserData = await _secureStorage.getUserData();
    if (cachedUserData != null) {
      try {
        final userJson = jsonDecode(cachedUserData) as Map<String, dynamic>;
        final cachedUser = UserInfo.fromJson(userJson);
        // Устанавливаем состояние из кэша МГНОВЕННО - показываем главный экран сразу
        state = state.copyWith(
          isAuthenticated: true,
          user: cachedUser,
          clearError: true,
        );
      } catch (e) {
        // Если кэш поврежден, игнорируем
      }
    }
    
    final accessToken = await _secureStorage.getAccessToken();
    final refreshTokenValue = await _secureStorage.getRefreshToken();
    
    // Если есть refresh token - пытаемся обновить access token проактивно
    if (refreshTokenValue != null) {
      try {
        // Пытаемся обновить токен (даже если access token еще есть, обновим его на свежий)
        final refreshed = await refreshToken();
        if (refreshed) {
          // Токен успешно обновлен - обновляем данные пользователя в фоне
          _refreshUserInBackground();
          return; // Все хорошо, пользователь авторизован
        }
      } catch (e) {
        debugPrint('Token refresh failed during init: $e');
        // Если обновление не удалось - refresh token истек, пробуем автоматический вход
      }
    }
    
    // Если refresh token истек или его нет - проверяем наличие сохраненного пароля для автоматического входа
    final savedPhone = await _secureStorage.getPhone();
    final savedEmail = await _secureStorage.getEmail();
    final savedPassword = await _secureStorage.getPassword();
    
    if (savedPassword != null && savedPassword.isNotEmpty && (savedPhone != null || savedEmail != null)) {
      // Автоматический вход с сохраненным паролем (токены истекли, но пароль есть)
      try {
        final request = LoginRequest(
          phone: savedPhone,
          email: savedEmail,
          password: savedPassword,
        );
        // Тихий вход без показа индикатора загрузки
        await login(request, showLoading: false);
        // Если успешно - пользователь авторизован с новыми токенами
        return;
      } catch (e) {
        debugPrint('Auto-login after token expiration failed: $e');
        // Если автоматический вход не удался, но есть кэш - продолжаем работать с кэшем
        if (cachedUserData != null) {
          // Пользователь видит главный экран, но данные могут быть устаревшими
          return;
        }
      }
    }
    
    // Если нет сохраненного пароля - проверяем наличие access token (может быть еще валидным)
    if (accessToken != null) {
      // Если есть access token - обновляем данные с сервера в фоне
      // Если токен истек, _refreshUserInBackground обработает это
      _refreshUserInBackground();
      return;
    }
    
    // Если ничего из вышеперечисленного не сработало - показываем экран входа только если нет кэша
    if (cachedUserData == null) {
      state = state.copyWith(
        isAuthenticated: false,
        user: null,
        clearError: true,
      );
    }
    // Если есть кэш - продолжаем работать с кэшем, пользователь видит главный экран
  }

  /// Обновление пользователя в фоне (не блокирует UI)
  Future<void> _refreshUserInBackground() async {
    try {
      final user = await _authService.getCurrentUser();
      state = state.copyWith(
        isAuthenticated: true,
        user: user,
        clearError: true,
      );
      // Сохраняем данные пользователя
      await _secureStorage.saveUserData(jsonEncode(user.toJson()));
    } catch (e) {
      // Если токен недействителен (401), пытаемся обновить
      if (e is UnauthorizedException) {
        final refreshed = await refreshToken();
        if (refreshed) {
          try {
            final user = await _authService.getCurrentUser();
            state = state.copyWith(
              isAuthenticated: true,
              user: user,
              clearError: true,
            );
            await _secureStorage.saveUserData(jsonEncode(user.toJson()));
            return;
          } catch (e2) {
            // Если и после refresh не получилось, пытаемся автоматический вход
          }
        }
        // Если токен недействителен и не удалось обновить - пытаемся автоматический вход
        // ВАЖНО: НЕ очищаем пароль и телефон - они нужны для автоматического входа!
        final savedPhone = await _secureStorage.getPhone();
        final savedEmail = await _secureStorage.getEmail();
        final savedPassword = await _secureStorage.getPassword();
        
        // Очищаем только токены, но сохраняем учетные данные
        await _secureStorage.clearTokens();
        
        // Пытаемся автоматический вход с сохраненными данными
        if (savedPassword != null && savedPassword.isNotEmpty && (savedPhone != null || savedEmail != null)) {
          try {
            final request = LoginRequest(
              phone: savedPhone,
              email: savedEmail,
              password: savedPassword,
            );
            // Тихий вход в фоне
            await login(request, showLoading: false);
            // Если успешно - пользователь останется авторизованным
            return;
          } catch (loginError) {
            // Если автоматический вход не удался, но у нас есть кэш - продолжаем работать
            debugPrint('Auto-login after token refresh failed: $loginError');
            // Не меняем состояние - пользователь может продолжать работать с кэшем
          }
        } else {
          // Если нет сохраненных данных для входа - только тогда показываем экран входа
          // Но только если нет кэша пользователя
          final cachedUserData = await _secureStorage.getUserData();
          if (cachedUserData == null) {
            state = state.copyWith(
              isAuthenticated: false,
              user: null,
              clearError: true,
            );
          }
          // Если есть кэш - продолжаем работать с ним
        }
      }
      // Для других ошибок просто игнорируем - используем кэш
    }
  }

  /// Логин по телефону/email/username и паролю
  Future<void> login(LoginRequest request, {bool showLoading = true}) async {
    if (showLoading) {
      state = state.copyWith(isLoading: true, clearError: true);
    }

    try {
      final authResponse = await _authService.login(request);

      // Сохраняем токены СИНХРОННО перед любыми запросами
      await _secureStorage.saveAccessToken(authResponse.access);
      await _secureStorage.saveRefreshToken(authResponse.refresh);

      // Сохраняем данные для автоматического входа (телефон/email и пароль)
      if (request.phone != null && request.phone!.isNotEmpty) {
        await _secureStorage.savePhone(request.phone!);
      }
      if (request.email != null && request.email!.isNotEmpty) {
        await _secureStorage.saveEmail(request.email!);
      }
      await _secureStorage.savePassword(request.password);

      // Проверяем что токен действительно сохранен перед запросами
      final savedToken = await _secureStorage.getAccessToken();
      if (savedToken != authResponse.access) {
        // Если токен не сохранился, повторяем сохранение
        await _secureStorage.saveAccessToken(authResponse.access);
        await _secureStorage.saveRefreshToken(authResponse.refresh);
      }

      // Сохраняем данные пользователя, если они есть
      if (authResponse.user != null) {
        await _secureStorage.saveUserData(jsonEncode(authResponse.user!.toJson()));
        state = state.copyWith(
          isAuthenticated: true,
          user: authResponse.user,
          isLoading: false,
          clearError: true,
        );
      } else {
        // Если user не пришёл в ответе, получаем его отдельно ПОСЛЕ сохранения токена
        try {
          // Небольшая задержка для гарантии что токен сохранен в SecureStorage
          await Future.delayed(const Duration(milliseconds: 50));
          
          final user = await _authService.getCurrentUser();
          await _secureStorage.saveUserData(jsonEncode(user.toJson()));
          state = state.copyWith(
            isAuthenticated: true,
            user: user,
            isLoading: false,
            clearError: true,
          );
        } catch (e) {
          // Если не удалось получить user, продолжаем без него
          state = state.copyWith(
            isAuthenticated: true,
            user: null,
            isLoading: false,
            clearError: true,
          );
        }
      }
    } on AppException catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.message,
        exception: e,
        isAuthenticated: false,
      );
      // При ошибке входа НЕ очищаем сохраненные данные - они остаются для следующей попытки
      // Пароль и телефон сохраняются навсегда для автоматического входа
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Неизвестная ошибка: ${e.toString()}',
        isAuthenticated: false,
      );
      // При ошибке входа НЕ очищаем сохраненные данные - они остаются для следующей попытки
      // Пароль и телефон сохраняются навсегда для автоматического входа
    }
  }

  /// Отправка OTP
  Future<void> sendOTP(OTPRequest request) async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      await _authService.sendOTP(request);
      state = state.copyWith(isLoading: false, clearError: true);
    } on AppException catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.message,
        exception: e,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Неизвестная ошибка: ${e.toString()}',
      );
    }
  }

  /// Верификация OTP
  Future<void> verifyOTP(OTPVerifyRequest request) async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final authResponse = await _authService.verifyOTP(request);

      // Сохраняем токены СИНХРОННО перед любыми запросами
      await _secureStorage.saveAccessToken(authResponse.access);
      await _secureStorage.saveRefreshToken(authResponse.refresh);

      // Проверяем что токен действительно сохранен перед запросами
      final savedToken = await _secureStorage.getAccessToken();
      if (savedToken != authResponse.access) {
        // Если токен не сохранился, повторяем сохранение
        await _secureStorage.saveAccessToken(authResponse.access);
        await _secureStorage.saveRefreshToken(authResponse.refresh);
      }

      // Сохраняем данные пользователя
      if (authResponse.user != null) {
        await _secureStorage.saveUserData(jsonEncode(authResponse.user!.toJson()));
        state = state.copyWith(
          isAuthenticated: true,
          user: authResponse.user,
          isLoading: false,
          clearError: true,
        );
      } else {
        // Если user не пришёл в ответе, получаем его отдельно ПОСЛЕ сохранения токена
        try {
          // Небольшая задержка для гарантии что токен сохранен в SecureStorage
          await Future.delayed(const Duration(milliseconds: 50));
          
          final user = await _authService.getCurrentUser();
          await _secureStorage.saveUserData(jsonEncode(user.toJson()));
          state = state.copyWith(
            isAuthenticated: true,
            user: user,
            isLoading: false,
            clearError: true,
          );
        } catch (e) {
          // Если не удалось получить user, продолжаем без него
          state = state.copyWith(
            isAuthenticated: true,
            user: null,
            isLoading: false,
            clearError: true,
          );
        }
      }
    } on AppException catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.message,
        exception: e,
        isAuthenticated: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Неизвестная ошибка: ${e.toString()}',
        isAuthenticated: false,
      );
    }
  }

  /// Обновление токена
  Future<bool> refreshToken() async {
    try {
      final refreshTokenValue = await _secureStorage.getRefreshToken();
      if (refreshTokenValue == null) {
        return false;
      }

      final newAccessToken = await _authService.refreshToken(refreshTokenValue);
      await _secureStorage.saveAccessToken(newAccessToken);
      return true;
    } catch (e) {
      // Если refresh не удался - НЕ вызываем logout (чтобы не очистить пароль)
      // Просто возвращаем false, вызывающий код обработает ситуацию с автоматическим входом
      debugPrint('Token refresh failed: $e');
      return false;
    }
  }

  /// Выход из системы
  /// Важно: по умолчанию сохраняем телефон и пароль для автоматического входа
  Future<void> logout({bool clearSavedCredentials = false}) async {
    state = state.copyWith(isLoading: true);

    try {
      final refreshToken = await _secureStorage.getRefreshToken();
      if (refreshToken != null) {
        await _authService.logout(refreshToken);
      }
    } catch (e) {
      // Игнорируем ошибки при logout
    } finally {
      // Сохраняем телефон и пароль перед очисткой (для автоматического входа)
      final savedPhone = await _secureStorage.getPhone();
      final savedEmail = await _secureStorage.getEmail();
      final savedPassword = await _secureStorage.getPassword();
      
      // Очищаем токены и данные пользователя, но сохраняем учетные данные
      await _secureStorage.clearTokens();
      await _secureStorage.saveUserData(''); // Очищаем данные пользователя
      
      // Если нужно очистить учетные данные - очищаем их
      if (clearSavedCredentials) {
        await _secureStorage.savePhone('');
        await _secureStorage.saveEmail('');
        await _secureStorage.savePassword('');
      } else {
        // Восстанавливаем сохраненные учетные данные для автоматического входа
        if (savedPhone != null && savedPhone.isNotEmpty) {
          await _secureStorage.savePhone(savedPhone);
        }
        if (savedEmail != null && savedEmail.isNotEmpty) {
          await _secureStorage.saveEmail(savedEmail);
        }
        if (savedPassword != null && savedPassword.isNotEmpty) {
          await _secureStorage.savePassword(savedPassword);
        }
      }
      
      state = state.copyWith(
        isAuthenticated: false,
        user: null,
        isLoading: false,
        clearError: true,
      );
    }
  }

  /// Очистка ошибки
  void clearError() {
    state = state.copyWith(clearError: true);
  }

  /// Смена пароля текущего пользователя
  Future<void> changePassword({
    required String oldPassword,
    required String newPassword,
    required String confirmPassword,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      await _authService.changePassword(
        oldPassword: oldPassword,
        newPassword: newPassword,
        confirmPassword: confirmPassword,
      );
      state = state.copyWith(isLoading: false, clearError: true);
    } on AppException catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.message,
        exception: e,
      );
      rethrow;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Ошибка при смене пароля: ${e.toString()}',
      );
      rethrow;
    }
  }

  /// Обновление данных пользователя
  Future<void> refreshUser() async {
    if (!state.isAuthenticated) return;

    try {
      final user = await _authService.getCurrentUser();
      await _secureStorage.saveUserData(jsonEncode(user.toJson()));
      state = state.copyWith(user: user);
    } catch (e) {
      // Если не удалось обновить, проверяем токен
      if (e is AppException && e is UnauthorizedException) {
        await logout();
      }
    }
  }
}


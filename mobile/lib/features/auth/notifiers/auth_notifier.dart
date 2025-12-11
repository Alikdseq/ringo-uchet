import 'dart:convert';
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
  /// Оптимизировано: сначала загружаем из кэша, затем обновляем в фоне
  Future<void> _checkAuthStatus() async {
    final token = await _secureStorage.getAccessToken();
    if (token != null) {
      // СНАЧАЛА загружаем пользователя из кэша для мгновенного отображения
      final cachedUserData = await _secureStorage.getUserData();
      if (cachedUserData != null) {
        try {
          final userJson = jsonDecode(cachedUserData) as Map<String, dynamic>;
          final cachedUser = UserInfo.fromJson(userJson);
          // Устанавливаем состояние из кэша МГНОВЕННО
          state = state.copyWith(
            isAuthenticated: true,
            user: cachedUser,
            clearError: true,
          );
        } catch (e) {
          // Если кэш поврежден, игнорируем и загружаем с сервера
        }
      }
      
      // Затем в ФОНЕ обновляем данные с сервера
      _refreshUserInBackground();
    } else {
      // Если токена нет, просто устанавливаем состояние
      state = state.copyWith(
        isAuthenticated: false,
        user: null,
        clearError: true,
      );
    }
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
            // Если и после refresh не получилось, очищаем
          }
        }
        // Если токен недействителен, очищаем хранилище
        await _secureStorage.clearAll();
        state = state.copyWith(
          isAuthenticated: false,
          user: null,
          clearError: true,
        );
      }
      // Для других ошибок просто игнорируем - используем кэш
    }
  }

  /// Логин по телефону/email/username и паролю
  Future<void> login(LoginRequest request) async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final authResponse = await _authService.login(request);

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
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Неизвестная ошибка: ${e.toString()}',
        isAuthenticated: false,
      );
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
      final refreshToken = await _secureStorage.getRefreshToken();
      if (refreshToken == null) {
        return false;
      }

      final newAccessToken = await _authService.refreshToken(refreshToken);
      await _secureStorage.saveAccessToken(newAccessToken);
      return true;
    } catch (e) {
      // Если refresh не удался, делаем logout
      await logout();
      return false;
    }
  }

  /// Выход из системы
  Future<void> logout() async {
    state = state.copyWith(isLoading: true);

    try {
      final refreshToken = await _secureStorage.getRefreshToken();
      if (refreshToken != null) {
        await _authService.logout(refreshToken);
      }
    } catch (e) {
      // Игнорируем ошибки при logout
    } finally {
      // Очищаем все данные
      await _secureStorage.clearAll();
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


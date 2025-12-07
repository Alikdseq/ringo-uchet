import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/storage/secure_storage.dart';
import '../models/auth_models.dart';
import '../services/auth_service.dart';
import '../notifiers/auth_notifier.dart';

/// Провайдер состояния аутентификации
final authStateProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  final authService = ref.watch(authServiceProvider);
  final secureStorage = ref.watch(secureStorageProvider);
  return AuthNotifier(authService, secureStorage);
});

/// Провайдер текущего пользователя
final currentUserProvider = Provider<UserInfo?>((ref) {
  final authState = ref.watch(authStateProvider);
  return authState.user;
});

/// Провайдер проверки авторизации
final isAuthenticatedProvider = Provider<bool>((ref) {
  final authState = ref.watch(authStateProvider);
  return authState.isAuthenticated;
});


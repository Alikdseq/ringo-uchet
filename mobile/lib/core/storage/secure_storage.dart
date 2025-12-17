import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../constants/app_constants.dart';

/// Провайдер secure storage
final secureStorageProvider = Provider<SecureStorage>((ref) {
  return SecureStorage();
});

/// Класс для работы с безопасным хранилищем токенов
class SecureStorage {
  final _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
    ),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
  );

  /// Сохранить access token
  Future<void> saveAccessToken(String token) async {
    await _storage.write(key: AppConstants.storageTokenKey, value: token);
  }

  /// Получить access token
  Future<String?> getAccessToken() async {
    return await _storage.read(key: AppConstants.storageTokenKey);
  }

  /// Сохранить refresh token
  Future<void> saveRefreshToken(String token) async {
    await _storage.write(key: AppConstants.storageRefreshTokenKey, value: token);
  }

  /// Получить refresh token
  Future<String?> getRefreshToken() async {
    return await _storage.read(key: AppConstants.storageRefreshTokenKey);
  }

  /// Обновить токены (метод оставлен для обратной совместимости, но логика перенесена в AuthNotifier)
  @Deprecated('Используйте AuthNotifier.refreshToken() вместо этого')
  Future<bool> refreshToken() async {
    // Логика перенесена в AuthNotifier для правильной работы с state management
    return false;
  }

  /// Очистить все токены (не затрагивает сохраненные учетные данные)
  Future<void> clearTokens() async {
    await _storage.delete(key: AppConstants.storageTokenKey);
    await _storage.delete(key: AppConstants.storageRefreshTokenKey);
  }

  /// Сохранить данные пользователя
  Future<void> saveUserData(String data) async {
    await _storage.write(key: AppConstants.storageUserKey, value: data);
  }

  /// Получить данные пользователя
  Future<String?> getUserData() async {
    return await _storage.read(key: AppConstants.storageUserKey);
  }

  /// Сохранить номер телефона для автоматического входа
  Future<void> savePhone(String phone) async {
    await _storage.write(key: AppConstants.storagePhoneKey, value: phone);
  }

  /// Получить сохраненный номер телефона
  Future<String?> getPhone() async {
    return await _storage.read(key: AppConstants.storagePhoneKey);
  }

  /// Сохранить email для автоматического входа
  Future<void> saveEmail(String email) async {
    await _storage.write(key: AppConstants.storageEmailKey, value: email);
  }

  /// Получить сохраненный email
  Future<String?> getEmail() async {
    return await _storage.read(key: AppConstants.storageEmailKey);
  }

  /// Сохранить пароль для автоматического входа (в зашифрованном виде)
  Future<void> savePassword(String password) async {
    await _storage.write(key: AppConstants.storagePasswordKey, value: password);
  }

  /// Получить сохраненный пароль
  Future<String?> getPassword() async {
    return await _storage.read(key: AppConstants.storagePasswordKey);
  }

  /// Очистить все данные
  Future<void> clearAll() async {
    await _storage.deleteAll();
  }
}


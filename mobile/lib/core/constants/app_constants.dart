/// Константы приложения
class AppConstants {
  // API
  static const String apiTimeout = 'api_timeout';
  // Адаптивные таймауты: базовый для быстрых соединений, увеличенный для VPN/медленного интернета
  static const int defaultTimeoutSeconds = 20; // Базовый таймаут (оптимизирован для быстрых соединений)
  static const int slowConnectionTimeoutSeconds = 45; // Увеличенный таймаут для VPN/медленного интернета
  static const int preloadTimeoutSeconds = 30; // Таймаут для предзагрузки (увеличен для VPN)
  static const int maxRetryAttempts = 3;
  static const int slowConnectionThresholdMs = 2000; // Если запрос занимает >2 сек, считаем соединение медленным

  // Storage Keys
  static const String storageTokenKey = 'auth_token';
  static const String storageRefreshTokenKey = 'refresh_token';
  static const String storageUserKey = 'user_data';
  static const String storagePhoneKey = 'saved_phone';
  static const String storageEmailKey = 'saved_email';
  static const String storagePasswordKey = 'saved_password';
  static const String storageLocaleKey = 'locale';
  static const String storageThemeKey = 'theme_mode';

  // Cache Keys
  static const String cacheEquipmentKey = 'equipment_cache';
  static const String cacheServicesKey = 'services_cache';
  static const String cacheMaterialsKey = 'materials_cache';
  static const String cacheClientsKey = 'clients_cache';
  static const int cacheExpirationHours = 24;

  // Pagination
  static const int defaultPageSize = 20;
  static const int maxPageSize = 100;

  // File Upload
  static const int maxFileSizeMB = 10;
  static const List<String> allowedImageTypes = ['jpg', 'jpeg', 'png', 'webp'];
  static const List<String> allowedDocumentTypes = ['pdf', 'doc', 'docx'];

  // GPS
  static const double defaultAccuracy = 10.0; // meters
  static const int gpsTimeoutSeconds = 10;
}


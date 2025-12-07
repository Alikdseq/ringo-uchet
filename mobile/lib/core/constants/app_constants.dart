/// Константы приложения
class AppConstants {
  // API
  static const String apiTimeout = 'api_timeout';
  static const int defaultTimeoutSeconds = 30;
  static const int maxRetryAttempts = 3;

  // Storage Keys
  static const String storageTokenKey = 'auth_token';
  static const String storageRefreshTokenKey = 'refresh_token';
  static const String storageUserKey = 'user_data';
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


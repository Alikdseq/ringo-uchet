/// Конфигурация приложения для разных flavors
enum AppFlavor {
  dev,
  stage,
  prod,
}

class AppConfig {
  final AppFlavor flavor;
  final String apiBaseUrl;
  final String apiVersion;
  final bool enableLogging;
  final bool enableCrashlytics;
  final String appName;
  final String packageName;

  const AppConfig({
    required this.flavor,
    required this.apiBaseUrl,
    required this.apiVersion,
    required this.enableLogging,
    required this.enableCrashlytics,
    required this.appName,
    required this.packageName,
  });

  static AppConfig get dev => const AppConfig(
        flavor: AppFlavor.dev,
        apiBaseUrl: 'http://localhost:8001',
        apiVersion: 'v1',
        enableLogging: true,
        enableCrashlytics: false,
        appName: 'Ringo Dev',
        packageName: 'com.ringo.dev',
      );

  static AppConfig get stage => const AppConfig(
        flavor: AppFlavor.stage,
        apiBaseUrl: 'https://api.ringo.stage',
        apiVersion: 'v1',
        enableLogging: true,
        enableCrashlytics: true,
        appName: 'Ringo Stage',
        packageName: 'com.ringo.stage',
      );

  static AppConfig get prod => const AppConfig(
        flavor: AppFlavor.prod,
        apiBaseUrl: 'https://api.ringo.prod',
        apiVersion: 'v1',
        enableLogging: false,
        enableCrashlytics: true,
        appName: 'Ringo Uchet',
        packageName: 'com.ringo.prod',
      );

  String get apiUrl => '$apiBaseUrl/api/$apiVersion';
}


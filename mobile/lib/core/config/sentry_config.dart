import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// Конфигурация Sentry для отслеживания ошибок
class SentryConfig {
  static const String _dsn = String.fromEnvironment(
    'SENTRY_DSN',
    defaultValue: '',
  );

  static const String _environment = String.fromEnvironment(
    'SENTRY_ENVIRONMENT',
    defaultValue: 'production',
  );

  /// Инициализация Sentry
  static Future<void> init() async {
    if (_dsn.isEmpty) {
      // Sentry не настроен, пропускаем инициализацию
      return;
    }

    final packageInfo = await PackageInfo.fromPlatform();

    await SentryFlutter.init(
      (options) {
        options.dsn = _dsn;
        options.environment = _environment;
        options.release = '${packageInfo.packageName}@${packageInfo.version}+${packageInfo.buildNumber}';
        options.tracesSampleRate = 0.1; // 10% трейсов
        options.profilesSampleRate = 0.1; // 10% профилей
        options.enableAutoPerformanceTracing = true;
        options.enableUserInteractionTracing = true;
        
        // Настройки для production
        if (_environment == 'production') {
          options.beforeSend = (SentryEvent event, {dynamic hint}) {
            // Фильтрация чувствительных данных
            if (event.request?.data != null) {
              // Удаляем пароли и токены из событий
              final data = event.request!.data;
              if (data is Map) {
                data.removeWhere((key, value) => 
                  key.toString().toLowerCase().contains('password') ||
                  key.toString().toLowerCase().contains('token') ||
                  key.toString().toLowerCase().contains('secret')
                );
              }
            }
            return event;
          };
        }
      },
      appRunner: () {
        // Приложение запускается здесь после инициализации Sentry
      },
    );
  }

  /// Установка пользовательского контекста
  static Future<void> setUser({
    String? id,
    String? email,
    String? username,
  }) async {
    await Sentry.configureScope((scope) {
      scope.setUser(SentryUser(
        id: id,
        email: email,
        username: username,
      ));
    });
  }

  /// Очистка пользовательского контекста (при logout)
  static Future<void> clearUser() async {
    await Sentry.configureScope((scope) {
      scope.setUser(null);
    });
  }

  /// Отправка кастомного события
  static Future<void> captureException(
    dynamic exception, {
    dynamic stackTrace,
    Map<String, dynamic>? extra,
  }) async {
    await Sentry.captureException(
      exception,
      stackTrace: stackTrace,
      hint: Hint.withMap(extra ?? {}),
    );
  }

  /// Отправка сообщения
  static Future<void> captureMessage(
    String message, {
    SentryLevel level = SentryLevel.info,
    Map<String, dynamic>? extra,
  }) async {
    await Sentry.captureMessage(
      message,
      level: level,
      hint: Hint.withMap(extra ?? {}),
    );
  }

  /// Добавление breadcrumb
  static void addBreadcrumb(
    String message, {
    String? category,
    SentryLevel level = SentryLevel.info,
    Map<String, dynamic>? data,
  }) {
    Sentry.addBreadcrumb(
      Breadcrumb(
        message: message,
        category: category,
        level: level,
        data: data,
      ),
    );
  }
}


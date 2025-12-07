import 'dart:io';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'firebase_config.dart';
import 'app_config.dart';
import '../network/dio_client.dart'; // Для appConfigProvider

/// Провайдер Firebase Messaging
final firebaseMessagingProvider = Provider<FirebaseMessaging?>((ref) {
  final config = ref.watch(appConfigProvider);
  final firebaseConfig = _getFirebaseConfig(config.flavor);
  return firebaseConfig.enabled ? FirebaseMessaging.instance : null;
});

/// Провайдер Firebase Crashlytics
final firebaseCrashlyticsProvider = Provider<FirebaseCrashlytics?>((ref) {
  final config = ref.watch(appConfigProvider);
  final firebaseConfig = _getFirebaseConfig(config.flavor);
  return firebaseConfig.enabled ? FirebaseCrashlytics.instance : null;
});

FirebaseConfig _getFirebaseConfig(AppFlavor flavor) {
  switch (flavor) {
    case AppFlavor.dev:
      return FirebaseConfig.dev;
    case AppFlavor.stage:
      return FirebaseConfig.stage;
    case AppFlavor.prod:
      return FirebaseConfig.prod;
  }
}

/// Сервис для работы с Firebase
class FirebaseService {
  final FirebaseMessaging? messaging;
  final FirebaseCrashlytics? crashlytics;
  final FlutterLocalNotificationsPlugin localNotifications;
  final Function(RemoteMessage)? onNotificationTapped;

  FirebaseService({
    this.messaging,
    this.crashlytics,
    this.onNotificationTapped,
  }) : localNotifications = FlutterLocalNotificationsPlugin();

  /// Инициализация FCM
  Future<void> initializeFCM() async {
    if (messaging == null) return;

    // Инициализация локальных уведомлений
    await _initializeLocalNotifications();

    // Запрос разрешения на уведомления (iOS)
    final settings = await messaging!.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      debugPrint('User granted notification permission');
    } else {
      debugPrint('User declined or has not accepted notification permission');
    }

    // Получение FCM токена
    final token = await messaging!.getToken();
    if (token != null) {
      debugPrint('FCM Token: $token');
      // Токен будет отправлен через NotificationService после авторизации
    }

    // Обработка обновления токена
    messaging!.onTokenRefresh.listen((newToken) {
      debugPrint('FCM Token refreshed: $newToken');
      // TODO: Обновить токен на сервере
    });

    // Обработка сообщений в foreground
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // Обработка сообщений при открытии из фона
    FirebaseMessaging.onMessageOpenedApp.listen(_handleBackgroundMessage);

    // Обработка сообщения при открытии из terminated состояния
    final initialMessage = await messaging!.getInitialMessage();
    if (initialMessage != null) {
      _handleBackgroundMessage(initialMessage);
    }

    // Настройка обработчика для background сообщений
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  }

  /// Инициализация локальных уведомлений
  Future<void> _initializeLocalNotifications() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (details) {
        // Обработка нажатия на локальное уведомление
        if (details.payload != null) {
          _handleNotificationTap(details.payload!);
        }
      },
    );

    // Создание канала для Android
    if (Platform.isAndroid) {
      const androidChannel = AndroidNotificationChannel(
        'ringo_notifications',
        'Ringo Notifications',
        description: 'Уведомления приложения Ringo Uchet',
        importance: Importance.high,
        playSound: true,
      );

      await localNotifications
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(androidChannel);
    }
  }

  /// Обработка сообщений в foreground
  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    debugPrint('Foreground message: ${message.notification?.title}');

    // Показываем локальное уведомление
    final notification = message.notification;
    if (notification != null) {
      await localNotifications.show(
        message.hashCode,
        notification.title,
        notification.body,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'ringo_notifications',
            'Ringo Notifications',
            channelDescription: 'Уведомления приложения Ringo Uchet',
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(),
        ),
        payload: message.data.toString(),
      );
    }

    // Обработка данных для deep links
    if (message.data.isNotEmpty) {
      _handleNotificationData(message.data);
    }
  }

  /// Обработка сообщений из фона
  void _handleBackgroundMessage(RemoteMessage message) {
    debugPrint('Background message: ${message.notification?.title}');
    _handleNotificationData(message.data);
  }

  /// Обработка данных уведомления для deep links
  void _handleNotificationData(Map<String, dynamic> data) {
    // Обработка deep links
    final type = data['type'] as String?;
    final orderId = data['order_id'] as String?;

    if (type == 'order' && orderId != null) {
      // TODO: Навигация к заявке через navigatorKey
      debugPrint('Navigate to order: $orderId');
      if (onNotificationTapped != null) {
        // Создаём RemoteMessage для callback
        final message = RemoteMessage(
          data: data,
          notification: RemoteNotification(
            title: data['title'] as String?,
            body: data['body'] as String?,
          ),
        );
        onNotificationTapped!(message);
      }
    }
  }

  /// Обработка нажатия на уведомление
  void _handleNotificationTap(String payload) {
    // TODO: Парсинг payload и навигация
    debugPrint('Notification tapped: $payload');
  }

  /// Логирование ошибки в Crashlytics
  void logError(dynamic error, StackTrace? stackTrace, {bool fatal = false}) {
    crashlytics?.recordError(
      error,
      stackTrace,
      fatal: fatal,
    );
  }

  /// Логирование пользовательского события
  void logEvent(String message) {
    crashlytics?.log(message);
  }
}

/// Background handler для FCM (должен быть top-level функцией)
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  debugPrint('Background message: ${message.notification?.title}');
}

/// Провайдер Firebase Service
final firebaseServiceProvider = Provider<FirebaseService>((ref) {
  return FirebaseService(
    messaging: ref.watch(firebaseMessagingProvider),
    crashlytics: ref.watch(firebaseCrashlyticsProvider),
  );
});


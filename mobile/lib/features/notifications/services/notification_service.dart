import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/errors/app_exception.dart';

/// Провайдер сервиса уведомлений
final notificationServiceProvider = Provider<NotificationService>((ref) {
  final dio = ref.watch(dioClientProvider);
  return NotificationService(dio);
});

/// Сервис для работы с уведомлениями
class NotificationService {
  final Dio _dio;

  NotificationService(this._dio);

  /// Регистрация FCM токена устройства
  Future<void> registerDeviceToken({
    required String token,
    required String platform,
  }) async {
    try {
      final deviceInfo = DeviceInfoPlugin();
      final packageInfo = await PackageInfo.fromPlatform();

      Map<String, dynamic> deviceInfoData = {};
      if (platform == 'android') {
        final androidInfo = await deviceInfo.androidInfo;
        deviceInfoData = {
          'model': androidInfo.model,
          'manufacturer': androidInfo.manufacturer,
          'version': androidInfo.version.release,
          'sdkInt': androidInfo.version.sdkInt,
        };
      } else if (platform == 'ios') {
        final iosInfo = await deviceInfo.iosInfo;
        deviceInfoData = {
          'model': iosInfo.model,
          'name': iosInfo.name,
          'systemVersion': iosInfo.systemVersion,
          'identifierForVendor': iosInfo.identifierForVendor,
        };
      }

      await _dio.post(
        '/notifications/device-tokens/',
        data: {
          'token': token,
          'platform': platform,
          'app_version': packageInfo.version,
          'device_info': deviceInfoData,
        },
      );
    } on DioException catch (e) {
      throw _handleError(e);
    } catch (e) {
      if (e is AppException) rethrow;
      throw AppException.unknown('Неизвестная ошибка: ${e.toString()}');
    }
  }

  /// Получить настройки уведомлений
  Future<Map<String, dynamic>> getPreferences() async {
    try {
      final response = await _dio.get('/notifications/preferences/preferences/');
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw _handleError(e);
    } catch (e) {
      if (e is AppException) rethrow;
      throw AppException.unknown('Неизвестная ошибка: ${e.toString()}');
    }
  }

  /// Обновить настройки уведомлений
  Future<Map<String, dynamic>> updatePreferences(Map<String, dynamic> preferences) async {
    try {
      final response = await _dio.post(
        '/notifications/preferences/preferences/',
        data: preferences,
      );
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw _handleError(e);
    } catch (e) {
      if (e is AppException) rethrow;
      throw AppException.unknown('Неизвестная ошибка: ${e.toString()}');
    }
  }

  /// Получить историю уведомлений
  Future<List<Map<String, dynamic>>> getNotificationLogs() async {
    try {
      final response = await _dio.get('/notifications/preferences/logs/');
      return (response.data as List).cast<Map<String, dynamic>>();
    } on DioException catch (e) {
      throw _handleError(e);
    } catch (e) {
      if (e is AppException) rethrow;
      throw AppException.unknown('Неизвестная ошибка: ${e.toString()}');
    }
  }

  AppException _handleError(DioException error) {
    if (error.error is AppException) {
      return error.error as AppException;
    }

    switch (error.response?.statusCode) {
      case 400:
        return AppException.badRequest(
          _extractMessage(error.response?.data) ?? 'Неверный запрос',
        );
      case 401:
        return AppException.unauthorized('Требуется авторизация');
      case 403:
        return AppException.forbidden('Доступ запрещён');
      case 500:
      case 502:
      case 503:
        return AppException.server('Ошибка сервера');
      default:
        return AppException.network('Ошибка подключения к серверу');
    }
  }

  String? _extractMessage(dynamic data) {
    if (data is Map<String, dynamic>) {
      return data['detail'] as String? ?? data['message'] as String?;
    }
    return null;
  }
}


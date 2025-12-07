import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/notification_models.dart';
import '../services/notification_service.dart';

/// Провайдер настроек уведомлений
final notificationPreferencesProvider = StateNotifierProvider<NotificationPreferencesNotifier, NotificationPreferences>((ref) {
  final service = ref.watch(notificationServiceProvider);
  return NotificationPreferencesNotifier(service);
});

/// Notifier для управления настройками уведомлений
class NotificationPreferencesNotifier extends StateNotifier<NotificationPreferences> {
  final NotificationService _service;

  NotificationPreferencesNotifier(this._service) : super(const NotificationPreferences()) {
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    try {
      final prefs = await _service.getPreferences();
      state = NotificationPreferences.fromJson(prefs);
    } catch (e) {
      // Оставляем значения по умолчанию при ошибке
    }
  }

  Future<void> updatePreferences(NotificationPreferences preferences) async {
    try {
      await _service.updatePreferences(preferences.toJson());
      state = preferences;
    } catch (e) {
      rethrow;
    }
  }

  Future<void> refresh() async {
    await _loadPreferences();
  }
}


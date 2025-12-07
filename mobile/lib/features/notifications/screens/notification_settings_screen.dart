import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/notification_providers.dart';
import '../models/notification_models.dart';

/// Экран настроек уведомлений
class NotificationSettingsScreen extends ConsumerStatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  ConsumerState<NotificationSettingsScreen> createState() => _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState extends ConsumerState<NotificationSettingsScreen> {
  bool _isSaving = false;

  @override
  Widget build(BuildContext context) {
    final preferences = ref.watch(notificationPreferencesProvider);
    final notifier = ref.read(notificationPreferencesProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Настройки уведомлений'),
        actions: [
          if (_isSaving)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.save),
              onPressed: () async {
                setState(() => _isSaving = true);
                try {
                  await notifier.updatePreferences(preferences);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Настройки сохранены')),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Ошибка: ${e.toString()}')),
                    );
                  }
                } finally {
                  if (mounted) {
                    setState(() => _isSaving = false);
                  }
                }
              },
            ),
        ],
      ),
      body: ListView(
        children: [
          _buildSectionHeader('Типы уведомлений'),
          _buildSwitchTile(
            title: 'Создание заявки',
            subtitle: 'Уведомления о новых заявках',
            value: preferences.orderCreated,
            onChanged: (value) {
              notifier.updatePreferences(
                preferences.copyWith(orderCreated: value),
              );
            },
          ),
          _buildSwitchTile(
            title: 'Изменение статуса',
            subtitle: 'Уведомления об изменении статуса заявки',
            value: preferences.statusChanged,
            onChanged: (value) {
              notifier.updatePreferences(
                preferences.copyWith(statusChanged: value),
              );
            },
          ),
          _buildSwitchTile(
            title: 'Получение платежа',
            subtitle: 'Уведомления о получении платежей',
            value: preferences.paymentReceived,
            onChanged: (value) {
              notifier.updatePreferences(
                preferences.copyWith(paymentReceived: value),
              );
            },
          ),
          _buildSwitchTile(
            title: 'Счёт готов',
            subtitle: 'Уведомления о готовности счёта',
            value: preferences.invoiceReady,
            onChanged: (value) {
              notifier.updatePreferences(
                preferences.copyWith(invoiceReady: value),
              );
            },
          ),
          _buildSwitchTile(
            title: 'Касса заполнена',
            subtitle: 'Уведомления о заполнении кассы',
            value: preferences.kassaFull,
            onChanged: (value) {
              notifier.updatePreferences(
                preferences.copyWith(kassaFull: value),
              );
            },
          ),
          const Divider(),
          Padding(
            padding: const EdgeInsets.all(16),
            child: ElevatedButton.icon(
              onPressed: () async {
                await notifier.refresh();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Настройки обновлены')),
                  );
                }
              },
              icon: const Icon(Icons.refresh),
              label: const Text('Синхронизировать с сервером'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
      ),
    );
  }

  Widget _buildSwitchTile({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return SwitchListTile(
      title: Text(title),
      subtitle: Text(subtitle),
      value: value,
      onChanged: onChanged,
    );
  }
}


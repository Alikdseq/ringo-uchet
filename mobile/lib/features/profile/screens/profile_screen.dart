import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../features/auth/providers/auth_providers.dart';
import '../../notifications/screens/notification_settings_screen.dart';
import '../../orders/screens/offline_queue_screen.dart';
import 'change_password_screen.dart';

/// Экран профиля
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);
    final user = authState.user;

    return Scaffold(
      body: user == null
          ? const Center(child: Text('Пользователь не найден'))
          : ListView(
              children: [
                // Информация о пользователе
                _UserInfoCard(user: user),
                const Divider(),

                // Настройки
                _SettingsSection(),

                // Выход
                ListTile(
                  leading: const Icon(Icons.logout, color: Colors.red),
                  title: const Text('Выйти', style: TextStyle(color: Colors.red)),
                  onTap: () async {
                    await ref.read(authStateProvider.notifier).logout();
                    if (context.mounted) {
                      Navigator.pushReplacementNamed(context, '/login');
                    }
                  },
                ),
              ],
            ),
    );
  }
}

class _UserInfoCard extends StatelessWidget {
  final dynamic user; // UserInfo

  const _UserInfoCard({required this.user});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            CircleAvatar(
              radius: 40,
              backgroundColor: Theme.of(context).primaryColor,
              child: Text(
                user.fullName[0].toUpperCase(),
                style: const TextStyle(fontSize: 32, color: Colors.white),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              user.fullName,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              user.role ?? 'user',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey[600],
                  ),
            ),
            if (user.email != null) ...[
              const SizedBox(height: 8),
              Text(user.email!),
            ],
            if (user.phone != null) ...[
              const SizedBox(height: 4),
              Text(user.phone!),
            ],
          ],
        ),
      ),
    );
  }
}

class _SettingsSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'Настройки',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
        ),
        ListTile(
          leading: const Icon(Icons.notifications),
          title: const Text('Уведомления'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const NotificationSettingsScreen(),
              ),
            );
          },
        ),
        ListTile(
          leading: const Icon(Icons.lock),
          title: const Text('Смена пароля'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const ChangePasswordScreen(),
              ),
            );
          },
        ),
        ListTile(
          leading: const Icon(Icons.sync),
          title: const Text('Оффлайн очередь'),
          subtitle: const Text('Несинхронизированные действия'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const OfflineQueueScreen(),
              ),
            );
          },
        ),
      ],
    );
  }
}


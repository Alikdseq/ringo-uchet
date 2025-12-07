import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/network/connectivity_service.dart';

/// Виджет баннера оффлайн статуса
class OfflineBanner extends ConsumerWidget {
  const OfflineBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connectionStatus = ref.watch(connectionStatusProvider);

    return connectionStatus.when(
      data: (status) {
        if (status == ConnectionStatus.disconnected) {
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: Colors.orange,
            child: Row(
              children: [
                const Icon(Icons.wifi_off, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Работа в оффлайн режиме',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          );
        }
        return const SizedBox.shrink();
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}


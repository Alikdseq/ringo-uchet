import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/offline/offline_queue_service.dart';
import '../../features/orders/screens/offline_queue_screen.dart';

/// Виджет индикатора оффлайн очереди
class OfflineQueueIndicator extends ConsumerWidget {
  const OfflineQueueIndicator({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final queueService = ref.watch(offlineQueueServiceProvider);
    
    return FutureBuilder<int>(
      future: queueService.getQueueCount(),
      builder: (context, snapshot) {
        final count = snapshot.data ?? 0;
        
        if (count == 0) {
          return const SizedBox.shrink();
        }

        return GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const OfflineQueueScreen(),
              ),
            );
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.orange,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.cloud_upload, color: Colors.white, size: 16),
                const SizedBox(width: 4),
                Text(
                  '$count',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}


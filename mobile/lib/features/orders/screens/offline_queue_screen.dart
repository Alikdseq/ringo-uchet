import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/offline/offline_queue_service.dart';
import '../../../core/offline/sync_service.dart';

/// Экран Offline Queue
class OfflineQueueScreen extends ConsumerStatefulWidget {
  const OfflineQueueScreen({super.key});

  @override
  ConsumerState<OfflineQueueScreen> createState() => _OfflineQueueScreenState();
}

class _OfflineQueueScreenState extends ConsumerState<OfflineQueueScreen> {
  List<OfflineQueueItem> _queueItems = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadQueue();
  }

  Future<void> _loadQueue() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final queueService = ref.read(offlineQueueServiceProvider);
      final items = await queueService.getQueueItems();
      setState(() {
        _queueItems = items;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _retryItem(OfflineQueueItem item) async {
    try {
      final syncService = ref.read(syncServiceProvider);
      await syncService.syncQueue();
      await _loadQueue();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Синхронизация запущена')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _deleteItem(OfflineQueueItem item) async {
    if (item.id == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удалить из очереди?'),
        content: const Text('Это действие нельзя отменить'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final queueService = ref.read(offlineQueueServiceProvider);
        await queueService.removeFromQueue(item.id!);
        await _loadQueue();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Ошибка: ${e.toString()}')),
          );
        }
      }
    }
  }

  Future<void> _syncAll() async {
    try {
      final syncService = ref.read(syncServiceProvider);
      await syncService.syncQueue();
      await _loadQueue();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Синхронизация завершена')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка: ${e.toString()}')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Оффлайн очередь'),
        actions: [
          if (_queueItems.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.sync),
              onPressed: _syncAll,
              tooltip: 'Синхронизировать все',
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadQueue,
            tooltip: 'Обновить',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _queueItems.isEmpty
              ? const Center(child: Text('Очередь пуста'))
              : ListView.builder(
                  itemCount: _queueItems.length,
                  itemBuilder: (context, index) {
                    final item = _queueItems[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      child: ListTile(
                        title: Text(_getActionLabel(item.action)),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('${item.method} ${item.endpoint}'),
                            if (item.errorMessage != null)
                              Text(
                                item.errorMessage!,
                                style: TextStyle(
                                  color: Colors.red[700],
                                  fontSize: 12,
                                ),
                              ),
                            if (item.retryCount != null && item.retryCount! > 0)
                              Text(
                                'Попыток: ${item.retryCount}',
                                style: const TextStyle(fontSize: 12),
                              ),
                            Text(
                              'Создано: ${_formatDateTime(item.createdAt)}',
                              style: const TextStyle(fontSize: 12),
                            ),
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.refresh),
                              onPressed: () => _retryItem(item),
                              tooltip: 'Повторить',
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete),
                              onPressed: () => _deleteItem(item),
                              tooltip: 'Удалить',
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }

  String _getActionLabel(OfflineActionType action) {
    switch (action) {
      case OfflineActionType.createOrder:
        return 'Создание заявки';
      case OfflineActionType.updateOrder:
        return 'Обновление заявки';
      case OfflineActionType.changeStatus:
        return 'Изменение статуса';
      case OfflineActionType.uploadPhoto:
        return 'Загрузка фото';
      case OfflineActionType.deleteOrder:
        return 'Удаление заявки';
    }
  }

  String _formatDateTime(DateTime date) {
    return '${date.day}.${date.month}.${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }
}


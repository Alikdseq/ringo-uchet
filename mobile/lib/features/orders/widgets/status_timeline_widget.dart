import 'package:flutter/material.dart';
import '../../../core/constants/status_colors.dart';
import '../models/order_models.dart';

/// Виджет таймлайна статусов
class StatusTimelineWidget extends StatelessWidget {
  final List<OrderStatusLog> logs;

  const StatusTimelineWidget({
    super.key,
    required this.logs,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: logs.length,
      itemBuilder: (context, index) {
        final log = logs[index];
        final isLast = index == logs.length - 1;

        return _TimelineItem(
          log: log,
          isLast: isLast,
        );
      },
    );
  }
}

class _TimelineItem extends StatelessWidget {
  final OrderStatusLog log;
  final bool isLast;

  const _TimelineItem({
    required this.log,
    required this.isLast,
  });

  @override
  Widget build(BuildContext context) {
    final statusColor = StatusColors.getOrderStatusColor(log.toStatus.toUpperCase());

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Линия и точка
        Column(
          children: [
            Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                color: statusColor,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
            ),
            if (!isLast)
              Container(
                width: 2,
                height: 60,
                color: Colors.grey[300],
              ),
          ],
        ),
        const SizedBox(width: 16),
        // Контент
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _getStatusLabel(log.toStatus),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: statusColor,
                      ),
                    ),
                    Text(
                      _formatDateTime(log.createdAt),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.grey[600],
                          ),
                    ),
                  ],
                ),
                if (log.actorName != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Изменил: ${log.actorName}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
                if (log.comment.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    log.comment,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  String _getStatusLabel(String status) {
    switch (status.toUpperCase()) {
      case 'DRAFT':
        return 'Черновик';
      case 'CREATED':
        return 'Создан';
      case 'APPROVED':
        return 'Одобрен';
      case 'IN_PROGRESS':
        return 'В работе';
      case 'COMPLETED':
        return 'Завершён';
      case 'CANCELLED':
        return 'Отменён';
      default:
        return status;
    }
  }

  String _formatDateTime(DateTime date) {
    return '${date.day}.${date.month}.${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }
}


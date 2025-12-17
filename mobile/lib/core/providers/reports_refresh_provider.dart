import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Провайдер для триггера обновления отчетов
/// Используется для мгновенного обновления отчетов после изменения заявок
final reportsRefreshProvider = StateProvider<int>((ref) => 0);

/// Функция для триггера обновления отчетов
void triggerReportsRefresh(WidgetRef ref) {
  ref.read(reportsRefreshProvider.notifier).state++;
}


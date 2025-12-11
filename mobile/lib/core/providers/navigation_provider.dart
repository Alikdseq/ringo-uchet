import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Провайдер для управления индексом нижней панели навигации
final navigationIndexProvider = StateNotifierProvider<NavigationIndexNotifier, int>((ref) {
  return NavigationIndexNotifier();
});

class NavigationIndexNotifier extends StateNotifier<int> {
  NavigationIndexNotifier() : super(0);

  void setIndex(int index) {
    state = index;
  }

  void navigateToOrders() {
    state = 1; // Индекс экрана заявок
  }
}


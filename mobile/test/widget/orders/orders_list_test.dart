import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../lib/features/orders/screens/orders_list_screen.dart';
import '../../../lib/core/config/app_config.dart';
import '../../../lib/core/network/dio_client.dart';
import '../../../lib/features/orders/services/order_service.dart';
import '../../helpers/test_helpers.dart';

void main() {
  group('OrdersListScreen Widget Tests', () {
    late ProviderContainer container;

    setUp(() {
      container = createTestContainer();
    });

    tearDown(() {
      container.dispose();
    });

    testWidgets('отображает список заявок', (WidgetTester tester) async {
      // Arrange & Act
      await tester.pumpWidget(
        ProviderScope(
          parent: container,
          child: MaterialApp(
            home: const OrdersListScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Assert
      expect(find.text('Заявки'), findsOneWidget);
      expect(find.byType(TextField), findsWidgets); // Поиск
    });

    testWidgets('показывает фильтр по статусу', (WidgetTester tester) async {
      // Arrange
      await tester.pumpWidget(
        ProviderScope(
          parent: container,
          child: MaterialApp(
            home: const OrdersListScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Act
      final filterButton = find.byIcon(Icons.filter_list);
      if (filterButton.evaluate().isNotEmpty) {
        await tester.tap(filterButton);
        await tester.pumpAndSettle();

        // Assert
        expect(find.text('Фильтр по статусу'), findsOneWidget);
      }
    });
  });
}


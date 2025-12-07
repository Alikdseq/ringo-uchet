import 'package:flutter_test/flutter_test.dart';
import 'package:dio/dio.dart';
import 'package:mocktail/mocktail.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../lib/features/orders/services/order_service.dart';
import '../../../../lib/features/orders/models/order_models.dart';
import '../../../../lib/core/errors/app_exception.dart';
import '../helpers/test_helpers.dart';

void main() {
  group('OrderService', () {
    late MockDio mockDio;
    late ProviderContainer container;

    setUp(() {
      mockDio = MockDio();
      container = createTestContainer(dio: mockDio);
    });

    tearDown(() {
      container.dispose();
    });

    test('getOrders успешно возвращает список заказов', () async {
      // Arrange
      final response = Response(
        data: [TestData.orderData],
        statusCode: 200,
        requestOptions: RequestOptions(path: '/api/orders/'),
      );
      when(() => mockDio.get(any(), queryParameters: any(named: 'queryParameters')))
          .thenAnswer((_) async => response);

      final service = container.read(orderServiceProvider);

      // Act
      final orders = await service.getOrders();

      // Assert
      expect(orders, isNotEmpty);
      expect(orders.first.id, equals('test-order-id'));
      expect(orders.first.number, equals('ORD-001'));
    });

    test('getOrder успешно возвращает заказ по ID', () async {
      // Arrange
      final response = Response(
        data: TestData.orderData,
        statusCode: 200,
        requestOptions: RequestOptions(path: '/api/orders/test-id/'),
      );
      when(() => mockDio.get(any()))
          .thenAnswer((_) async => response);

      final service = container.read(orderServiceProvider);

      // Act
      final order = await service.getOrder('test-id');

      // Assert
      expect(order.id, equals('test-order-id'));
      expect(order.number, equals('ORD-001'));
    });

    test('createOrder успешно создаёт заказ', () async {
      // Arrange
      final response = Response(
        data: TestData.orderData,
        statusCode: 201,
        requestOptions: RequestOptions(path: '/api/orders/'),
      );
      when(() => mockDio.post(any(), data: any(named: 'data')))
          .thenAnswer((_) async => response);

      final service = container.read(orderServiceProvider);
      final request = OrderRequest(
        address: 'Test Address',
        startDt: DateTime.now(),
        description: 'Test Description',
      );

      // Act
      final order = await service.createOrder(request);

      // Assert
      expect(order.id, equals('test-order-id'));
      verify(() => mockDio.post('/api/orders/', data: any(named: 'data'))).called(1);
    });

    test('changeOrderStatus успешно изменяет статус', () async {
      // Arrange
      final statusResponse = Response(
        data: {'status': 'APPROVED'},
        statusCode: 200,
        requestOptions: RequestOptions(path: '/api/orders/test-id/status/'),
      );
      final orderResponse = Response(
        data: TestData.orderData..['status'] = 'APPROVED',
        statusCode: 200,
        requestOptions: RequestOptions(path: '/api/orders/test-id/'),
      );
      when(() => mockDio.patch(any(), data: any(named: 'data')))
          .thenAnswer((_) async => statusResponse);
      when(() => mockDio.get(any()))
          .thenAnswer((_) async => orderResponse);

      final service = container.read(orderServiceProvider);
      final request = OrderStatusRequest(
        status: OrderStatus.approved,
        comment: 'Approved',
      );

      // Act
      final order = await service.changeOrderStatus('test-id', request);

      // Assert
      expect(order.status, equals(OrderStatus.approved));
    });
  });
}


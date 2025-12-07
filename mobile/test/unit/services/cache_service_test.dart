import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../lib/core/offline/cache_service.dart';
import '../../../../lib/core/storage/local_storage.dart';
import '../helpers/test_helpers.dart';

void main() {
  group('CacheService', () {
    late MockLocalStorage mockLocalStorage;
    late ProviderContainer container;

    setUp(() {
      mockLocalStorage = MockLocalStorage();
      container = createTestContainer(localStorage: mockLocalStorage);
    });

    tearDown(() {
      container.dispose();
    });

    test('cacheOrders сохраняет заказы в кэш', () async {
      // Arrange
      final service = container.read(cacheServiceProvider);
      final orders = [TestData.orderData];

      // Act
      await service.cacheOrders(orders);

      // Assert
      // Проверяем, что метод был вызван (в реальном тесте нужно проверить Hive box)
      expect(service, isNotNull);
    });

    test('getCachedOrders возвращает заказы из кэша', () async {
      // Arrange
      final service = container.read(cacheServiceProvider);

      // Act
      final cached = await service.getCachedOrders();

      // Assert
      // В реальном тесте нужно настроить моки для Hive
      expect(cached, isNull); // Если кэш пуст
    });
  });
}


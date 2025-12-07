import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mocktail/mocktail.dart';
import 'package:dio/dio.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart' as sqflite_ffi;
import '../../lib/core/network/dio_client.dart';
import '../../lib/core/storage/secure_storage.dart';
import '../../lib/core/storage/local_storage.dart';
import '../../lib/core/config/app_config.dart';
import '../../lib/features/auth/services/auth_service.dart';
import '../../lib/features/orders/services/order_service.dart';
import '../../lib/features/catalog/services/catalog_service.dart';
import '../../lib/core/offline/cache_service.dart';
import '../../lib/core/offline/offline_queue_service.dart';
import '../../lib/core/network/connectivity_service.dart';

/// Инициализация для тестов
void initTestDatabase() {
  sqflite_ffi.sqfliteFfiInit();
  sqflite_ffi.databaseFactory = sqflite_ffi.databaseFactoryFfi;
}

/// Моки для тестирования
class MockDio extends Mock implements Dio {}
class MockSecureStorage extends Mock implements SecureStorage {}
class MockLocalStorage extends Mock implements LocalStorage {}
class MockConnectivityService extends Mock implements ConnectivityService {}

/// Настройка тестового окружения
ProviderContainer createTestContainer({
  Dio? dio,
  SecureStorage? secureStorage,
  LocalStorage? localStorage,
  ConnectivityService? connectivityService,
}) {
  final container = ProviderContainer(
    overrides: [
      if (dio != null) dioClientProvider.overrideWithValue(dio),
      if (secureStorage != null) secureStorageProvider.overrideWithValue(secureStorage),
      if (localStorage != null) localStorageProvider.overrideWithValue(localStorage),
      if (connectivityService != null) connectivityServiceProvider.overrideWithValue(connectivityService),
      appConfigProvider.overrideWithValue(AppConfig.dev),
    ],
  );
  return container;
}

/// Хелпер для создания тестовых данных
class TestData {
  static Map<String, dynamic> get authResponse => {
        'access': 'test_access_token',
        'refresh': 'test_refresh_token',
        'user': {
          'id': 1,
          'username': 'testuser',
          'email': 'test@example.com',
          'phone': '+79991234567',
          'first_name': 'Test',
          'last_name': 'User',
          'role': 'manager',
        },
      };

  static Map<String, dynamic> get orderData => {
        'id': 'test-order-id',
        'number': 'ORD-001',
        'address': 'Test Address',
        'start_dt': '2025-01-01T10:00:00Z',
        'description': 'Test Order',
        'status': 'CREATED',
        'prepayment_amount': '0.00',
        'prepayment_status': 'pending',
        'total_amount': '1000.00',
        'attachments': [],
        'meta': {},
        'created_at': '2025-01-01T09:00:00Z',
        'updated_at': '2025-01-01T09:00:00Z',
      };

  static Map<String, dynamic> get equipmentData => {
        'id': 1,
        'code': 'EQ-001',
        'name': 'Test Equipment',
        'description': 'Test Description',
        'hourly_rate': '1500.00',
        'status': 'available',
        'photos': [],
        'attributes': {},
      };
}


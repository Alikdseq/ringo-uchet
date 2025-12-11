import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../storage/local_storage.dart';
import '../storage/indexed_db_storage.dart';
import '../constants/app_constants.dart';

/// Провайдер сервиса кэширования
final cacheServiceProvider = Provider<CacheService>((ref) {
  return CacheService(ref);
});

/// Сервис для кэширования данных
class CacheService {
  final Ref _ref;
  static const String _ordersBox = 'orders_cache';
  static const String _equipmentBox = 'equipment_cache';
  static const String _servicesBox = 'services_cache';
  static const String _materialsBox = 'materials_cache';
  static const String _clientsBox = 'clients_cache';
  
  // IndexedDB для web (постоянное хранилище)
  IndexedDbStorage? _indexedDb;
  bool _indexedDbInitialized = false;

  CacheService(this._ref) {
    if (kIsWeb) {
      _initIndexedDb();
    }
  }

  /// Инициализация IndexedDB для web
  Future<void> _initIndexedDb() async {
    if (!kIsWeb || _indexedDbInitialized) return;
    try {
      _indexedDb = IndexedDbStorage();
      await _indexedDb!.init();
      _indexedDbInitialized = true;
    } catch (e) {
      // IndexedDB недоступен, используем Hive
    }
  }

  /// Инициализация кэш боксов
  Future<void> _initBoxes() async {
    final boxes = [
      _ordersBox,
      _equipmentBox,
      _servicesBox,
      _materialsBox,
      _clientsBox,
    ];

    for (final boxName in boxes) {
      if (!Hive.isBoxOpen(boxName)) {
        await Hive.openBox(boxName);
      }
    }
  }

  /// Получить box для заказов
  Future<Box> _getOrdersBox() async {
    await _initBoxes();
    return Hive.box(_ordersBox);
  }

  /// Получить box для оборудования
  Future<Box> _getEquipmentBox() async {
    await _initBoxes();
    return Hive.box(_equipmentBox);
  }

  /// Получить box для услуг
  Future<Box> _getServicesBox() async {
    await _initBoxes();
    return Hive.box(_servicesBox);
  }

  /// Получить box для материалов
  Future<Box> _getMaterialsBox() async {
    await _initBoxes();
    return Hive.box(_materialsBox);
  }

  /// Получить box для клиентов
  Future<Box> _getClientsBox() async {
    await _initBoxes();
    return Hive.box(_clientsBox);
  }

  /// Сохранить заказы в кэш
  Future<void> cacheOrders(List<dynamic> orders) async {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    
    // На web используем IndexedDB для постоянного хранения
    if (kIsWeb && _indexedDbInitialized && _indexedDb != null) {
      try {
        await _indexedDb!.put('orders', orders);
        await _indexedDb!.put('orders_timestamp', timestamp);
        return;
      } catch (e) {
        // Fallback на Hive
      }
    }
    
    // Для мобильных платформ используем Hive
    final box = await _getOrdersBox();
    await box.put('orders', jsonEncode(orders));
    await box.put('orders_timestamp', timestamp);
  }

  /// Получить заказы из кэша
  Future<List<dynamic>?> getCachedOrders() async {
    // На web используем IndexedDB для постоянного хранения
    if (kIsWeb && _indexedDbInitialized && _indexedDb != null) {
      try {
        final timestamp = await _indexedDb!.get('orders_timestamp') as int?;
        if (timestamp == null) return null;

        // Проверяем, не истёк ли кэш (24 часа)
        final cacheAge = DateTime.now().millisecondsSinceEpoch - timestamp;
        const cacheExpiration = AppConstants.cacheExpirationHours * 60 * 60 * 1000;

        if (cacheAge > cacheExpiration) {
          await _indexedDb!.delete('orders');
          await _indexedDb!.delete('orders_timestamp');
          return null;
        }

        final orders = await _indexedDb!.get('orders') as List<dynamic>?;
        return orders;
      } catch (e) {
        // Fallback на Hive
      }
    }
    
    // Для мобильных платформ используем Hive
    final box = await _getOrdersBox();
    final timestamp = box.get('orders_timestamp') as int?;

    if (timestamp == null) return null;

    // Проверяем, не истёк ли кэш (24 часа)
    final cacheAge = DateTime.now().millisecondsSinceEpoch - timestamp;
    const cacheExpiration = AppConstants.cacheExpirationHours * 60 * 60 * 1000;

    if (cacheAge > cacheExpiration) {
      await box.delete('orders');
      await box.delete('orders_timestamp');
      return null;
    }

    final ordersJson = box.get('orders') as String?;
    if (ordersJson == null) return null;

    return jsonDecode(ordersJson) as List<dynamic>;
  }

  /// Сохранить оборудование в кэш
  Future<void> cacheEquipment(List<dynamic> equipment) async {
    final box = await _getEquipmentBox();
    await box.put('equipment', jsonEncode(equipment));
    await box.put('equipment_timestamp', DateTime.now().millisecondsSinceEpoch);
  }

  /// Получить оборудование из кэша
  Future<List<dynamic>?> getCachedEquipment() async {
    final box = await _getEquipmentBox();
    final timestamp = box.get('equipment_timestamp') as int?;

    if (timestamp == null) return null;

    final cacheAge = DateTime.now().millisecondsSinceEpoch - timestamp;
    const cacheExpiration = AppConstants.cacheExpirationHours * 60 * 60 * 1000;

    if (cacheAge > cacheExpiration) {
      await box.delete('equipment');
      await box.delete('equipment_timestamp');
      return null;
    }

    final equipmentJson = box.get('equipment') as String?;
    if (equipmentJson == null) return null;

    return jsonDecode(equipmentJson) as List<dynamic>;
  }

  /// Сохранить услуги в кэш
  Future<void> cacheServices(List<dynamic> services) async {
    final box = await _getServicesBox();
    await box.put('services', jsonEncode(services));
    await box.put('services_timestamp', DateTime.now().millisecondsSinceEpoch);
  }

  /// Получить услуги из кэша
  Future<List<dynamic>?> getCachedServices() async {
    final box = await _getServicesBox();
    final timestamp = box.get('services_timestamp') as int?;

    if (timestamp == null) return null;

    final cacheAge = DateTime.now().millisecondsSinceEpoch - timestamp;
    const cacheExpiration = AppConstants.cacheExpirationHours * 60 * 60 * 1000;

    if (cacheAge > cacheExpiration) {
      await box.delete('services');
      await box.delete('services_timestamp');
      return null;
    }

    final servicesJson = box.get('services') as String?;
    if (servicesJson == null) return null;

    return jsonDecode(servicesJson) as List<dynamic>;
  }

  /// Сохранить материалы в кэш
  Future<void> cacheMaterials(List<dynamic> materials) async {
    final box = await _getMaterialsBox();
    await box.put('materials', jsonEncode(materials));
    await box.put('materials_timestamp', DateTime.now().millisecondsSinceEpoch);
  }

  /// Получить материалы из кэша
  Future<List<dynamic>?> getCachedMaterials() async {
    final box = await _getMaterialsBox();
    final timestamp = box.get('materials_timestamp') as int?;

    if (timestamp == null) return null;

    final cacheAge = DateTime.now().millisecondsSinceEpoch - timestamp;
    const cacheExpiration = AppConstants.cacheExpirationHours * 60 * 60 * 1000;

    if (cacheAge > cacheExpiration) {
      await box.delete('materials');
      await box.delete('materials_timestamp');
      return null;
    }

    final materialsJson = box.get('materials') as String?;
    if (materialsJson == null) return null;

    return jsonDecode(materialsJson) as List<dynamic>;
  }

  /// Сохранить клиентов в кэш
  Future<void> cacheClients(List<dynamic> clients) async {
    final box = await _getClientsBox();
    await box.put('clients', jsonEncode(clients));
    await box.put('clients_timestamp', DateTime.now().millisecondsSinceEpoch);
  }

  /// Получить клиентов из кэша
  Future<List<dynamic>?> getCachedClients() async {
    final box = await _getClientsBox();
    final timestamp = box.get('clients_timestamp') as int?;

    if (timestamp == null) return null;

    final cacheAge = DateTime.now().millisecondsSinceEpoch - timestamp;
    const cacheExpiration = AppConstants.cacheExpirationHours * 60 * 60 * 1000;

    if (cacheAge > cacheExpiration) {
      await box.delete('clients');
      await box.delete('clients_timestamp');
      return null;
    }

    final clientsJson = box.get('clients') as String?;
    if (clientsJson == null) return null;

    return jsonDecode(clientsJson) as List<dynamic>;
  }

  /// Очистить весь кэш
  Future<void> clearCache() async {
    final boxes = [
      await _getOrdersBox(),
      await _getEquipmentBox(),
      await _getServicesBox(),
      await _getMaterialsBox(),
      await _getClientsBox(),
    ];

    for (final box in boxes) {
      await box.clear();
    }
  }
}

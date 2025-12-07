import 'package:json_annotation/json_annotation.dart';

part 'catalog_models.g.dart';

/// Статусы техники
enum EquipmentStatus {
  @JsonValue('available')
  available,
  @JsonValue('busy')
  busy,
  @JsonValue('maintenance')
  maintenance,
  @JsonValue('inactive')
  inactive,
}

/// Модель техники
@JsonSerializable()
class Equipment {
  final int id;
  final String code;
  final String name;
  final String description;
  @JsonKey(name: 'hourly_rate', fromJson: _stringToDouble)
  final double hourlyRate;
  @JsonKey(name: 'daily_rate', fromJson: _stringToDoubleNullable)
  final double? dailyRate;
  @JsonKey(name: 'fuel_consumption', fromJson: _stringToDoubleNullable)
  final double? fuelConsumption;
  final EquipmentStatus status;
  final List<String> photos;
  @JsonKey(name: 'last_maintenance_date')
  final DateTime? lastMaintenanceDate;
  final Map<String, dynamic> attributes;

  // Вспомогательные функции для конвертации строк в числа
  static double _stringToDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is num) return value.toDouble();
    if (value is String) {
      try {
        return double.parse(value);
      } catch (e) {
        return 0.0;
      }
    }
    return 0.0;
  }

  static double? _stringToDoubleNullable(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    if (value is String) {
      try {
        return double.parse(value);
      } catch (e) {
        return null;
      }
    }
    return null;
  }

  const Equipment({
    required this.id,
    required this.code,
    required this.name,
    required this.description,
    required this.hourlyRate,
    this.dailyRate,
    this.fuelConsumption,
    required this.status,
    required this.photos,
    this.lastMaintenanceDate,
    required this.attributes,
  });

  factory Equipment.fromJson(Map<String, dynamic> json) =>
      _$EquipmentFromJson(json);
  Map<String, dynamic> toJson() => _$EquipmentToJson(this);
}

/// Категория услуг
@JsonSerializable()
class ServiceCategory {
  final int id;
  final String name;
  final String description;
  @JsonKey(name: 'sort_order')
  final int sortOrder;

  const ServiceCategory({
    required this.id,
    required this.name,
    required this.description,
    required this.sortOrder,
  });

  factory ServiceCategory.fromJson(Map<String, dynamic> json) =>
      _$ServiceCategoryFromJson(json);
  Map<String, dynamic> toJson() => _$ServiceCategoryToJson(this);
}

/// Услуга
@JsonSerializable()
class ServiceItem {
  final int id;
  @JsonKey(fromJson: _categoryToInt)
  final int category;
  @JsonKey(name: 'category_name')
  final String? categoryName;
  final String name;
  final String unit;
  @JsonKey(fromJson: _stringToDouble)
  final double price;
  @JsonKey(name: 'default_duration', fromJson: _stringToDoubleNullable)
  final double? defaultDuration;
  @JsonKey(name: 'included_items')
  final List<dynamic> includedItems;
  @JsonKey(name: 'is_active')
  final bool isActive;

  // Вспомогательные функции для конвертации строк в числа
  static double _stringToDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is num) return value.toDouble();
    if (value is String) {
      try {
        return double.parse(value);
      } catch (e) {
        return 0.0;
      }
    }
    return 0.0;
  }

  static double? _stringToDoubleNullable(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    if (value is String) {
      try {
        return double.parse(value);
      } catch (e) {
        return null;
      }
    }
    return null;
  }

  // Конвертация category из объекта или числа
  static int _categoryToInt(dynamic value) {
    if (value == null) return 0;
    if (value is num) return value.toInt();
    if (value is Map<String, dynamic>) {
      // Если category приходит как объект, извлекаем id
      return (value['id'] as num?)?.toInt() ?? 0;
    }
    return 0;
  }

  const ServiceItem({
    required this.id,
    required this.category,
    this.categoryName,
    required this.name,
    required this.unit,
    required this.price,
    this.defaultDuration,
    required this.includedItems,
    required this.isActive,
  });

  factory ServiceItem.fromJson(Map<String, dynamic> json) =>
      _$ServiceItemFromJson(json);
  Map<String, dynamic> toJson() => _$ServiceItemToJson(this);
}

/// Материал
@JsonSerializable()
class MaterialItem {
  final int id;
  final String name;
  final String category;
  final String unit;
  @JsonKey(fromJson: _stringToDouble)
  final double price;
  @JsonKey(fromJson: _stringToDoubleNullable)
  final double? density;
  final String? supplier;
  @JsonKey(name: 'is_active')
  final bool isActive;

  // Вспомогательные функции для конвертации строк в числа
  static double _stringToDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is num) return value.toDouble();
    if (value is String) {
      try {
        return double.parse(value);
      } catch (e) {
        return 0.0;
      }
    }
    return 0.0;
  }

  static double? _stringToDoubleNullable(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    if (value is String) {
      try {
        return double.parse(value);
      } catch (e) {
        return null;
      }
    }
    return null;
  }

  const MaterialItem({
    required this.id,
    required this.name,
    required this.category,
    required this.unit,
    required this.price,
    this.density,
    this.supplier,
    required this.isActive,
  });

  factory MaterialItem.fromJson(Map<String, dynamic> json) =>
      _$MaterialItemFromJson(json);
  Map<String, dynamic> toJson() => _$MaterialItemToJson(this);
}

/// Навеска
@JsonSerializable()
class Attachment {
  final int id;
  final int equipment;
  @JsonKey(name: 'equipment_name')
  final String? equipmentName;
  @JsonKey(name: 'equipment_code')
  final String? equipmentCode;
  final String name;
  @JsonKey(name: 'pricing_modifier', fromJson: _stringToDouble)
  final double pricingModifier;
  final EquipmentStatus status;
  final Map<String, dynamic> metadata;

  // Вспомогательная функция для конвертации строк в числа
  static double _stringToDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is num) return value.toDouble();
    if (value is String) {
      try {
        return double.parse(value);
      } catch (e) {
        return 0.0;
      }
    }
    return 0.0;
  }

  const Attachment({
    required this.id,
    required this.equipment,
    this.equipmentName,
    this.equipmentCode,
    required this.name,
    required this.pricingModifier,
    required this.status,
    required this.metadata,
  });

  factory Attachment.fromJson(Map<String, dynamic> json) =>
      _$AttachmentFromJson(json);
  Map<String, dynamic> toJson() => _$AttachmentToJson(this);
}

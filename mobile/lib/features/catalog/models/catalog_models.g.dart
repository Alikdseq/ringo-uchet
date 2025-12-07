// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'catalog_models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Equipment _$EquipmentFromJson(Map<String, dynamic> json) => Equipment(
      id: (json['id'] as num).toInt(),
      code: json['code'] as String,
      name: json['name'] as String,
      description: json['description'] as String,
      hourlyRate: Equipment._stringToDouble(json['hourly_rate']),
      dailyRate: Equipment._stringToDoubleNullable(json['daily_rate']),
      fuelConsumption:
          Equipment._stringToDoubleNullable(json['fuel_consumption']),
      status: $enumDecode(_$EquipmentStatusEnumMap, json['status']),
      photos:
          (json['photos'] as List<dynamic>).map((e) => e as String).toList(),
      lastMaintenanceDate: json['last_maintenance_date'] == null
          ? null
          : DateTime.parse(json['last_maintenance_date'] as String),
      attributes: json['attributes'] as Map<String, dynamic>,
    );

Map<String, dynamic> _$EquipmentToJson(Equipment instance) => <String, dynamic>{
      'id': instance.id,
      'code': instance.code,
      'name': instance.name,
      'description': instance.description,
      'hourly_rate': instance.hourlyRate,
      'daily_rate': instance.dailyRate,
      'fuel_consumption': instance.fuelConsumption,
      'status': _$EquipmentStatusEnumMap[instance.status]!,
      'photos': instance.photos,
      'last_maintenance_date': instance.lastMaintenanceDate?.toIso8601String(),
      'attributes': instance.attributes,
    };

const _$EquipmentStatusEnumMap = {
  EquipmentStatus.available: 'available',
  EquipmentStatus.busy: 'busy',
  EquipmentStatus.maintenance: 'maintenance',
  EquipmentStatus.inactive: 'inactive',
};

ServiceCategory _$ServiceCategoryFromJson(Map<String, dynamic> json) =>
    ServiceCategory(
      id: (json['id'] as num).toInt(),
      name: json['name'] as String,
      description: json['description'] as String,
      sortOrder: (json['sort_order'] as num).toInt(),
    );

Map<String, dynamic> _$ServiceCategoryToJson(ServiceCategory instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'description': instance.description,
      'sort_order': instance.sortOrder,
    };

ServiceItem _$ServiceItemFromJson(Map<String, dynamic> json) => ServiceItem(
      id: (json['id'] as num).toInt(),
      category: ServiceItem._categoryToInt(json['category']),
      categoryName: json['category_name'] as String?,
      name: json['name'] as String,
      unit: json['unit'] as String,
      price: ServiceItem._stringToDouble(json['price']),
      defaultDuration:
          ServiceItem._stringToDoubleNullable(json['default_duration']),
      includedItems: json['included_items'] as List<dynamic>,
      isActive: json['is_active'] as bool,
    );

Map<String, dynamic> _$ServiceItemToJson(ServiceItem instance) =>
    <String, dynamic>{
      'id': instance.id,
      'category': instance.category,
      'category_name': instance.categoryName,
      'name': instance.name,
      'unit': instance.unit,
      'price': instance.price,
      'default_duration': instance.defaultDuration,
      'included_items': instance.includedItems,
      'is_active': instance.isActive,
    };

MaterialItem _$MaterialItemFromJson(Map<String, dynamic> json) => MaterialItem(
      id: (json['id'] as num).toInt(),
      name: json['name'] as String,
      category: json['category'] as String,
      unit: json['unit'] as String,
      price: MaterialItem._stringToDouble(json['price']),
      density: MaterialItem._stringToDoubleNullable(json['density']),
      supplier: json['supplier'] as String?,
      isActive: json['is_active'] as bool,
    );

Map<String, dynamic> _$MaterialItemToJson(MaterialItem instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'category': instance.category,
      'unit': instance.unit,
      'price': instance.price,
      'density': instance.density,
      'supplier': instance.supplier,
      'is_active': instance.isActive,
    };

Attachment _$AttachmentFromJson(Map<String, dynamic> json) => Attachment(
      id: (json['id'] as num).toInt(),
      equipment: (json['equipment'] as num).toInt(),
      equipmentName: json['equipment_name'] as String?,
      equipmentCode: json['equipment_code'] as String?,
      name: json['name'] as String,
      pricingModifier: Attachment._stringToDouble(json['pricing_modifier']),
      status: $enumDecode(_$EquipmentStatusEnumMap, json['status']),
      metadata: json['metadata'] as Map<String, dynamic>,
    );

Map<String, dynamic> _$AttachmentToJson(Attachment instance) =>
    <String, dynamic>{
      'id': instance.id,
      'equipment': instance.equipment,
      'equipment_name': instance.equipmentName,
      'equipment_code': instance.equipmentCode,
      'name': instance.name,
      'pricing_modifier': instance.pricingModifier,
      'status': _$EquipmentStatusEnumMap[instance.status]!,
      'metadata': instance.metadata,
    };

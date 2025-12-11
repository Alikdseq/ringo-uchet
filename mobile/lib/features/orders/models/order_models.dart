import 'package:json_annotation/json_annotation.dart';
import '../../../shared/models/user.dart' show UserInfo;

part 'order_models.g.dart';

/// Статусы заказа
enum OrderStatus {
  @JsonValue('DRAFT')
  draft,
  @JsonValue('CREATED')
  created,
  @JsonValue('APPROVED')
  approved,
  @JsonValue('IN_PROGRESS')
  inProgress,
  @JsonValue('COMPLETED')
  completed,
  @JsonValue('CANCELLED')
  cancelled,
}

/// Тип позиции заказа
enum OrderItemType {
  @JsonValue('equipment')
  equipment,
  @JsonValue('service')
  service,
  @JsonValue('material')
  material,
  @JsonValue('attachment')
  attachment,
}

/// Модель заказа
@JsonSerializable()
class Order {
  final String id;
  final String number;
  final ClientInfo? client;
  final int? clientId;
  final String address;
  @JsonKey(name: 'geo_lat')
  final double? geoLat;
  @JsonKey(name: 'geo_lng')
  final double? geoLng;
  @JsonKey(name: 'start_dt')
  final DateTime startDt;
  @JsonKey(name: 'end_dt')
  final DateTime? endDt;
  final String description;
  final OrderStatus status;
    final UserInfo? manager;
    final int? managerId;
    final UserInfo? operator;  // Для обратной совместимости
    final int? operatorId;  // Для обратной совместимости
    final List<UserInfo>? operators;  // Список операторов
    @JsonKey(name: 'operator_ids')
    final List<int>? operatorIds;
  @JsonKey(name: 'prepayment_amount')
  final double prepaymentAmount;
  @JsonKey(name: 'prepayment_status')
  final String prepaymentStatus;
  @JsonKey(name: 'total_amount')
  final double totalAmount;
  @JsonKey(name: 'price_snapshot')
  final Map<String, dynamic>? priceSnapshot;
  final List<dynamic> attachments;
  final Map<String, dynamic> meta;
  @JsonKey(name: 'created_by')
  final UserInfo? createdBy;
  @JsonKey(name: 'created_at')
  final DateTime createdAt;
  @JsonKey(name: 'updated_at')
  final DateTime updatedAt;
  final List<OrderItem>? items;
  @JsonKey(name: 'status_logs')
  final List<OrderStatusLog>? statusLogs;
  final List<PhotoEvidence>? photos;

  const Order({
    required this.id,
    required this.number,
    this.client,
    this.clientId,
    required this.address,
    this.geoLat,
    this.geoLng,
    required this.startDt,
    this.endDt,
    required this.description,
    required this.status,
    this.manager,
    this.managerId,
    this.operator,
    this.operatorId,
    this.operators,
    this.operatorIds,
    required this.prepaymentAmount,
    required this.prepaymentStatus,
    required this.totalAmount,
    this.priceSnapshot,
    required this.attachments,
    required this.meta,
    this.createdBy,
    required this.createdAt,
    required this.updatedAt,
    this.items,
    this.statusLogs,
    this.photos,
  });

  factory Order.fromJson(Map<String, dynamic> json) {
    // Создаем копию для безопасной обработки
    final processedJson = Map<String, dynamic>.from(json);
    
    // Обрабатываем client - может быть объектом или ID (int)
    if (json['client'] != null) {
      if (json['client'] is Map<String, dynamic>) {
        // Это объект, оставляем как есть
      } else if (json['client'] is num) {
        // Это ID, сохраняем в clientId и устанавливаем client в null
        final clientIdValue = (json['client'] as num).toInt();
        processedJson['client'] = null;
        // Сохраняем ID в clientId, если его еще нет
        if (processedJson['clientId'] == null) {
          processedJson['clientId'] = clientIdValue;
        }
      }
    }
    
    // Обрабатываем manager - может быть объектом или ID (int)
    if (json['manager'] != null) {
      if (json['manager'] is Map<String, dynamic>) {
        // Это объект, оставляем как есть
      } else if (json['manager'] is num) {
        // Это ID, сохраняем в managerId и устанавливаем manager в null
        final managerIdValue = (json['manager'] as num).toInt();
        processedJson['manager'] = null;
        if (processedJson['managerId'] == null) {
          processedJson['managerId'] = managerIdValue;
        }
      }
    }
    
    // Обрабатываем operator - может быть объектом, ID (int) или null
    if (json['operator'] == null) {
      // Если operator null, оставляем как есть
      processedJson['operator'] = null;
    } else if (json['operator'] is Map<String, dynamic>) {
      // Это объект, оставляем как есть
    } else if (json['operator'] is num) {
      // Это ID, сохраняем в operatorId и устанавливаем operator в null
      final operatorIdValue = (json['operator'] as num).toInt();
      processedJson['operator'] = null;
      if (processedJson['operatorId'] == null) {
        processedJson['operatorId'] = operatorIdValue;
      }
    }
    
    // Обрабатываем operators - список операторов
    if (json['operators'] != null && json['operators'] is List) {
      // Это список объектов операторов, оставляем как есть
      processedJson['operators'] = json['operators'];
    } else {
      processedJson['operators'] = null;
    }
    
    // Обрабатываем created_by - может быть объектом или ID (int)
    if (json['created_by'] != null) {
      if (json['created_by'] is Map<String, dynamic>) {
        // Это объект, оставляем как есть
      } else if (json['created_by'] is num) {
        // Это ID, устанавливаем в null (не можем создать UserInfo без полных данных)
        processedJson['created_by'] = null;
      }
    }
    
    // Обрабатываем строковые поля, которые могут быть null или неожиданного типа
    if (processedJson['prepayment_status'] == null || processedJson['prepayment_status'] is! String) {
      processedJson['prepayment_status'] = 'pending';
    }
    if (processedJson['address'] == null || processedJson['address'] is! String) {
      processedJson['address'] = processedJson['address']?.toString() ?? '';
    }
    if (processedJson['description'] == null || processedJson['description'] is! String) {
      processedJson['description'] = processedJson['description']?.toString() ?? '';
    }
    
    // Обрабатываем number и id - должны быть строками
    if (processedJson['id'] == null || processedJson['id'] is! String) {
      processedJson['id'] = processedJson['id']?.toString() ?? '';
    }
    if (processedJson['number'] == null || processedJson['number'] is! String) {
      processedJson['number'] = processedJson['number']?.toString() ?? '';
    }
    
    // Обрабатываем meta и attachments - должны быть не null
    if (processedJson['meta'] == null || processedJson['meta'] is! Map<String, dynamic>) {
      processedJson['meta'] = <String, dynamic>{};
    }
    if (processedJson['attachments'] == null || processedJson['attachments'] is! List) {
      processedJson['attachments'] = <dynamic>[];
    }
    if (processedJson['items'] == null || processedJson['items'] is! List) {
      processedJson['items'] = <dynamic>[];
    }
    
    // Обрабатываем Decimal поля - Django возвращает их как строки
    // prepayment_amount может быть строкой или числом
    if (processedJson.containsKey('prepayment_amount') && processedJson['prepayment_amount'] != null) {
      if (processedJson['prepayment_amount'] is String) {
        try {
          processedJson['prepayment_amount'] = double.parse(processedJson['prepayment_amount'] as String);
        } catch (e) {
          processedJson['prepayment_amount'] = 0.0;
        }
      } else if (processedJson['prepayment_amount'] is num) {
        processedJson['prepayment_amount'] = (processedJson['prepayment_amount'] as num).toDouble();
      }
    } else {
      processedJson['prepayment_amount'] = 0.0;
    }
    
    // total_amount может быть строкой или числом
    if (processedJson.containsKey('total_amount') && processedJson['total_amount'] != null) {
      if (processedJson['total_amount'] is String) {
        try {
          processedJson['total_amount'] = double.parse(processedJson['total_amount'] as String);
        } catch (e) {
          processedJson['total_amount'] = 0.0;
        }
      } else if (processedJson['total_amount'] is num) {
        processedJson['total_amount'] = (processedJson['total_amount'] as num).toDouble();
      }
    } else {
      processedJson['total_amount'] = 0.0;
    }
    
    // Обрабатываем items - каждый item может иметь строковые Decimal поля
    if (processedJson['items'] != null && processedJson['items'] is List) {
      final itemsList = (processedJson['items'] as List).map((item) {
        if (item is Map<String, dynamic>) {
          final processedItem = Map<String, dynamic>.from(item);
          
          // quantity может быть строкой или числом
          if (processedItem.containsKey('quantity') && processedItem['quantity'] != null) {
            if (processedItem['quantity'] is String) {
              try {
                processedItem['quantity'] = double.parse(processedItem['quantity'] as String);
              } catch (e) {
                processedItem['quantity'] = 1.0;
              }
            } else if (processedItem['quantity'] is num) {
              processedItem['quantity'] = (processedItem['quantity'] as num).toDouble();
            }
          } else {
            processedItem['quantity'] = 1.0;
          }
          
          // unit_price может быть строкой или числом
          if (processedItem.containsKey('unit_price') && processedItem['unit_price'] != null) {
            if (processedItem['unit_price'] is String) {
              try {
                processedItem['unit_price'] = double.parse(processedItem['unit_price'] as String);
              } catch (e) {
                processedItem['unit_price'] = 0.0;
              }
            } else if (processedItem['unit_price'] is num) {
              processedItem['unit_price'] = (processedItem['unit_price'] as num).toDouble();
            }
          } else {
            processedItem['unit_price'] = 0.0;
          }
          
          // tax_rate может быть строкой или числом
          if (processedItem.containsKey('tax_rate') && processedItem['tax_rate'] != null) {
            if (processedItem['tax_rate'] is String) {
              try {
                processedItem['tax_rate'] = double.parse(processedItem['tax_rate'] as String);
              } catch (e) {
                processedItem['tax_rate'] = 0.0;
              }
            } else if (processedItem['tax_rate'] is num) {
              processedItem['tax_rate'] = (processedItem['tax_rate'] as num).toDouble();
            }
          } else {
            processedItem['tax_rate'] = 0.0;
          }
          
          // discount может быть строкой или числом
          if (processedItem.containsKey('discount') && processedItem['discount'] != null) {
            if (processedItem['discount'] is String) {
              try {
                processedItem['discount'] = double.parse(processedItem['discount'] as String);
              } catch (e) {
                processedItem['discount'] = 0.0;
              }
            } else if (processedItem['discount'] is num) {
              processedItem['discount'] = (processedItem['discount'] as num).toDouble();
            }
          } else {
            processedItem['discount'] = 0.0;
          }
          
          // fuel_expense может быть строкой или числом (опциональное поле)
          if (processedItem.containsKey('fuel_expense') && processedItem['fuel_expense'] != null) {
            if (processedItem['fuel_expense'] is String) {
              try {
                processedItem['fuel_expense'] = double.parse(processedItem['fuel_expense'] as String);
              } catch (e) {
                processedItem['fuel_expense'] = null;
              }
            } else if (processedItem['fuel_expense'] is num) {
              processedItem['fuel_expense'] = (processedItem['fuel_expense'] as num).toDouble();
            }
          } else {
            processedItem['fuel_expense'] = null;
          }
          
          // repair_expense может быть строкой или числом (опциональное поле)
          if (processedItem.containsKey('repair_expense') && processedItem['repair_expense'] != null) {
            if (processedItem['repair_expense'] is String) {
              try {
                processedItem['repair_expense'] = double.parse(processedItem['repair_expense'] as String);
              } catch (e) {
                processedItem['repair_expense'] = null;
              }
            } else if (processedItem['repair_expense'] is num) {
              processedItem['repair_expense'] = (processedItem['repair_expense'] as num).toDouble();
            }
          } else {
            processedItem['repair_expense'] = null;
          }
          
          return processedItem;
        }
        return item;
      }).toList();
      processedJson['items'] = itemsList;
    }
    
    // Обрабатываем статус DELETED (больше не поддерживается, но могут быть старые записи)
    if (processedJson['status'] == 'DELETED') {
      // Заменяем DELETED на CANCELLED для обратной совместимости
      processedJson['status'] = 'CANCELLED';
    }
    
    // Используем стандартный парсинг с обработанными данными
    try {
      return _$OrderFromJson(processedJson);
    } catch (e, stackTrace) {
      // Логируем ошибку парсинга для отладки
      print('Error parsing Order from JSON: $e');
      print('Stack trace: $stackTrace');
      print('Processed JSON keys: ${processedJson.keys.toList()}');
      print('Processed JSON: $processedJson');
      // Если ошибка связана со статусом, пробуем заменить на CANCELLED
      if (e.toString().contains('DELETED') || e.toString().contains('status')) {
        processedJson['status'] = 'CANCELLED';
        try {
          return _$OrderFromJson(processedJson);
        } catch (_) {
          rethrow;
        }
      }
      rethrow;
    }
  }
  
  Map<String, dynamic> toJson() => _$OrderToJson(this);
}

/// Позиция заказа
@JsonSerializable()
class OrderItem {
  final int? id;
  @JsonKey(name: 'item_type')
  final OrderItemType itemType;
  @JsonKey(name: 'ref_id')
  final int? refId;
  @JsonKey(name: 'name_snapshot')
  final String nameSnapshot;
  final double quantity;
  final String unit;
  @JsonKey(name: 'unit_price')
  final double unitPrice;
  @JsonKey(name: 'tax_rate')
  final double taxRate;
  final double discount;
  @JsonKey(name: 'fuel_expense')
  final double? fuelExpense;
  @JsonKey(name: 'repair_expense')
  final double? repairExpense;
  final Map<String, dynamic> metadata;
  @JsonKey(name: 'display_quantity')
  final String? displayQuantity;
  @JsonKey(name: 'display_unit')
  final String? displayUnit;
  @JsonKey(name: 'line_total')
  final double? lineTotal;

  const OrderItem({
    this.id,
    required this.itemType,
    this.refId,
    required this.nameSnapshot,
    required this.quantity,
    required this.unit,
    required this.unitPrice,
    required this.taxRate,
    required this.discount,
    this.fuelExpense,
    this.repairExpense,
    required this.metadata,
    this.displayQuantity,
    this.displayUnit,
    this.lineTotal,
  });

  factory OrderItem.fromJson(Map<String, dynamic> json) => _$OrderItemFromJson(json);
  Map<String, dynamic> toJson({bool excludeId = true}) {
    final json = _$OrderItemToJson(this);
    // Исключаем id при создании нового элемента (read_only в сериализаторе)
    if (excludeId && id == null) {
      json.remove('id');
    }
    
    // Убеждаемся, что name_snapshot всегда присутствует (обязательное поле)
    if (json['name_snapshot'] == null || json['name_snapshot'] == '') {
      throw Exception('name_snapshot is required for OrderItem');
    }
    
    // Конвертируем DecimalField в строки для Django (quantity, unit_price, tax_rate, discount)
    // Django DecimalField принимает строки в формате "123.45"
    json['quantity'] = quantity.toStringAsFixed(2);
    json['unit_price'] = unitPrice.toStringAsFixed(2);
    json['tax_rate'] = taxRate.toStringAsFixed(2);
    json['discount'] = discount.toStringAsFixed(2);
    
    // Обрабатываем fuel_expense (опциональное поле)
    if (fuelExpense != null && fuelExpense! > 0) {
      json['fuel_expense'] = fuelExpense!.toStringAsFixed(2);
    } else {
      json.remove('fuel_expense'); // Удаляем null или 0 значения
    }
    
    // Обрабатываем repair_expense (опциональное поле)
    if (repairExpense != null && repairExpense! > 0) {
      json['repair_expense'] = repairExpense!.toStringAsFixed(2);
    } else {
      json.remove('repair_expense'); // Удаляем null или 0 значения
    }
    
    // Убеждаемся что metadata это объект, а не null
    if (json['metadata'] == null) {
      json['metadata'] = {};
    }
    
    // Убеждаемся, что unit не null (обязательное поле в модели)
    if (json['unit'] == null || json['unit'] == '') {
      json['unit'] = unit.isNotEmpty ? unit : 'шт';
    }
    
    // Удаляем ref_id если он null (опциональное поле в модели)
    if (json['ref_id'] == null) {
      json.remove('ref_id');
    }
    
    return json;
  }

  double get total => (unitPrice * quantity) * (1 - discount / 100);
}

/// Лог изменения статуса
@JsonSerializable()
class OrderStatusLog {
  final int id;
  @JsonKey(name: 'from_status')
  final String? fromStatus;
  @JsonKey(name: 'to_status')
  final String toStatus;
  final UserInfo? actor;
  @JsonKey(name: 'actor_name')
  final String? actorName;
  final String comment;
  @JsonKey(name: 'attachment_url')
  final String? attachmentUrl;
  @JsonKey(name: 'created_at')
  final DateTime createdAt;

  const OrderStatusLog({
    required this.id,
    this.fromStatus,
    required this.toStatus,
    this.actor,
    this.actorName,
    required this.comment,
    this.attachmentUrl,
    required this.createdAt,
  });

  factory OrderStatusLog.fromJson(Map<String, dynamic> json) => _$OrderStatusLogFromJson(json);
  Map<String, dynamic> toJson() => _$OrderStatusLogToJson(this);
}

/// Фото-доказательство
@JsonSerializable()
class PhotoEvidence {
  final int id;
  final String order;
  @JsonKey(name: 'uploaded_by')
  final UserInfo? uploadedBy;
  @JsonKey(name: 'photo_type')
  final String photoType;
  @JsonKey(name: 'file_url')
  final String fileUrl;
  @JsonKey(name: 'gps_lat')
  final double? gpsLat;
  @JsonKey(name: 'gps_lng')
  final double? gpsLng;
  @JsonKey(name: 'captured_at')
  final DateTime? capturedAt;
  final String notes;
  final Map<String, dynamic> metadata;
  @JsonKey(name: 'created_at')
  final DateTime createdAt;
  @JsonKey(name: 'updated_at')
  final DateTime updatedAt;

  const PhotoEvidence({
    required this.id,
    required this.order,
    this.uploadedBy,
    required this.photoType,
    required this.fileUrl,
    this.gpsLat,
    this.gpsLng,
    this.capturedAt,
    required this.notes,
    required this.metadata,
    required this.createdAt,
    required this.updatedAt,
  });

  factory PhotoEvidence.fromJson(Map<String, dynamic> json) => _$PhotoEvidenceFromJson(json);
  Map<String, dynamic> toJson() => _$PhotoEvidenceToJson(this);
}

/// Информация о клиенте
@JsonSerializable()
class ClientInfo {
  final int id;
  final String name;
  @JsonKey(name: 'contact_person')
  final String? contactPerson;
  final String phone;
  final String? email;
  final String? address;
  final String? city;
  @JsonKey(name: 'geo_lat')
  final double? geoLat;
  @JsonKey(name: 'geo_lng')
  final double? geoLng;

  const ClientInfo({
    required this.id,
    required this.name,
    this.contactPerson,
    required this.phone,
    this.email,
    this.address,
    this.city,
    this.geoLat,
    this.geoLng,
  });

  factory ClientInfo.fromJson(Map<String, dynamic> json) => _$ClientInfoFromJson(json);
  Map<String, dynamic> toJson() => _$ClientInfoToJson(this);
}

/// Запрос на создание/обновление заказа
@JsonSerializable()
class OrderRequest {
  final String? number;
  @JsonKey(name: 'client_id')
  final int? clientId;
  final String address;
  @JsonKey(name: 'geo_lat')
  final double? geoLat;
  @JsonKey(name: 'geo_lng')
  final double? geoLng;
  @JsonKey(name: 'start_dt')
  final DateTime startDt;
  @JsonKey(name: 'end_dt')
  final DateTime? endDt;
  final String description;
  final OrderStatus? status;
    @JsonKey(name: 'manager_id')
    final int? managerId;
    @JsonKey(name: 'operator_id')
    final int? operatorId;  // Для обратной совместимости
    @JsonKey(name: 'operator_ids')
    final List<int>? operatorIds;  // Список ID операторов
    @JsonKey(name: 'prepayment_amount')
    final double? prepaymentAmount;
    @JsonKey(name: 'total_amount')
    final double? totalAmount;
    final List<OrderItem>? items;

    const OrderRequest({
    this.number,
    this.clientId,
    required this.address,
    this.geoLat,
    this.geoLng,
    required this.startDt,
    this.endDt,
    required this.description,
    this.status,
    this.managerId,
    this.operatorId,
    this.operatorIds,
    this.prepaymentAmount,
    this.totalAmount,
    this.items,
  });

  factory OrderRequest.fromJson(Map<String, dynamic> json) => _$OrderRequestFromJson(json);
  Map<String, dynamic> toJson() {
    final json = _$OrderRequestToJson(this);
    
    // Форматируем даты в правильный ISO8601 формат для Django
    // Django REST Framework ожидает ISO8601 формат: YYYY-MM-DDThh:mm:ss[.uuuuuu][+HH:MM|-HH:MM|Z]
    // Конвертируем в UTC и форматируем без миллисекунд, но с Z в конце
    final startDtUtc = startDt.toUtc();
    // Форматируем как: 2025-12-01T09:00:00Z (без миллисекунд)
    String startDtStr = startDtUtc.toIso8601String();
    // Убираем миллисекунды (.000 или .000000) перед Z
    startDtStr = startDtStr.replaceAll(RegExp(r'\.\d+Z$'), 'Z');
    json['start_dt'] = startDtStr;
    
    if (endDt != null) {
      final endDtUtc = endDt!.toUtc();
      String endDtStr = endDtUtc.toIso8601String();
      endDtStr = endDtStr.replaceAll(RegExp(r'\.\d+Z$'), 'Z');
      json['end_dt'] = endDtStr;
    } else {
      json.remove('end_dt'); // Удаляем null значения
    }
    
    // Обрабатываем number - отправляем пустую строку если null
    // Django сериализатор сгенерирует номер автоматически в методе create()
    if (json['number'] == null || json['number'] == '') {
      json['number'] = ''; // Отправляем пустую строку, сериализатор сгенерирует номер
    }
    
    // Явно конвертируем items в JSON (excludeId=true для создания новых элементов)
    // ВАЖНО: отправляем items только если они явно указаны (не null)
    // Если items = null, не отправляем поле вообще - это означает "не изменять существующие items"
    // Если items = [], отправляем пустой список - это означает "удалить все items"
    if (items != null) {
      if (items!.isNotEmpty) {
        json['items'] = items!.map((item) => item.toJson(excludeId: true)).toList();
      } else {
        // Пустой список означает удаление всех items
        json['items'] = [];
      }
    }
    // Если items == null, не добавляем поле в JSON - это означает "не трогать существующие items"
    
    // Удаляем null значения для опциональных полей
    if (json['geo_lat'] == null) {
      json.remove('geo_lat');
    } else {
      // DecimalField в Django принимает строки или числа
      json['geo_lat'] = geoLat!.toStringAsFixed(6);
    }
    if (json['geo_lng'] == null) {
      json.remove('geo_lng');
    } else {
      json['geo_lng'] = geoLng!.toStringAsFixed(6);
    }
    if (json['prepayment_amount'] == null) {
      json.remove('prepayment_amount');
    } else {
      json['prepayment_amount'] = prepaymentAmount!.toStringAsFixed(2);
    }
    if (json['manager_id'] == null) json.remove('manager_id');
    if (json['operator_id'] == null) json.remove('operator_id');
    // Отправляем operator_ids если указаны
    if (operatorIds != null && operatorIds!.isNotEmpty) {
      json['operator_ids'] = operatorIds;
    } else {
      json.remove('operator_ids');
    }
    
    // Убеждаемся, что description не null (может быть пустой строкой)
    if (json['description'] == null) {
      json['description'] = '';
    }
    
    // Обрабатываем total_amount - отправляем как строку с фиксированной точностью для DecimalField
    if (totalAmount != null) {
      json['total_amount'] = totalAmount!.toStringAsFixed(2);
    } else {
      json.remove('total_amount');
    }
    
    return json;
  }
}

/// Запрос на изменение статуса
@JsonSerializable()
class OrderStatusRequest {
  final OrderStatus status;
  final String? comment;
  @JsonKey(name: 'attachment_url')
  final String? attachmentUrl;
  @JsonKey(name: 'operator_salary')
  final double? operatorSalary;
  @JsonKey(name: 'fuel_expense')
  final double? fuelExpense;

  const OrderStatusRequest({
    required this.status,
    this.comment,
    this.attachmentUrl,
    this.operatorSalary,
    this.fuelExpense,
  });

  factory OrderStatusRequest.fromJson(Map<String, dynamic> json) => _$OrderStatusRequestFromJson(json);
  Map<String, dynamic> toJson() {
    final json = _$OrderStatusRequestToJson(this);
    // Удаляем null и пустые значения для опциональных полей
    if (json['comment'] == null || (json['comment'] as String).trim().isEmpty) {
      json.remove('comment');
    } else {
      // Убеждаемся, что comment это строка
      json['comment'] = (json['comment'] as String).trim();
    }
    if (json['attachment_url'] == null || json['attachment_url'] == '' || json['attachment_url'] == 'null') {
      json.remove('attachment_url');
    }
    // Обрабатываем финансовые поля
    if (operatorSalary != null && operatorSalary! > 0) {
      json['operator_salary'] = operatorSalary!.toStringAsFixed(2);
    } else {
      json.remove('operator_salary');
    }
    if (fuelExpense != null && fuelExpense! > 0) {
      json['fuel_expense'] = fuelExpense!.toStringAsFixed(2);
    } else {
      json.remove('fuel_expense');
    }
    return json;
  }
}

/// Запрос на предпросмотр расчёта
@JsonSerializable()
class OrderPricePreviewRequest {
  final List<OrderItem> items;

  const OrderPricePreviewRequest({
    required this.items,
  });

  factory OrderPricePreviewRequest.fromJson(Map<String, dynamic> json) => _$OrderPricePreviewRequestFromJson(json);
  Map<String, dynamic> toJson() => _$OrderPricePreviewRequestToJson(this);
}

/// Ответ на предпросмотр расчёта
@JsonSerializable()
class OrderPricePreviewResponse {
  final List<Map<String, dynamic>> items;
  final double total;
  final Map<String, dynamic>? details;

  const OrderPricePreviewResponse({
    required this.items,
    required this.total,
    this.details,
  });

  factory OrderPricePreviewResponse.fromJson(Map<String, dynamic> json) => _$OrderPricePreviewResponseFromJson(json);
  Map<String, dynamic> toJson() => _$OrderPricePreviewResponseToJson(this);
}


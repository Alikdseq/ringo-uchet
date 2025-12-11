// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'order_models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Order _$OrderFromJson(Map<String, dynamic> json) => Order(
      id: json['id'] as String,
      number: json['number'] as String,
      client: json['client'] == null
          ? null
          : ClientInfo.fromJson(json['client'] as Map<String, dynamic>),
      clientId: (json['clientId'] as num?)?.toInt(),
      address: json['address'] as String,
      geoLat: (json['geo_lat'] as num?)?.toDouble(),
      geoLng: (json['geo_lng'] as num?)?.toDouble(),
      startDt: DateTime.parse(json['start_dt'] as String),
      endDt: json['end_dt'] == null
          ? null
          : DateTime.parse(json['end_dt'] as String),
      description: json['description'] as String,
      status: $enumDecode(_$OrderStatusEnumMap, json['status']),
      manager: json['manager'] == null
          ? null
          : UserInfo.fromJson(json['manager'] as Map<String, dynamic>),
      managerId: (json['managerId'] as num?)?.toInt(),
      operator: json['operator'] == null
          ? null
          : UserInfo.fromJson(json['operator'] as Map<String, dynamic>),
      operatorId: (json['operatorId'] as num?)?.toInt(),
      operators: (json['operators'] as List<dynamic>?)
          ?.map((e) => UserInfo.fromJson(e as Map<String, dynamic>))
          .toList(),
      operatorIds: (json['operator_ids'] as List<dynamic>?)
          ?.map((e) => (e as num).toInt())
          .toList(),
      prepaymentAmount: (json['prepayment_amount'] as num).toDouble(),
      prepaymentStatus: json['prepayment_status'] as String,
      totalAmount: (json['total_amount'] as num).toDouble(),
      priceSnapshot: json['price_snapshot'] as Map<String, dynamic>?,
      attachments: json['attachments'] as List<dynamic>,
      meta: json['meta'] as Map<String, dynamic>,
      createdBy: json['created_by'] == null
          ? null
          : UserInfo.fromJson(json['created_by'] as Map<String, dynamic>),
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      items: (json['items'] as List<dynamic>?)
          ?.map((e) => OrderItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      statusLogs: (json['status_logs'] as List<dynamic>?)
          ?.map((e) => OrderStatusLog.fromJson(e as Map<String, dynamic>))
          .toList(),
      photos: (json['photos'] as List<dynamic>?)
          ?.map((e) => PhotoEvidence.fromJson(e as Map<String, dynamic>))
          .toList(),
    );

Map<String, dynamic> _$OrderToJson(Order instance) => <String, dynamic>{
      'id': instance.id,
      'number': instance.number,
      'client': instance.client,
      'clientId': instance.clientId,
      'address': instance.address,
      'geo_lat': instance.geoLat,
      'geo_lng': instance.geoLng,
      'start_dt': instance.startDt.toIso8601String(),
      'end_dt': instance.endDt?.toIso8601String(),
      'description': instance.description,
      'status': _$OrderStatusEnumMap[instance.status]!,
      'manager': instance.manager,
      'managerId': instance.managerId,
      'operator': instance.operator,
      'operatorId': instance.operatorId,
      'operators': instance.operators,
      'operator_ids': instance.operatorIds,
      'prepayment_amount': instance.prepaymentAmount,
      'prepayment_status': instance.prepaymentStatus,
      'total_amount': instance.totalAmount,
      'price_snapshot': instance.priceSnapshot,
      'attachments': instance.attachments,
      'meta': instance.meta,
      'created_by': instance.createdBy,
      'created_at': instance.createdAt.toIso8601String(),
      'updated_at': instance.updatedAt.toIso8601String(),
      'items': instance.items,
      'status_logs': instance.statusLogs,
      'photos': instance.photos,
    };

const _$OrderStatusEnumMap = {
  OrderStatus.draft: 'DRAFT',
  OrderStatus.created: 'CREATED',
  OrderStatus.approved: 'APPROVED',
  OrderStatus.inProgress: 'IN_PROGRESS',
  OrderStatus.completed: 'COMPLETED',
  OrderStatus.cancelled: 'CANCELLED',
  OrderStatus.deleted: 'DELETED',
};

OrderItem _$OrderItemFromJson(Map<String, dynamic> json) => OrderItem(
      id: (json['id'] as num?)?.toInt(),
      itemType: $enumDecode(_$OrderItemTypeEnumMap, json['item_type']),
      refId: (json['ref_id'] as num?)?.toInt(),
      nameSnapshot: json['name_snapshot'] as String,
      quantity: (json['quantity'] as num).toDouble(),
      unit: json['unit'] as String,
      unitPrice: (json['unit_price'] as num).toDouble(),
      taxRate: (json['tax_rate'] as num).toDouble(),
      discount: (json['discount'] as num).toDouble(),
      fuelExpense: (json['fuel_expense'] as num?)?.toDouble(),
      repairExpense: (json['repair_expense'] as num?)?.toDouble(),
      metadata: json['metadata'] as Map<String, dynamic>,
      displayQuantity: json['display_quantity'] as String?,
      displayUnit: json['display_unit'] as String?,
      lineTotal: (json['line_total'] as num?)?.toDouble(),
    );

Map<String, dynamic> _$OrderItemToJson(OrderItem instance) => <String, dynamic>{
      'id': instance.id,
      'item_type': _$OrderItemTypeEnumMap[instance.itemType]!,
      'ref_id': instance.refId,
      'name_snapshot': instance.nameSnapshot,
      'quantity': instance.quantity,
      'unit': instance.unit,
      'unit_price': instance.unitPrice,
      'tax_rate': instance.taxRate,
      'discount': instance.discount,
      'fuel_expense': instance.fuelExpense,
      'repair_expense': instance.repairExpense,
      'metadata': instance.metadata,
      'display_quantity': instance.displayQuantity,
      'display_unit': instance.displayUnit,
      'line_total': instance.lineTotal,
    };

const _$OrderItemTypeEnumMap = {
  OrderItemType.equipment: 'equipment',
  OrderItemType.service: 'service',
  OrderItemType.material: 'material',
  OrderItemType.attachment: 'attachment',
};

OrderStatusLog _$OrderStatusLogFromJson(Map<String, dynamic> json) =>
    OrderStatusLog(
      id: (json['id'] as num).toInt(),
      fromStatus: json['from_status'] as String?,
      toStatus: json['to_status'] as String,
      actor: json['actor'] == null
          ? null
          : UserInfo.fromJson(json['actor'] as Map<String, dynamic>),
      actorName: json['actor_name'] as String?,
      comment: json['comment'] as String,
      attachmentUrl: json['attachment_url'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );

Map<String, dynamic> _$OrderStatusLogToJson(OrderStatusLog instance) =>
    <String, dynamic>{
      'id': instance.id,
      'from_status': instance.fromStatus,
      'to_status': instance.toStatus,
      'actor': instance.actor,
      'actor_name': instance.actorName,
      'comment': instance.comment,
      'attachment_url': instance.attachmentUrl,
      'created_at': instance.createdAt.toIso8601String(),
    };

PhotoEvidence _$PhotoEvidenceFromJson(Map<String, dynamic> json) =>
    PhotoEvidence(
      id: (json['id'] as num).toInt(),
      order: json['order'] as String,
      uploadedBy: json['uploaded_by'] == null
          ? null
          : UserInfo.fromJson(json['uploaded_by'] as Map<String, dynamic>),
      photoType: json['photo_type'] as String,
      fileUrl: json['file_url'] as String,
      gpsLat: (json['gps_lat'] as num?)?.toDouble(),
      gpsLng: (json['gps_lng'] as num?)?.toDouble(),
      capturedAt: json['captured_at'] == null
          ? null
          : DateTime.parse(json['captured_at'] as String),
      notes: json['notes'] as String,
      metadata: json['metadata'] as Map<String, dynamic>,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );

Map<String, dynamic> _$PhotoEvidenceToJson(PhotoEvidence instance) =>
    <String, dynamic>{
      'id': instance.id,
      'order': instance.order,
      'uploaded_by': instance.uploadedBy,
      'photo_type': instance.photoType,
      'file_url': instance.fileUrl,
      'gps_lat': instance.gpsLat,
      'gps_lng': instance.gpsLng,
      'captured_at': instance.capturedAt?.toIso8601String(),
      'notes': instance.notes,
      'metadata': instance.metadata,
      'created_at': instance.createdAt.toIso8601String(),
      'updated_at': instance.updatedAt.toIso8601String(),
    };

ClientInfo _$ClientInfoFromJson(Map<String, dynamic> json) => ClientInfo(
      id: (json['id'] as num).toInt(),
      name: json['name'] as String,
      contactPerson: json['contact_person'] as String?,
      phone: json['phone'] as String,
      email: json['email'] as String?,
      address: json['address'] as String?,
      city: json['city'] as String?,
      geoLat: (json['geo_lat'] as num?)?.toDouble(),
      geoLng: (json['geo_lng'] as num?)?.toDouble(),
    );

Map<String, dynamic> _$ClientInfoToJson(ClientInfo instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'contact_person': instance.contactPerson,
      'phone': instance.phone,
      'email': instance.email,
      'address': instance.address,
      'city': instance.city,
      'geo_lat': instance.geoLat,
      'geo_lng': instance.geoLng,
    };

OrderRequest _$OrderRequestFromJson(Map<String, dynamic> json) => OrderRequest(
      number: json['number'] as String?,
      clientId: (json['client_id'] as num?)?.toInt(),
      address: json['address'] as String,
      geoLat: (json['geo_lat'] as num?)?.toDouble(),
      geoLng: (json['geo_lng'] as num?)?.toDouble(),
      startDt: DateTime.parse(json['start_dt'] as String),
      endDt: json['end_dt'] == null
          ? null
          : DateTime.parse(json['end_dt'] as String),
      description: json['description'] as String,
      status: $enumDecodeNullable(_$OrderStatusEnumMap, json['status']),
      managerId: (json['manager_id'] as num?)?.toInt(),
      operatorId: (json['operator_id'] as num?)?.toInt(),
      operatorIds: (json['operator_ids'] as List<dynamic>?)
          ?.map((e) => (e as num).toInt())
          .toList(),
      prepaymentAmount: (json['prepayment_amount'] as num?)?.toDouble(),
      totalAmount: (json['total_amount'] as num?)?.toDouble(),
      items: (json['items'] as List<dynamic>?)
          ?.map((e) => OrderItem.fromJson(e as Map<String, dynamic>))
          .toList(),
    );

Map<String, dynamic> _$OrderRequestToJson(OrderRequest instance) =>
    <String, dynamic>{
      'number': instance.number,
      'client_id': instance.clientId,
      'address': instance.address,
      'geo_lat': instance.geoLat,
      'geo_lng': instance.geoLng,
      'start_dt': instance.startDt.toIso8601String(),
      'end_dt': instance.endDt?.toIso8601String(),
      'description': instance.description,
      'status': _$OrderStatusEnumMap[instance.status],
      'manager_id': instance.managerId,
      'operator_id': instance.operatorId,
      'operator_ids': instance.operatorIds,
      'prepayment_amount': instance.prepaymentAmount,
      'total_amount': instance.totalAmount,
      'items': instance.items,
    };

OrderStatusRequest _$OrderStatusRequestFromJson(Map<String, dynamic> json) =>
    OrderStatusRequest(
      status: $enumDecode(_$OrderStatusEnumMap, json['status']),
      comment: json['comment'] as String?,
      attachmentUrl: json['attachment_url'] as String?,
      operatorSalary: (json['operator_salary'] as num?)?.toDouble(),
      fuelExpense: (json['fuel_expense'] as num?)?.toDouble(),
    );

Map<String, dynamic> _$OrderStatusRequestToJson(OrderStatusRequest instance) =>
    <String, dynamic>{
      'status': _$OrderStatusEnumMap[instance.status]!,
      'comment': instance.comment,
      'attachment_url': instance.attachmentUrl,
      'operator_salary': instance.operatorSalary,
      'fuel_expense': instance.fuelExpense,
    };

OrderPricePreviewRequest _$OrderPricePreviewRequestFromJson(
        Map<String, dynamic> json) =>
    OrderPricePreviewRequest(
      items: (json['items'] as List<dynamic>)
          .map((e) => OrderItem.fromJson(e as Map<String, dynamic>))
          .toList(),
    );

Map<String, dynamic> _$OrderPricePreviewRequestToJson(
        OrderPricePreviewRequest instance) =>
    <String, dynamic>{
      'items': instance.items,
    };

OrderPricePreviewResponse _$OrderPricePreviewResponseFromJson(
        Map<String, dynamic> json) =>
    OrderPricePreviewResponse(
      items: (json['items'] as List<dynamic>)
          .map((e) => e as Map<String, dynamic>)
          .toList(),
      total: (json['total'] as num).toDouble(),
      details: json['details'] as Map<String, dynamic>?,
    );

Map<String, dynamic> _$OrderPricePreviewResponseToJson(
        OrderPricePreviewResponse instance) =>
    <String, dynamic>{
      'items': instance.items,
      'total': instance.total,
      'details': instance.details,
    };

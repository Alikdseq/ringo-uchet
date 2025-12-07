import 'package:flutter/material.dart';

/// Цвета статусов заказов
class StatusColors {
  // Статусы заказов
  static const Color draft = Color(0xFF9E9E9E); // Серый
  static const Color created = Color(0xFF2196F3); // Синий
  static const Color approved = Color(0xFFFF9800); // Оранжевый
  static const Color inProgress = Color(0xFF00BCD4); // Бирюзовый
  static const Color completed = Color(0xFF4CAF50); // Зелёный
  static const Color cancelled = Color(0xFFF44336); // Красный

  // Статусы оплаты
  static const Color paymentPending = Color(0xFFFF9800);
  static const Color paymentSuccess = Color(0xFF4CAF50);
  static const Color paymentFailed = Color(0xFFF44336);
  static const Color paymentRefunded = Color(0xFF9E9E9E);

  // Статусы техники
  static const Color equipmentAvailable = Color(0xFF4CAF50);
  static const Color equipmentBusy = Color(0xFFFF9800);
  static const Color equipmentMaintenance = Color(0xFF2196F3);
  static const Color equipmentInactive = Color(0xFF9E9E9E);

  /// Получить цвет по статусу заказа
  static Color getOrderStatusColor(String status) {
    switch (status.toUpperCase()) {
      case 'DRAFT':
        return draft;
      case 'CREATED':
        return created;
      case 'APPROVED':
        return approved;
      case 'IN_PROGRESS':
        return inProgress;
      case 'COMPLETED':
        return completed;
      case 'CANCELLED':
        return cancelled;
      default:
        return draft;
    }
  }

  /// Получить цвет по статусу оплаты
  static Color getPaymentStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return paymentPending;
      case 'success':
        return paymentSuccess;
      case 'failed':
        return paymentFailed;
      case 'refunded':
        return paymentRefunded;
      default:
        return paymentPending;
    }
  }

  /// Получить цвет по статусу техники
  static Color getEquipmentStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'available':
        return equipmentAvailable;
      case 'busy':
        return equipmentBusy;
      case 'maintenance':
        return equipmentMaintenance;
      case 'inactive':
        return equipmentInactive;
      default:
        return equipmentInactive;
    }
  }
}


/// Модель настроек уведомлений
class NotificationPreferences {
  final bool orderCreated;
  final bool statusChanged;
  final bool paymentReceived;
  final bool invoiceReady;
  final bool kassaFull;

  const NotificationPreferences({
    this.orderCreated = true,
    this.statusChanged = true,
    this.paymentReceived = true,
    this.invoiceReady = true,
    this.kassaFull = true,
  });

  factory NotificationPreferences.fromJson(Map<String, dynamic> json) {
    return NotificationPreferences(
      orderCreated: json['order_created'] as bool? ?? true,
      statusChanged: json['status_changed'] as bool? ?? true,
      paymentReceived: json['payment_received'] as bool? ?? true,
      invoiceReady: json['invoice_ready'] as bool? ?? true,
      kassaFull: json['kassa_full'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'order_created': orderCreated,
      'status_changed': statusChanged,
      'payment_received': paymentReceived,
      'invoice_ready': invoiceReady,
      'kassa_full': kassaFull,
    };
  }

  NotificationPreferences copyWith({
    bool? orderCreated,
    bool? statusChanged,
    bool? paymentReceived,
    bool? invoiceReady,
    bool? kassaFull,
  }) {
    return NotificationPreferences(
      orderCreated: orderCreated ?? this.orderCreated,
      statusChanged: statusChanged ?? this.statusChanged,
      paymentReceived: paymentReceived ?? this.paymentReceived,
      invoiceReady: invoiceReady ?? this.invoiceReady,
      kassaFull: kassaFull ?? this.kassaFull,
    );
  }
}


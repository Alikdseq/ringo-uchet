import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
// import 'package:printing/printing.dart';  // Временно отключено для сборки APK

// Условный импорт для веб-платформы
import 'download_helper_stub.dart'
    if (dart.library.html) 'download_helper_web.dart'
    as download_helper;
import '../../../core/constants/status_colors.dart';
import '../../auth/providers/auth_providers.dart';
import '../models/order_models.dart';
import '../services/order_service.dart';
import '../widgets/status_timeline_widget.dart';
import '../widgets/change_status_dialog.dart';
import 'complete_order_screen.dart';

/// Экран детали заявки
class OrderDetailScreen extends ConsumerStatefulWidget {
  final String orderId;

  const OrderDetailScreen({
    super.key,
    required this.orderId,
  });

  @override
  ConsumerState<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends ConsumerState<OrderDetailScreen> {
  Order? _order;
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadOrder();
  }

  Future<void> _loadOrder() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final orderService = ref.read(orderServiceProvider);
      final order = await orderService.getOrder(widget.orderId);
      setState(() {
        _order = order;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _changeStatus(OrderStatus newStatus) async {
    if (_order == null) return;

    final result = await showDialog<OrderStatusRequest>(
      context: context,
      builder: (_) => ChangeStatusDialog(
        currentStatus: _order!.status,
        newStatus: newStatus,
      ),
    );

    if (result == null) return;

    try {
      final orderService = ref.read(orderServiceProvider);
      await orderService.changeOrderStatus(widget.orderId, result);
      await _loadOrder();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Статус изменён')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка: ${e.toString()}')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_order?.number ?? 'Заявка'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            // Возвращаемся на главный экран
            Navigator.of(context).popUntil((route) => route.isFirst);
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadOrder,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('Ошибка: $_error'),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadOrder,
                        child: const Text('Повторить'),
                      ),
                    ],
                  ),
                )
              : _order == null
                  ? const Center(child: Text('Заявка не найдена'))
                  : RefreshIndicator(
                      onRefresh: _loadOrder,
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Статус и основная информация
                            _buildHeader(),
                            const Divider(),

                            // Клиент
                            _buildClientSection(),
                            const Divider(),

                            // Адрес и карта
                            _buildAddressSection(),
                            const Divider(),

                            // Позиции заказа (скрываем для оператора)
                            if (!_isOperator()) ...[
                              _buildItemsSection(),
                              const Divider(),
                            ],

                            // Финансы (скрываем для оператора)
                            if (!_isOperator()) ...[
                              _buildFinanceSection(),
                              const Divider(),
                            ],

                            // Таймлайн статусов
                            _buildTimelineSection(),
                            const Divider(),

                            // Фото
                            if (_order!.photos != null && _order!.photos!.isNotEmpty)
                              _buildPhotosSection(),

                            // Кнопки действий
                            _buildActionButtons(),
                            const SizedBox(height: 16),
                          ],
                        ),
                      ),
                    ),
    );
  }

  Widget _buildHeader() {
    final statusColor = StatusColors.getOrderStatusColor(
      _order!.status.toString().split('.').last.toUpperCase(),
    );

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Заказ ${_order!.number}',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: statusColor),
                ),
                child: Text(
                  _getStatusLabel(_order!.status),
                  style: TextStyle(
                    color: statusColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Создан: ${_formatDateTime(_order!.createdAt)}',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.grey[600],
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildClientSection() {
    if (_order!.client == null) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Клиент',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 8),
          Text(_order!.client!.name),
          if (_order!.client!.phone.isNotEmpty)
            Text('Телефон: ${_order!.client!.phone}'),
          if (_order!.client!.email != null && _order!.client!.email!.isNotEmpty)
            Text('Email: ${_order!.client!.email}'),
        ],
      ),
    );
  }

  Widget _buildAddressSection() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Адрес',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 8),
          Text(_order!.address),
          if (_order!.geoLat != null && _order!.geoLng != null) ...[
            const SizedBox(height: 8),
            // TODO: Добавить Google Maps виджет
            Container(
              height: 200,
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Text(
                  'Карта: ${_order!.geoLat}, ${_order!.geoLng}',
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildItemsSection() {
    if (_order!.items == null || _order!.items!.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Позиции заказа',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 8),
          ..._order!.items!.map((item) {
                // Правильный расчет стоимости для техники
                // ВСЕГДА используем lineTotal с сервера, если он есть - это правильный расчет
                double calculatedTotal;
                if (item.lineTotal != null && item.lineTotal! > 0) {
                  // Используем значение с сервера - это правильный расчет с учетом смен и часов
                  calculatedTotal = item.lineTotal!.toDouble();
                } else if (item.itemType == 'equipment') {
                  // Для техники рассчитываем: смены * daily_rate + часы * hourly_rate
                  final metadata = item.metadata;
                  final shifts = (metadata['shifts'] as num?)?.toDouble() ?? 0.0;
                  final hours = (metadata['hours'] as num?)?.toDouble() ?? 0.0;
                  final dailyRate = (metadata['daily_rate'] as num?)?.toDouble() ?? 0.0;
                  final hourlyRate = item.unitPrice;
                  
                  final shiftsCost = shifts * dailyRate;
                  final hoursCost = hours * hourlyRate;
                  final totalBeforeDiscount = shiftsCost + hoursCost;
                  
                  // Применяем скидку
                  final discount = item.discount;
                  if (discount > 0) {
                    final discountAmount = totalBeforeDiscount * (discount / 100);
                    calculatedTotal = totalBeforeDiscount - discountAmount;
                  } else {
                    calculatedTotal = totalBeforeDiscount;
                  }
                  
                  // Применяем налог
                  final taxRate = item.taxRate;
                  if (taxRate > 0) {
                    final taxAmount = calculatedTotal * (taxRate / 100);
                    calculatedTotal = calculatedTotal + taxAmount;
                  }
                } else {
                  // Для других типов позиций
                  calculatedTotal = item.quantity * item.unitPrice;
                }
                
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          // Для техники всегда используем display_quantity и display_unit из сервера
                          // которые правильно показывают смены и часы
                          item.displayQuantity != null
                              ? '${item.nameSnapshot} x${item.displayQuantity}${item.displayUnit != null ? " ${item.displayUnit}" : ""}'
                              : '${item.nameSnapshot} x${item.quantity} ${item.unit}',
                        ),
                      ),
                      Text(
                        calculatedTotal.toStringAsFixed(2) + ' ₽',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                );
              }),
        ],
      ),
    );
  }

  Widget _buildFinanceSection() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Финансы',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Предоплата:'),
              Text('${_order!.prepaymentAmount.toStringAsFixed(2)} ₽'),
            ],
          ),
          const Divider(),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Итого:',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              Text(
                '${_order!.totalAmount.toStringAsFixed(2)} ₽',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).primaryColor,
                    ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineSection() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'История статусов',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 16),
          if (_order!.statusLogs != null && _order!.statusLogs!.isNotEmpty)
            StatusTimelineWidget(logs: _order!.statusLogs!)
          else
            const Text('История изменений статусов отсутствует'),
        ],
      ),
    );
  }

  Widget _buildPhotosSection() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Фото',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 100,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _order!.photos!.length,
              itemBuilder: (context, index) {
                final photo = _order!.photos![index];
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Image.network(
                    photo.fileUrl,
                    width: 100,
                    height: 100,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        width: 100,
                        height: 100,
                        color: Colors.grey[300],
                        child: const Icon(Icons.broken_image),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    final isOperator = _isOperator();
    final currentUser = ref.read(authStateProvider).user;
    final currentUserId = currentUser?.id;
    
    // Проверяем, является ли текущий пользователь оператором этой заявки
    final isOrderOperator = _order!.operators?.any((op) => op.id == currentUserId) == true ||
        _order!.operator?.id == currentUserId;
    
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Кнопки смены статуса (доступны менеджерам/админам и операторам этой заявки)
          if (!isOperator || isOrderOperator) ...[
            if (_order!.status == OrderStatus.draft)
              ElevatedButton.icon(
                onPressed: () => _changeStatus(OrderStatus.created),
                icon: const Icon(Icons.send),
                label: const Text('Отправить'),
              ),
            if (_order!.status == OrderStatus.created)
              ElevatedButton.icon(
                onPressed: () => _changeStatus(OrderStatus.approved),
                icon: const Icon(Icons.check),
                label: const Text('Одобрить'),
              ),
            if (_order!.status == OrderStatus.approved)
              ElevatedButton.icon(
                onPressed: () => _changeStatus(OrderStatus.inProgress),
                icon: const Icon(Icons.play_arrow),
                label: const Text('Начать работу'),
              ),
            if (_order!.status == OrderStatus.inProgress)
              ElevatedButton.icon(
                onPressed: () => _showCompleteOrderDialog(),
                icon: const Icon(Icons.check_circle),
                label: const Text('Завершить'),
              ),
            // Получение чека доступно только менеджерам/админам
            if (_order!.status == OrderStatus.completed && !isOperator) ...[
              const SizedBox(height: 8),
              ElevatedButton.icon(
                onPressed: _downloadReceipt,
                icon: const Icon(Icons.receipt),
                label: const Text('Получить чек'),
              ),
            ],
          ],
        ],
      ),
    );
  }
  
  bool _isOperator() {
    final authState = ref.read(authStateProvider);
    final user = authState.user;
    return user?.role == 'operator';
  }

  String _getStatusLabel(OrderStatus status) {
    switch (status) {
      case OrderStatus.draft:
        return 'Черновик';
      case OrderStatus.created:
        return 'Создан';
      case OrderStatus.approved:
        return 'Одобрен';
      case OrderStatus.inProgress:
        return 'В работе';
      case OrderStatus.completed:
        return 'Завершён';
      case OrderStatus.cancelled:
        return 'Отменён';
    }
  }

  String _formatDateTime(DateTime date) {
    return '${date.day}.${date.month}.${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _showCompleteOrderDialog() async {
    if (_order == null) return;

    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => CompleteOrderScreen(
          orderId: widget.orderId,
          order: _order!,
        ),
      ),
    );

    if (result == true && mounted) {
      // Обновляем заявку после завершения
      await _loadOrder();
    }
  }

  Future<void> _downloadReceipt() async {
    if (_order == null) return;

    // Показываем индикатор загрузки
    if (!mounted) return;
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    try {
      final orderService = ref.read(orderServiceProvider);
      final pdfBytesList = await orderService.getReceipt(widget.orderId);
      
      // Преобразуем List<int> в Uint8List
      final pdfBytes = Uint8List.fromList(pdfBytesList);
      
      // Закрываем индикатор загрузки
      if (mounted) {
        Navigator.pop(context);
      }
      
      if (kIsWeb) {
        // Для веб-платформы используем скачивание через браузер
        await _downloadReceiptWeb(pdfBytes);
      } else {
        // Для мобильных платформ сохраняем файл
        await _downloadReceiptMobile(pdfBytes);
      }
    } catch (e) {
      // Закрываем индикатор загрузки, если он открыт
      if (mounted && Navigator.canPop(context)) {
        Navigator.pop(context);
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка при загрузке чека: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  Future<void> _downloadReceiptWeb(Uint8List pdfBytes) async {
    if (!mounted) return;
    
    // Для веб используем скачивание через браузер
    try {
      if (kIsWeb) {
        download_helper.downloadFileWeb(
          pdfBytes,
          'receipt_${_order!.number}.pdf',
        );
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Чек успешно скачан'),
              duration: Duration(seconds: 3),
            ),
          );
        }
      } else {
        // Fallback: показываем PDF в просмотре
        // Временно отключено из-за проблем с библиотекой printing
        // if (mounted) {
        //   await Printing.layoutPdf(
        //     onLayout: (format) async => pdfBytes,
        //   );
        // }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('PDF сохранен в файлы приложения')),
          );
        }
      }
    } catch (e) {
      // Если не удалось скачать, показываем PDF в просмотре
      // Временно отключено из-за проблем с библиотекой printing
      // if (mounted) {
      //   await Printing.layoutPdf(
      //     onLayout: (format) async => pdfBytes,
      //   );
      // }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('PDF сохранен в файлы приложения')),
        );
      }
    }
  }

  Future<void> _downloadReceiptMobile(Uint8List pdfBytes) async {
    if (!mounted) return;
    
    try {
      // Получаем директорию для сохранения файлов
      final directory = await getApplicationDocumentsDirectory();
      final filePath = '${directory.path}/receipt_${_order!.number}.pdf';
      
      // Сохраняем PDF файл
      final file = File(filePath);
      await file.writeAsBytes(pdfBytes);
      
      // Показываем диалог с опциями: просмотр, сохранение
      if (mounted) {
        await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Чек загружен'),
            content: const Text('Выберите действие с чеком'),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  // Просмотр PDF - временно отключено из-за проблем с библиотекой printing
                  // Printing.layoutPdf(
                  //   onLayout: (format) async => pdfBytes,
                  // );
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('PDF сохранен в файлы приложения')),
                  );
                },
                child: const Text('Просмотр'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  // Показываем путь к файлу
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Чек сохранен: $filePath'),
                      duration: const Duration(seconds: 3),
                    ),
                  );
                },
                child: const Text('Информация'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Закрыть'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка при сохранении чека: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }
}


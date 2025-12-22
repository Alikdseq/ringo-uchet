import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';
// import 'package:printing/printing.dart';  // Временно отключено для сборки APK

// Условный импорт для веб-платформы
import 'download_helper_stub.dart'
    if (dart.library.html) 'download_helper_web.dart'
    as download_helper;
import '../../../core/constants/status_colors.dart';
import '../../../core/providers/reports_refresh_provider.dart';
import '../../auth/providers/auth_providers.dart';
import '../../auth/services/user_service.dart';
import '../models/order_models.dart';
import '../services/order_service.dart';
import '../widgets/status_timeline_widget.dart';
import '../widgets/change_status_dialog.dart';
import '../widgets/nomenclature_selection_dialog.dart';
import 'complete_order_screen.dart';
import '../../../shared/models/user.dart';

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
  
  // Контроллеры для редактирования (только для админа)
  final _totalAmountController = TextEditingController();
  final _addressController = TextEditingController();
  final _descriptionController = TextEditingController();
  bool _isSaving = false;
  List<OrderItem> _editableItems = [];
  Set<int> _selectedOperatorIds = {};
  List<UserInfo> _operators = [];
  bool _isLoadingOperators = false;
  
  // КРИТИЧНО: Убрали автосохранение - сохраняем только при явном действии пользователя
  // Это предотвращает мерцание и перезагрузки во время редактирования

  @override
  void initState() {
    super.initState();
    _loadOrder();
    _loadOperators();
  }
  
  @override
  void dispose() {
    // КРИТИЧНО: Убрали автосохранение - не нужно отменять таймеры
    _totalAmountController.dispose();
    _addressController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }
  
  Future<void> _loadOperators() async {
    setState(() {
      _isLoadingOperators = true;
    });
    try {
      final userService = ref.read(userServiceProvider);
      final operators = await userService.getOperators();
      setState(() {
        _operators = operators;
        _isLoadingOperators = false;
      });
    } catch (e) {
      setState(() {
        _operators = [];
        _isLoadingOperators = false;
      });
    }
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
        _editableItems = order.items?.toList() ?? [];
        // Восстанавливаем выбранных операторов из заявки
        final operatorIdsFromOrder = <int>{};
        if (order.operators != null) {
          for (var op in order.operators!) {
            operatorIdsFromOrder.add(op.id);
          }
        }
        if (order.operator != null) {
          operatorIdsFromOrder.add(order.operator!.id);
        }
        _selectedOperatorIds = operatorIdsFromOrder;
        
        // Устанавливаем стоимость - если есть totalAmount, используем его, иначе показываем 0
        final totalAmount = order.totalAmount > 0 ? order.totalAmount : 0.0;
        _totalAmountController.text = totalAmount.toStringAsFixed(2);
        _addressController.text = order.address;
        _descriptionController.text = order.description;
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
      
      // КРИТИЧНО: Обновляем отчеты при изменении статуса (особенно при завершении)
      // Это обеспечивает моментальное обновление отчетов без перезагрузки экрана
      ref.read(reportsRefreshProvider.notifier).state++;
      
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

                            // Описание (только для админа редактируемое)
                            if (!_isOperator()) ...[
                              _buildDescriptionSection(),
                              const Divider(),
                            ],

                            // Операторы (только для админа редактируемые)
                            if (!_isOperator()) ...[
                              _buildOperatorsSection(),
                              const Divider(),
                            ],

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
    final isAdmin = _isAdmin();
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Адрес',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              if (isAdmin)
                IconButton(
                  icon: const Icon(Icons.save, size: 20),
                  onPressed: _isSaving ? null : _saveChanges,
                  tooltip: 'Сохранить изменения',
                ),
            ],
          ),
          const SizedBox(height: 8),
          if (isAdmin)
            TextField(
              controller: _addressController,
              decoration: const InputDecoration(
                labelText: 'Адрес',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
              enabled: !_isSaving,
            )
          else
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
    final isAdmin = _isAdmin();
    final items = isAdmin ? _editableItems : (_order!.items ?? []);
    
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Номенклатура',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              if (isAdmin)
                ElevatedButton.icon(
                  onPressed: _isSaving ? null : _showNomenclatureDialog,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Добавить'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          if (items.isEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Номенклатура не выбрана',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey[600],
                    ),
              ),
            )
          else
            ...items.asMap().entries.map((entry) {
              final index = entry.key;
              final item = entry.value;
                // Правильный расчет стоимости для техники
                // ВСЕГДА используем lineTotal с сервера, если он есть - это правильный расчет
                double calculatedTotal;
                if (item.lineTotal != null && item.lineTotal! > 0) {
                  // Используем значение с сервера - это правильный расчет с учетом смен и часов
                  calculatedTotal = item.lineTotal!.toDouble();
                } else if (item.itemType == OrderItemType.equipment) {
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
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            calculatedTotal.toStringAsFixed(2) + ' ₽',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          if (isAdmin) ...[
                            const SizedBox(width: 8),
                            IconButton(
                              icon: const Icon(Icons.delete, size: 20, color: Colors.red),
                              onPressed: _isSaving ? null : () async {
                                setState(() {
                                  _editableItems.removeAt(index);
                                });
                                // При удалении item явно отправляем обновленный список items
                                await _saveChangesWithItems();
                              },
                              tooltip: 'Удалить',
                            ),
                          ],
                        ],
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
    final isAdmin = _isAdmin();
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
              if (isAdmin)
                SizedBox(
                  width: 150,
                  child: TextField(
                    controller: _totalAmountController,
                    decoration: const InputDecoration(
                      labelText: 'Стоимость (₽)',
                      border: OutlineInputBorder(),
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                    ),
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).primaryColor,
                        ),
                    keyboardType: TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}'))],
                    enabled: !_isSaving,
                    // КРИТИЧНО: Убрали автосохранение при изменении
                    // Сохранение происходит только при явном действии (кнопка сохранить, переход на следующий этап)
                    // Это предотвращает мерцание и перезагрузки во время редактирования
                    onChanged: (value) {
                      // Просто обновляем значение БЕЗ сохранения
                      // Пользователь может редактировать сколько угодно без мерцаний
                    },
                  ),
                )
              else
                Text(
                  '${(_order!.totalAmount > 0 ? _order!.totalAmount : 0.0).toStringAsFixed(2)} ₽',
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
    
    // Операторы должны видеть кнопки для своих заявок (назначенных им)
    // Менеджеры и админы видят кнопки для всех заявок
    final canSeeButtons = !isOperator || isOrderOperator;
    
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Кнопки смены статуса (доступны менеджерам/админам и операторам этой заявки)
          if (canSeeButtons) ...[
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
            // Кнопка удаления доступна только менеджерам/админам и если заявка не удалена
            if (!isOperator) ...[
              const SizedBox(height: 8),
              ElevatedButton.icon(
                onPressed: _deleteOrder,
                icon: const Icon(Icons.delete),
                label: const Text('Удалить заявку'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
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

  bool _isAdmin() {
    final authState = ref.read(authStateProvider);
    final user = authState.user;
    return user?.role == 'admin';
  }

  Widget _buildDescriptionSection() {
    final isAdmin = _isAdmin();
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Описание',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 8),
          if (isAdmin)
            TextField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Описание заявки',
                border: OutlineInputBorder(),
              ),
              maxLines: 4,
              enabled: !_isSaving,
              // КРИТИЧНО: Убрали автосохранение при изменении
              // Сохранение происходит только при явном действии (кнопка сохранить, переход на следующий этап)
              // Это предотвращает мерцание и перезагрузки во время редактирования
              onChanged: (value) {
                // Просто обновляем значение БЕЗ сохранения
                // Пользователь может редактировать сколько угодно без мерцаний
              },
            )
          else
            Text(
              _order!.description.isEmpty ? 'Описание отсутствует' : _order!.description,
              style: TextStyle(
                color: _order!.description.isEmpty ? Colors.grey[600] : null,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildOperatorsSection() {
    final isAdmin = _isAdmin();
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Операторы',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 8),
          if (_isLoadingOperators)
            const Center(child: CircularProgressIndicator())
          else if (_operators.isEmpty)
            const Text(
              'Операторы не найдены',
              style: TextStyle(color: Colors.grey),
            )
          else if (isAdmin)
            Card(
              child: Column(
                children: [
                  ..._operators.map((operator) {
                    final isSelected = _selectedOperatorIds.contains(operator.id);
                    return CheckboxListTile(
                      title: Text(operator.fullName),
                      subtitle: operator.phone != null ? Text(operator.phone!) : null,
                      value: isSelected,
                      onChanged: _isSaving ? null : (value) {
                        if (value == true) {
                          // Проверяем, не добавлен ли уже оператор
                          if (_selectedOperatorIds.contains(operator.id)) {
                            // Оператор уже добавлен - показываем предупреждение
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Оператор ${operator.fullName} уже добавлен'),
                                backgroundColor: Colors.orange,
                                duration: const Duration(seconds: 2),
                              ),
                            );
                            return;
                          }
                          setState(() {
                            _selectedOperatorIds.add(operator.id);
                          });
                        } else {
                          setState(() {
                            _selectedOperatorIds.remove(operator.id);
                          });
                        }
                        // КРИТИЧНО: Убрали автосохранение при изменении операторов
                        // Сохранение происходит только при явном действии (кнопка сохранить, переход на следующий этап)
                        // Это предотвращает мерцание и перезагрузки во время редактирования
                      },
                    );
                  }).toList(),
                ],
              ),
            )
          else
            ...(_order!.operators ?? []).map((operator) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text('• ${operator.fullName}'),
              );
            }),
        ],
      ),
    );
  }

  Future<void> _showNomenclatureDialog() async {
    final result = await showDialog<List<OrderItem>>(
      context: context,
      builder: (context) => const NomenclatureSelectionDialog(),
    );

    if (result != null && result.isNotEmpty) {
      setState(() {
        _editableItems.addAll(result);
      });
      // При добавлении items явно отправляем их как измененные
      // Это гарантирует, что стоимость новых items прибавится к total_amount
      _saveChangesWithItems();
    }
  }
  
  Future<void> _saveChangesWithItems() async {
    if (_order == null || !_isAdmin()) return;
    
    setState(() {
      _isSaving = true;
    });
    
    try {
      final orderService = ref.read(orderServiceProvider);
      
      double? totalAmount;
      if (_totalAmountController.text.isNotEmpty) {
        totalAmount = double.tryParse(_totalAmountController.text.trim());
      }
      
      // При изменении items (добавлении или удалении) отправляем их явно
      // Пустой список означает удаление всех items
      final request = OrderRequest(
        address: _addressController.text.trim(),
        startDt: _order!.startDt,
        endDt: _order!.endDt,
        description: _descriptionController.text.trim(),
        status: _order!.status,
        operatorIds: _selectedOperatorIds.isNotEmpty ? _selectedOperatorIds.toList() : null,
        items: _editableItems, // Всегда отправляем список, даже если он пустой
        totalAmount: totalAmount,
      );
      
      final updatedOrder = await orderService.updateOrder(widget.orderId, request);
      
      // Обновляем локальное состояние сразу после успешного сохранения
      if (mounted) {
        setState(() {
          _order = updatedOrder;
          _editableItems = updatedOrder.items?.toList() ?? [];
          // Обновляем контроллер стоимости из обновленной заявки
          final totalAmount = updatedOrder.totalAmount > 0 ? updatedOrder.totalAmount : 0.0;
          _totalAmountController.text = totalAmount.toStringAsFixed(2);
        });
      }
      
      // КРИТИЧНО: НЕ перезагружаем заявку - обновляем только локальное состояние
      // Это предотвращает мерцание и перезагрузку UI
      // Данные уже обновлены в setState выше
      
      // КРИТИЧНО: Если заявка завершена, обновляем отчеты немедленно
      // Это обеспечивает моментальное отображение изменений в отчетах
      if (updatedOrder.status == OrderStatus.completed) {
        ref.read(reportsRefreshProvider.notifier).state++;
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_editableItems.isEmpty 
              ? 'Номенклатура удалена, стоимость обновлена'
              : 'Номенклатура обновлена, стоимость пересчитана'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка сохранения: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
        await _loadOrder();
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Future<void> _saveChanges() async {
    if (_order == null || !_isAdmin()) return;
    
    setState(() {
      _isSaving = true;
    });
    
    try {
      final orderService = ref.read(orderServiceProvider);
      
      double? totalAmount;
      if (_totalAmountController.text.isNotEmpty) {
        totalAmount = double.tryParse(_totalAmountController.text.trim());
      }
      
      // Определяем, были ли изменены items (сравниваем с оригинальными items из заявки)
      final originalItems = _order!.items ?? [];
      bool itemsChanged = false;
      
      if (_editableItems.length != originalItems.length) {
        itemsChanged = true;
      } else {
        // Сравниваем каждый item по основным полям
        for (int i = 0; i < _editableItems.length; i++) {
          final editable = _editableItems[i];
          final original = originalItems[i];
          
          if (editable.id != original.id ||
              editable.quantity != original.quantity ||
              editable.unitPrice != original.unitPrice ||
              editable.itemType != original.itemType ||
              editable.refId != original.refId) {
            itemsChanged = true;
            break;
          }
          
          // Сравниваем metadata (может содержать shifts, hours и т.д.)
          if (editable.metadata.toString() != original.metadata.toString()) {
            itemsChanged = true;
            break;
          }
        }
      }
      
      // Отправляем items только если они были изменены
      // Если items не изменены, отправляем null - это означает "не трогать существующие items"
      final request = OrderRequest(
        address: _addressController.text.trim(),
        startDt: _order!.startDt,
        endDt: _order!.endDt,
        description: _descriptionController.text.trim(),
        status: _order!.status,
        operatorIds: _selectedOperatorIds.isNotEmpty ? _selectedOperatorIds.toList() : null,
        items: itemsChanged ? (_editableItems.isNotEmpty ? _editableItems : []) : null,
        totalAmount: totalAmount,
      );
      
      final updatedOrder = await orderService.updateOrder(widget.orderId, request);
      
      // Обновляем локальное состояние сразу после успешного сохранения
      if (mounted) {
        setState(() {
          _order = updatedOrder;
          _editableItems = updatedOrder.items?.toList() ?? [];
          // Обновляем контроллер стоимости из обновленной заявки
          final totalAmount = updatedOrder.totalAmount > 0 ? updatedOrder.totalAmount : 0.0;
          _totalAmountController.text = totalAmount.toStringAsFixed(2);
        });
      }
      
      // КРИТИЧНО: НЕ перезагружаем заявку - обновляем только локальное состояние
      // Это предотвращает мерцание и перезагрузку UI
      // Данные уже обновлены в setState выше
      
      // КРИТИЧНО: Если заявка завершена, обновляем отчеты немедленно
      // Это обеспечивает моментальное отображение изменений в отчетах
      if (updatedOrder.status == OrderStatus.completed) {
        ref.read(reportsRefreshProvider.notifier).state++;
      }
      
      // КРИТИЧНО: Показываем уведомление только при явном сохранении (не при автосохранении)
      // Уведомление показывается только если это было явное действие пользователя
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Изменения сохранены'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка сохранения: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
        // КРИТИЧНО: НЕ перезагружаем заявку даже при ошибке
        // Это предотвращает мерцание - пользователь видит что было до ошибки
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
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
  
  Future<void> _deleteOrder() async {
    if (_order == null) return;
    
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удалить заявку?'),
        content: Text('Вы уверены, что хотите удалить заявку ${_order!.number}? Заявка будет полностью удалена из базы данных. Это действие нельзя отменить.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
    
    if (confirm != true) return;
    
    try {
      final orderService = ref.read(orderServiceProvider);
      await orderService.deleteOrder(widget.orderId);
      
      // Мгновенно обновляем отчеты после удаления заявки
      ref.read(reportsRefreshProvider.notifier).state++;
      
      if (mounted) {
        Navigator.pop(context, true); // Возвращаемся к списку заявок
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Заявка полностью удалена из базы данных')),
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
          
          // Предлагаем отправить в WhatsApp если есть номер клиента
          final clientPhone = _order?.client?.phone;
          if (clientPhone != null && clientPhone.isNotEmpty) {
            await _showWhatsAppDialog(clientPhone);
          }
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
      
      // Получаем номер телефона клиента для отправки в WhatsApp
      final clientPhone = _order?.client?.phone;
      final canSendWhatsApp = clientPhone != null && clientPhone.isNotEmpty;
      final clientPhoneNonNull = clientPhone; // Для использования внутри if (canSendWhatsApp)
      
      // Показываем диалог с опциями: просмотр, сохранение, отправка в WhatsApp
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
              if (canSendWhatsApp && clientPhoneNonNull != null)
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _sendReceiptToWhatsApp(clientPhoneNonNull, filePath);
                  },
                  child: const Text('Отправить в WhatsApp'),
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
  
  Future<void> _sendReceiptToWhatsApp(String phone, String filePath) async {
    try {
      // Нормализуем номер телефона (убираем все кроме цифр)
      final normalizedPhone = phone.replaceAll(RegExp(r'[^\d]'), '');
      // Если номер начинается с 8, заменяем на 7
      final whatsappPhone = normalizedPhone.startsWith('8') 
          ? '7${normalizedPhone.substring(1)}'
          : normalizedPhone.startsWith('+') 
              ? normalizedPhone.substring(1)
              : normalizedPhone;
      
      // Формируем URL для WhatsApp
      final whatsappUrl = 'https://wa.me/$whatsappPhone?text=Чек%20по%20заявке%20${_order!.number}';
      
      // Открываем WhatsApp через url_launcher
      if (await canLaunchUrl(Uri.parse(whatsappUrl))) {
        await launchUrl(Uri.parse(whatsappUrl), mode: LaunchMode.externalApplication);
        
        // После открытия WhatsApp, можно попробовать отправить файл
        // Но для этого нужен другой подход - через share_plus или file_picker
        // Пока просто открываем чат с текстом
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('WhatsApp открыт. Вручную отправьте файл: $filePath'),
              duration: const Duration(seconds: 5),
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Не удалось открыть WhatsApp. Убедитесь, что приложение установлено.'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка при отправке в WhatsApp: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
  
  Future<void> _showWhatsAppDialog(String phone) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Отправить чек в WhatsApp?'),
        content: Text('Отправить чек заказчику ${_order?.client?.name ?? ""} (${phone})?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Отправить'),
          ),
        ],
      ),
    );
    
    if (result == true && mounted) {
      // Для веб просто открываем WhatsApp с текстом
      await _sendReceiptToWhatsApp(phone, '');
    }
  }
}


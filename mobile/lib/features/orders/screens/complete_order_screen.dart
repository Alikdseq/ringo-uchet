import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/order_models.dart';
import '../services/order_service.dart';
import '../../catalog/services/catalog_service.dart';
import '../../catalog/models/catalog_models.dart';

/// Экран завершения заявки
class CompleteOrderScreen extends ConsumerStatefulWidget {
  final String orderId;
  final Order order;

  const CompleteOrderScreen({
    super.key,
    required this.orderId,
    required this.order,
  });

  @override
  ConsumerState<CompleteOrderScreen> createState() => _CompleteOrderScreenState();
}

class _CompleteOrderScreenState extends ConsumerState<CompleteOrderScreen> {
  final _formKey = GlobalKey<FormState>();
  final _scrollController = ScrollController();
  final _commentController = TextEditingController();
  final _operatorSalaryController = TextEditingController();  // Для обратной совместимости
  // Map для хранения зарплаты каждого оператора: operatorId -> salary
  final Map<int, TextEditingController> _operatorSalaryControllers = {};

  DateTime? _endDt;
  final List<SelectedItem> _selectedItems = [];
  double _totalAmount = 0.0;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    // Инициализируем контроллеры для зарплаты операторов
    _initializeOperatorControllers();
  }

  void _initializeOperatorControllers() {
    final operators = widget.order.operators ?? [];
    if (operators.isEmpty && widget.order.operator != null) {
      // Для обратной совместимости
      final operatorId = widget.order.operator!.id;
      if (!_operatorSalaryControllers.containsKey(operatorId)) {
        _operatorSalaryControllers[operatorId] = TextEditingController();
      }
    } else {
      for (final operator in operators) {
        if (!_operatorSalaryControllers.containsKey(operator.id)) {
          _operatorSalaryControllers[operator.id] = TextEditingController();
        }
      }
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _commentController.dispose();
    _operatorSalaryController.dispose();
    // Удаляем все контроллеры зарплаты операторов
    for (final controller in _operatorSalaryControllers.values) {
      controller.dispose();
    }
    _operatorSalaryControllers.clear();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Завершение заявки'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          controller: _scrollController,
          padding: const EdgeInsets.all(16),
          children: [
            // Информация о заявке
            _buildOrderInfo(),
            const SizedBox(height: 24),

            // Комментарий
            _buildSectionHeader('Комментарий'),
            const SizedBox(height: 8),
            TextFormField(
              controller: _commentController,
              decoration: const InputDecoration(
                labelText: 'Комментарий',
                hintText: 'Введите комментарий к завершению заявки',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),

            const SizedBox(height: 24),

            // Дата окончания
            _buildSectionHeader('Дата окончания *'),
            const SizedBox(height: 8),
            ListTile(
              title: const Text('Дата окончания *'),
              subtitle: Text(_endDt != null
                  ? '${_endDt!.day}.${_endDt!.month}.${_endDt!.year} ${_endDt!.hour}:${_endDt!.minute.toString().padLeft(2, '0')}'
                  : 'Не выбрана'),
              trailing: const Icon(Icons.calendar_today),
              onTap: () async {
                final date = await showDatePicker(
                  context: context,
                  initialDate: widget.order.startDt,
                  firstDate: widget.order.startDt,
                  lastDate: DateTime.now().add(const Duration(days: 365)),
                );
                if (date != null) {
                  final time = await showTimePicker(
                    context: context,
                    initialTime: TimeOfDay.now(),
                  );
                  if (time != null) {
                    setState(() {
                      _endDt = DateTime(
                        date.year,
                        date.month,
                        date.day,
                        time.hour,
                        time.minute,
                      );
                    });
                  }
                }
              },
            ),

            const SizedBox(height: 24),

            // ЗП операторам
            _buildSectionHeader('Зарплата операторам'),
            const SizedBox(height: 8),
            _buildOperatorsSalarySection(),
            const SizedBox(height: 24),

            // Элементы номенклатуры
            _buildSectionHeader('Элементы номенклатуры *'),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: _showItemSelectionDialog,
              icon: const Icon(Icons.add),
              label: const Text('Добавить элемент'),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 48),
              ),
            ),
            const SizedBox(height: 16),
            if (_selectedItems.isNotEmpty) ...[
              ..._selectedItems.asMap().entries.map((entry) {
                final index = entry.key;
                final item = entry.value;
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    title: Text(item.name),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_getItemSubtitle(item)),
                        if (item.itemType == OrderItemType.equipment && item.fuelExpense != null && item.fuelExpense! > 0)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              'Расходы на топливо: ${item.fuelExpense!.toStringAsFixed(2)} ₽',
                              style: TextStyle(
                                fontSize: 12,
                                color: Theme.of(context).colorScheme.secondary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        if (item.itemType == OrderItemType.equipment && item.repairExpense != null && item.repairExpense! > 0)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              'Расходы на ремонт: ${item.repairExpense!.toStringAsFixed(2)} ₽',
                              style: TextStyle(
                                fontSize: 12,
                                color: Theme.of(context).colorScheme.error,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                      ],
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Для техники и материалов можно редактировать
                        IconButton(
                          icon: const Icon(Icons.edit),
                          onPressed: () {
                            if (item.itemType == OrderItemType.equipment) {
                              _editEquipmentShiftsAndHours(index);
                            } else {
                              _editItemQuantity(index);
                            }
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () {
                            setState(() {
                              _selectedItems.removeAt(index);
                              _calculateTotal();
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                );
              }),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Итого:',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    Text(
                      '${_totalAmount.toStringAsFixed(2)} ₽',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).primaryColor,
                          ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 32),

            // Кнопка завершения
            ElevatedButton(
              onPressed: _isSaving ? null : _completeOrder,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 48),
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: _isSaving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Завершить заявку'),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderInfo() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Заявка ${widget.order.number}',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            Text('Клиент: ${widget.order.client?.name ?? "Не указан"}'),
            Text('Адрес: ${widget.order.address}'),
            Text('Дата начала: ${_formatDateTime(widget.order.startDt)}'),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
    );
  }

  Widget _buildOperatorsSalarySection() {
    final operators = widget.order.operators ?? [];
    final operatorsList = operators.isEmpty && widget.order.operator != null
        ? [widget.order.operator!]
        : operators;
    
    if (operatorsList.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text('Операторы не назначены'),
        ),
      );
    }
    
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Укажите зарплату для каждого оператора',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          ...operatorsList.map((operator) {
            final operatorId = operator.id;
            // Убеждаемся, что контроллер инициализирован
            if (!_operatorSalaryControllers.containsKey(operatorId)) {
              _operatorSalaryControllers[operatorId] = TextEditingController();
            }
            final controller = _operatorSalaryControllers[operatorId]!;
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: TextFormField(
                controller: controller,
                decoration: InputDecoration(
                  labelText: 'ЗП для ${operator.fullName} (₽)',
                  hintText: '0.00',
                  border: const OutlineInputBorder(),
                ),
                keyboardType: TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  String _getItemSubtitle(SelectedItem item) {
    if (item.itemType == OrderItemType.equipment) {
      // Для техники показываем смены и часы
      final shifts = item.shifts ?? 0.0;
      final hours = item.hours ?? 0.0;
      final dailyRate = item.dailyRate ?? 0.0;
      final hourlyRate = item.unitPrice;
      
      String timeInfo = '';
      if (shifts > 0 && hours > 0) {
        timeInfo = '${shifts.toInt()} ${shifts == 1 ? "смена" : shifts < 5 ? "смены" : "смен"}, ${hours.toStringAsFixed(1)} ч';
      } else if (shifts > 0) {
        timeInfo = '${shifts.toInt()} ${shifts == 1 ? "смена" : shifts < 5 ? "смены" : "смен"}';
      } else if (hours > 0) {
        timeInfo = '${hours.toStringAsFixed(1)} ч';
      } else {
        timeInfo = 'Не указано';
      }
      
      // Рассчитываем стоимость
      final shiftsCost = shifts * dailyRate;
      final hoursCost = hours * hourlyRate;
      final totalCost = shiftsCost + hoursCost;
      
      return '$timeInfo = ${totalCost.toStringAsFixed(2)} ₽';
    } else if (item.itemType == OrderItemType.material) {
      return '${item.quantity} ${item.unit} × ${item.unitPrice.toStringAsFixed(2)} ₽ = ${(item.quantity * item.unitPrice).toStringAsFixed(2)} ₽';
    }
    return '${item.quantity} ${item.unit} × ${item.unitPrice.toStringAsFixed(2)} ₽ = ${(item.quantity * item.unitPrice).toStringAsFixed(2)} ₽';
  }

  Future<void> _showItemSelectionDialog() async {
    int selectedTab = 0; // 0 - техника, 1 - грунт, 2 - инструмент, 3 - навеска

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => Dialog(
          child: Container(
            width: double.maxFinite,
            constraints: const BoxConstraints(maxHeight: 600),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Заголовок
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Выберите элемент',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),
                // Табы
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () => setDialogState(() => selectedTab = 0),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            border: Border(
                              bottom: BorderSide(
                                color: selectedTab == 0
                                    ? Theme.of(context).primaryColor
                                    : Colors.transparent,
                                width: 2,
                              ),
                            ),
                          ),
                          child: Text(
                            'Техника',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: selectedTab == 0
                                  ? Theme.of(context).primaryColor
                                  : null,
                              fontWeight: selectedTab == 0
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: InkWell(
                        onTap: () => setDialogState(() => selectedTab = 1),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            border: Border(
                              bottom: BorderSide(
                                color: selectedTab == 1
                                    ? Theme.of(context).primaryColor
                                    : Colors.transparent,
                                width: 2,
                              ),
                            ),
                          ),
                          child: Text(
                            'Грунт',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: selectedTab == 1
                                  ? Theme.of(context).primaryColor
                                  : null,
                              fontWeight: selectedTab == 1
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: InkWell(
                        onTap: () => setDialogState(() => selectedTab = 2),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            border: Border(
                              bottom: BorderSide(
                                color: selectedTab == 2
                                    ? Theme.of(context).primaryColor
                                    : Colors.transparent,
                                width: 2,
                              ),
                            ),
                          ),
                          child: Text(
                            'Инструмент',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: selectedTab == 2
                                  ? Theme.of(context).primaryColor
                                  : null,
                              fontWeight: selectedTab == 2
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: InkWell(
                        onTap: () => setDialogState(() => selectedTab = 3),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            border: Border(
                              bottom: BorderSide(
                                color: selectedTab == 3
                                    ? Theme.of(context).primaryColor
                                    : Colors.transparent,
                                width: 2,
                              ),
                            ),
                          ),
                          child: Text(
                            'Навеска',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: selectedTab == 3
                                  ? Theme.of(context).primaryColor
                                  : null,
                              fontWeight: selectedTab == 3
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                // Контент
                Flexible(
                  child: Container(
                    constraints: const BoxConstraints(maxHeight: 400),
                    child: _buildItemList(selectedTab, setDialogState),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildItemList(int tab, StateSetter setDialogState) {
    final catalogService = ref.read(catalogServiceProvider);

    if (tab == 0) {
      // Техника
      return FutureBuilder<List<Equipment>>(
        future: catalogService.getEquipment(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Ошибка: ${snapshot.error}'));
          }
          final equipment = snapshot.data ?? [];
          if (equipment.isEmpty) {
            return const Center(child: Text('Техника не найдена'));
          }
          return ListView.builder(
            itemCount: equipment.length,
            itemBuilder: (context, index) {
              final item = equipment[index];
              return ListTile(
                title: Text(item.name),
                subtitle: Text(
                  '${item.hourlyRate} ₽/час${item.dailyRate != null ? ', ${item.dailyRate} ₽/смена' : ''}',
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: () => _addEquipmentWithShiftsAndHours(item, setDialogState),
                ),
              );
            },
          );
        },
      );
    } else {
      // Материалы (грунт, инструмент, навеска)
      final category = tab == 1 ? 'soil' : tab == 2 ? 'tool' : 'attachment';
      return FutureBuilder<List<MaterialItem>>(
        future: catalogService.getMaterials(category: category),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Ошибка: ${snapshot.error}'));
          }
          final materials = snapshot.data ?? [];
          if (materials.isEmpty) {
            return Center(child: Text('${tab == 1 ? "Грунт" : tab == 2 ? "Инструменты" : "Навески"} не найдены'));
          }
          return ListView.builder(
            itemCount: materials.length,
            itemBuilder: (context, index) {
              final material = materials[index];
              return ListTile(
                title: Text(material.name),
                subtitle: Text('${material.price} ₽/${material.unit}'),
                trailing: IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: () => _addItem(
                    SelectedItem(
                      itemType: OrderItemType.material,
                      refId: material.id,
                      name: material.name,
                      unitPrice: material.price,
                      unit: material.unit,
                      quantity: tab == 1 ? 1.0 : 1.0, // Для грунта можно будет изменить объем
                      metadata: {'material_category': category},
                    ),
                    setDialogState,
                  ),
                ),
              );
            },
          );
        },
      );
    }
  }

  void _addEquipmentWithShiftsAndHours(Equipment equipment, StateSetter setDialogState) async {
    Navigator.pop(context); // Закрываем диалог выбора
    
    final shiftsController = TextEditingController();
    final hoursController = TextEditingController();
    final fuelExpenseController = TextEditingController();
    final repairExpenseController = TextEditingController();
    
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Добавить: ${equipment.name}'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: shiftsController,
                decoration: const InputDecoration(
                  labelText: 'Количество смен',
                  hintText: '0',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.numberWithOptions(decimal: false),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d+')),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: hoursController,
                decoration: const InputDecoration(
                  labelText: 'Количество часов',
                  hintText: '0.0',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: fuelExpenseController,
                decoration: const InputDecoration(
                  labelText: 'Расходы на топливо (₽)',
                  hintText: '0.00',
                  border: OutlineInputBorder(),
                  helperText: 'Опционально',
                ),
                keyboardType: TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: repairExpenseController,
                decoration: const InputDecoration(
                  labelText: 'Расходы на ремонт техники (₽)',
                  hintText: '0.00',
                  border: OutlineInputBorder(),
                  helperText: 'Опционально',
                ),
                keyboardType: TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                ],
              ),
              if (equipment.dailyRate != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    'Цена за смену: ${equipment.dailyRate} ₽\nЦена за час: ${equipment.hourlyRate} ₽',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () {
              final shifts = double.tryParse(shiftsController.text) ?? 0.0;
              final hours = double.tryParse(hoursController.text) ?? 0.0;
              
              if (shifts == 0 && hours == 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Укажите хотя бы количество смен или часов'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }
              
              Navigator.pop(context, true);
            },
            child: const Text('Добавить'),
          ),
        ],
      ),
    );
    
    if (result == true) {
      final shifts = double.tryParse(shiftsController.text) ?? 0.0;
      final hours = double.tryParse(hoursController.text) ?? 0.0;
      final fuelExpense = fuelExpenseController.text.trim().isEmpty 
          ? null 
          : double.tryParse(fuelExpenseController.text.trim());
      final repairExpense = repairExpenseController.text.trim().isEmpty 
          ? null 
          : double.tryParse(repairExpenseController.text.trim());
      
      setState(() {
        _selectedItems.add(
          SelectedItem(
            itemType: OrderItemType.equipment,
            refId: equipment.id,
            name: equipment.name,
            unitPrice: equipment.hourlyRate,
            dailyRate: equipment.dailyRate,
            unit: 'час',
            quantity: shifts * 8 + hours, // Общее количество для совместимости
            shifts: shifts,
            hours: hours,
            fuelExpense: fuelExpense,
            repairExpense: repairExpense,
          ),
        );
        _calculateTotal();
      });
    }
  }

  void _addItem(SelectedItem item, StateSetter setDialogState) {
    Navigator.pop(context);
    setState(() {
      _selectedItems.add(item);
      _calculateTotal();
    });
  }

  void _editEquipmentShiftsAndHours(int index) async {
    final item = _selectedItems[index];
    final shiftsController = TextEditingController(
      text: (item.shifts ?? 0.0).toStringAsFixed(0),
    );
    final hoursController = TextEditingController(
      text: (item.hours ?? 0.0).toStringAsFixed(2),
    );
    final fuelExpenseController = TextEditingController(
      text: (item.fuelExpense ?? 0.0).toStringAsFixed(2),
    );
    final repairExpenseController = TextEditingController(
      text: (item.repairExpense ?? 0.0).toStringAsFixed(2),
    );

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Изменить: ${item.name}'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: shiftsController,
                decoration: const InputDecoration(
                  labelText: 'Количество смен',
                  hintText: '0',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.numberWithOptions(decimal: false),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d+')),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: hoursController,
                decoration: const InputDecoration(
                  labelText: 'Количество часов',
                  hintText: '0.0',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: fuelExpenseController,
                decoration: const InputDecoration(
                  labelText: 'Расходы на топливо (₽)',
                  hintText: '0.00',
                  border: OutlineInputBorder(),
                  helperText: 'Опционально',
                ),
                keyboardType: TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: repairExpenseController,
                decoration: const InputDecoration(
                  labelText: 'Расходы на ремонт техники (₽)',
                  hintText: '0.00',
                  border: OutlineInputBorder(),
                  helperText: 'Опционально',
                ),
                keyboardType: TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                ],
              ),
              if (item.dailyRate != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    'Цена за смену: ${item.dailyRate} ₽\nЦена за час: ${item.unitPrice} ₽',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () {
              final shifts = double.tryParse(shiftsController.text) ?? 0.0;
              final hours = double.tryParse(hoursController.text) ?? 0.0;
              
              if (shifts == 0 && hours == 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Укажите хотя бы количество смен или часов'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }
              
              Navigator.pop(context, true);
            },
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );
    
    if (result == true) {
      final shifts = double.tryParse(shiftsController.text) ?? 0.0;
      final hours = double.tryParse(hoursController.text) ?? 0.0;
      final fuelExpense = fuelExpenseController.text.trim().isEmpty 
          ? null 
          : double.tryParse(fuelExpenseController.text.trim());
      final repairExpense = repairExpenseController.text.trim().isEmpty 
          ? null 
          : double.tryParse(repairExpenseController.text.trim());
      
      setState(() {
        _selectedItems[index].shifts = shifts;
        _selectedItems[index].hours = hours;
        _selectedItems[index].quantity = shifts * 8 + hours; // Общее количество для совместимости
        _selectedItems[index].fuelExpense = fuelExpense;
        _selectedItems[index].repairExpense = repairExpense;
        _calculateTotal();
      });
    }
  }

  void _editItemQuantity(int index) {
    final item = _selectedItems[index];
    final quantityController = TextEditingController(
      text: item.quantity.toStringAsFixed(2),
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Изменить количество: ${item.name}'),
        content: TextField(
          controller: quantityController,
          decoration: const InputDecoration(
            labelText: 'Количество',
            hintText: '0.00',
          ),
          keyboardType: TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () {
              final quantity = double.tryParse(quantityController.text) ?? 0.0;
              if (quantity > 0) {
                setState(() {
                  _selectedItems[index].quantity = quantity;
                  _calculateTotal();
                });
                Navigator.pop(context);
              }
            },
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );
  }

  void _calculateTotal() {
    setState(() {
      _totalAmount = _selectedItems.fold(
        0.0,
        (sum, item) {
          // Для техники рассчитываем: смены * daily_rate + часы * hourly_rate
          if (item.itemType == OrderItemType.equipment) {
            final shifts = item.shifts ?? 0.0;
            final hours = item.hours ?? 0.0;
            final dailyRate = item.dailyRate ?? 0.0;
            final hourlyRate = item.unitPrice;
            return sum + (shifts * dailyRate) + (hours * hourlyRate);
          }
          return sum + (item.quantity * item.unitPrice);
        },
      );
    });
  }

  Future<void> _completeOrder() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_endDt == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Выберите дату окончания')),
      );
      return;
    }

    if (_selectedItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Добавьте хотя бы один элемент номенклатуры')),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final orderService = ref.read(orderServiceProvider);
      
      // Формируем список зарплат для каждого оператора
      final operatorSalaries = <Map<String, dynamic>>[];
      for (final entry in _operatorSalaryControllers.entries) {
        final operatorId = entry.key;
        final controller = entry.value;
        final salaryText = controller.text.trim();
        if (salaryText.isNotEmpty) {
          final salary = double.tryParse(salaryText);
          if (salary != null && salary > 0) {
            operatorSalaries.add({
              'operator_id': operatorId,
              'salary': salary,
            });
          }
        }
      }
      
      // Формируем данные для завершения заявки
      final completeData = {
        'comment': _commentController.text.trim(),
        'end_dt': _endDt!.toIso8601String(),
        // Для обратной совместимости оставляем operator_salary (первый оператор)
        'operator_salary': operatorSalaries.isNotEmpty 
            ? operatorSalaries.first['salary'] 
            : (_operatorSalaryController.text.trim().isEmpty 
                ? null 
                : double.tryParse(_operatorSalaryController.text.trim())),
        // Новое поле с зарплатами для всех операторов
        'operator_salaries': operatorSalaries,
        'items': _selectedItems.map((item) {
          final itemData = {
            'item_type': item.itemType.toString().split('.').last,
            'ref_id': item.refId,
            'quantity': item.quantity,
            'unit': item.unit,
            'unit_price': item.unitPrice, // Обязательное поле
            'tax_rate': 0.0,
            'discount': 0.0,
            'metadata': item.metadata ?? {},
          };
          
          // Для техники добавляем информацию о сменах, часах и расходах на топливо
          if (item.itemType == OrderItemType.equipment) {
            itemData['metadata'] = {
              ...(item.metadata ?? {}),
              'shifts': item.shifts ?? 0.0,
              'hours': item.hours ?? 0.0,
            };
            // quantity устанавливаем как общее количество для совместимости
            itemData['quantity'] = (item.shifts ?? 0.0) * 8 + (item.hours ?? 0.0);
            // Добавляем расходы на топливо для данной техники
            if (item.fuelExpense != null && item.fuelExpense! > 0) {
              itemData['fuel_expense'] = item.fuelExpense!.toStringAsFixed(2);
            }
            // Добавляем расходы на ремонт техники
            if (item.repairExpense != null && item.repairExpense! > 0) {
              itemData['repair_expense'] = item.repairExpense!.toStringAsFixed(2);
            }
          }
          
          return itemData;
        }).toList(),
      };

      await orderService.completeOrder(widget.orderId, completeData);

      if (mounted) {
        Navigator.pop(context, true); // Возвращаем true, чтобы обновить список
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Заявка успешно завершена')),
        );
      }
    } catch (e) {
      if (mounted) {
        String errorMessage = 'Ошибка при завершении заявки';
        if (e.toString().contains('400')) {
          errorMessage = 'Ошибка валидации данных. Проверьте заполненные поля.';
        } else if (e.toString().contains('401')) {
          errorMessage = 'Требуется авторизация. Войдите в систему заново.';
        } else if (e.toString().contains('403')) {
          errorMessage = 'Недостаточно прав для завершения заявки.';
        } else {
          errorMessage = 'Ошибка: ${e.toString()}';
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  String _formatDateTime(DateTime date) {
    return '${date.day}.${date.month}.${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }
}

/// Вспомогательный класс для выбранных позиций
class SelectedItem {
  final OrderItemType itemType;
  final int refId;
  final String name;
  final double unitPrice;
  final double? dailyRate; // Для техники - цена за смену
  final String unit;
  double quantity;
  double? shifts; // Количество смен (для техники)
  double? hours; // Количество часов (для техники)
  double? fuelExpense; // Расходы на топливо для данной техники
  double? repairExpense; // Расходы на ремонт техники
  final Map<String, dynamic>? metadata;

  SelectedItem({
    required this.itemType,
    required this.refId,
    required this.name,
    required this.unitPrice,
    this.dailyRate,
    required this.unit,
    required this.quantity,
    this.shifts,
    this.hours,
    this.fuelExpense,
    this.repairExpense,
    this.metadata,
  });
}


import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/order_models.dart';
import '../../catalog/services/catalog_service.dart';
import '../../catalog/models/catalog_models.dart';

/// Диалог выбора номенклатуры
class NomenclatureSelectionDialog extends ConsumerStatefulWidget {
  const NomenclatureSelectionDialog({super.key});

  @override
  ConsumerState<NomenclatureSelectionDialog> createState() => _NomenclatureSelectionDialogState();
}

class _NomenclatureSelectionDialogState extends ConsumerState<NomenclatureSelectionDialog> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _searchController = TextEditingController();
  List<OrderItem> _selectedItems = [];
  
  Future<List<Equipment>>? _equipmentFuture;
  Future<List<ServiceItem>>? _servicesFuture;
  Future<List<MaterialItem>>? _materialsFuture;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _loadData() {
    final catalogService = ref.read(catalogServiceProvider);
    setState(() {
      _equipmentFuture = catalogService.getEquipment();
      _servicesFuture = catalogService.getServices();
      _materialsFuture = catalogService.getMaterials();
    });
  }

  void _addItem(OrderItem item) {
    setState(() {
      _selectedItems.add(item);
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${item.nameSnapshot} добавлен'), duration: const Duration(seconds: 1)),
    );
  }

  void _removeItem(int index) {
    setState(() {
      _selectedItems.removeAt(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        height: MediaQuery.of(context).size.height * 0.8,
        child: Column(
          children: [
            AppBar(
              title: const Text('Выбор номенклатуры'),
              bottom: TabBar(
                controller: _tabController,
                tabs: const [
                  Tab(text: 'Техника'),
                  Tab(text: 'Услуги'),
                  Tab(text: 'Материалы'),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildEquipmentTab(),
                  _buildServicesTab(),
                  _buildMaterialsTab(),
                ],
              ),
            ),
            if (_selectedItems.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  border: Border(top: BorderSide(color: Colors.grey[300]!)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Выбрано: ${_selectedItems.length}',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 4),
                    SizedBox(
                      height: 100,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: _selectedItems.length,
                        itemBuilder: (context, index) {
                          final item = _selectedItems[index];
                          return Chip(
                            label: Text('${item.nameSnapshot} (${item.quantity} ${item.unit})'),
                            onDeleted: () => _removeItem(index),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Отмена'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _selectedItems.isEmpty
                        ? null
                        : () => Navigator.pop(context, _selectedItems),
                    child: const Text('Добавить'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEquipmentTab() {
    if (_equipmentFuture == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return FutureBuilder<List<Equipment>>(
      future: _equipmentFuture,
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
                '${item.code} • ${item.hourlyRate} ₽/час${item.dailyRate != null ? ', ${item.dailyRate} ₽/смена' : ''}',
              ),
              trailing: ElevatedButton(
                onPressed: () => _showEquipmentShiftsHoursDialog(item),
                child: const Text('Добавить'),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildServicesTab() {
    if (_servicesFuture == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return FutureBuilder<List<ServiceItem>>(
      future: _servicesFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Ошибка: ${snapshot.error}'));
        }
        final services = snapshot.data ?? [];
        if (services.isEmpty) {
          return const Center(child: Text('Услуги не найдены'));
        }
        return ListView.builder(
          itemCount: services.length,
          itemBuilder: (context, index) {
            final item = services[index];
            return ListTile(
              title: Text(item.name),
              subtitle: Text('${item.price} ₽/${item.unit}'),
              trailing: ElevatedButton(
                onPressed: () => _showQuantityDialog(
                  item.name,
                  OrderItemType.service,
                  item.id,
                  item.price,
                  item.unit,
                ),
                child: const Text('Добавить'),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildMaterialsTab() {
    if (_materialsFuture == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return FutureBuilder<List<MaterialItem>>(
      future: _materialsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Ошибка: ${snapshot.error}'));
        }
        final materials = snapshot.data ?? [];
        if (materials.isEmpty) {
          return const Center(child: Text('Материалы не найдены'));
        }
        return ListView.builder(
          itemCount: materials.length,
          itemBuilder: (context, index) {
            final item = materials[index];
            return ListTile(
              title: Text(item.name),
              subtitle: Text('${item.price} ₽/${item.unit}'),
              trailing: ElevatedButton(
                onPressed: () => _showQuantityDialog(
                  item.name,
                  OrderItemType.material,
                  item.id,
                  item.price,
                  item.unit,
                ),
                child: const Text('Добавить'),
              ),
            );
          },
        );
      },
    );
  }

  void _showEquipmentShiftsHoursDialog(Equipment equipment) async {
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
          ElevatedButton(
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
      
      // Рассчитываем общее количество для quantity (смены * 8 + часы)
      final totalQuantity = shifts * 8 + hours;
      
      // Создаем metadata с информацией о сменах, часах и расходах
      final metadata = <String, dynamic>{
        'shifts': shifts,
        'hours': hours,
        if (equipment.dailyRate != null) 'daily_rate': equipment.dailyRate,
      };
      
      final item = OrderItem(
        itemType: OrderItemType.equipment,
        refId: equipment.id,
        nameSnapshot: equipment.name,
        quantity: totalQuantity,
        unit: 'час',
        unitPrice: equipment.hourlyRate,
        taxRate: 0.0,
        discount: 0.0,
        fuelExpense: fuelExpense,
        repairExpense: repairExpense,
        metadata: metadata,
      );
      
      _addItem(item);
    }
  }

  void _showQuantityDialog(String name, OrderItemType type, int refId, double unitPrice, String unit) {
    final quantityController = TextEditingController(text: '1');
    final discountController = TextEditingController(text: '0');
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Добавить: $name'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: quantityController,
              decoration: InputDecoration(
                labelText: 'Количество ($unit)',
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}'))],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: discountController,
              decoration: const InputDecoration(
                labelText: 'Скидка (%)',
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}'))],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            onPressed: () {
              final quantity = double.tryParse(quantityController.text) ?? 1.0;
              final discount = double.tryParse(discountController.text) ?? 0.0;
              
              final item = OrderItem(
                itemType: type,
                refId: refId,
                nameSnapshot: name,
                quantity: quantity,
                unit: unit,
                unitPrice: unitPrice,
                taxRate: 0.0,
                discount: discount,
                metadata: {},
              );
              
              Navigator.pop(context);
              _addItem(item);
            },
            child: const Text('Добавить'),
          ),
        ],
      ),
    );
  }
}


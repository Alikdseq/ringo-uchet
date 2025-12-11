import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/order_models.dart';
import '../services/order_service.dart';
import '../widgets/nomenclature_selection_dialog.dart';
import '../../auth/services/user_service.dart';
import '../../../shared/models/user.dart';

/// Экран редактирования заявки (только для админа)
class OrderEditScreen extends ConsumerStatefulWidget {
  final String orderId;

  const OrderEditScreen({
    super.key,
    required this.orderId,
  });

  @override
  ConsumerState<OrderEditScreen> createState() => _OrderEditScreenState();
}

class _OrderEditScreenState extends ConsumerState<OrderEditScreen> {
  final _formKey = GlobalKey<FormState>();
  final _scrollController = ScrollController();
  final _totalAmountController = TextEditingController();
  
  Order? _order;
  bool _isLoading = false;
  bool _isSaving = false;
  
  List<OrderItem> _selectedItems = [];
  List<UserInfo> _operators = [];
  Set<int> _selectedOperatorIds = {};
  bool _isLoadingOperators = false;

  @override
  void initState() {
    super.initState();
    _loadOrder();
    _loadOperators();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _totalAmountController.dispose();
    super.dispose();
  }

  Future<void> _loadOrder() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final orderService = ref.read(orderServiceProvider);
      final order = await orderService.getOrder(widget.orderId);
      setState(() {
        _order = order;
        _selectedItems = order.items?.toList() ?? [];
        _selectedOperatorIds = order.operatorIds?.toSet() ?? {};
        _totalAmountController.text = order.totalAmount.toStringAsFixed(2);
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка загрузки заявки: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Редактирование заявки'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _order == null
              ? const Center(child: Text('Заявка не найдена'))
              : Form(
                  key: _formKey,
                  child: ListView(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    children: [
                      // Информация о заявке
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Заявка №${_order!.number}',
                                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                              ),
                              const SizedBox(height: 8),
                              Text('Статус: ${_getStatusLabel(_order!.status)}'),
                              Text('Клиент: ${_order!.client?.name ?? "Не указан"}'),
                              Text('Адрес: ${_order!.address}'),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Раздел: Номенклатура
                      _buildSectionHeader('Номенклатура'),
                      const SizedBox(height: 8),
                      _buildNomenclatureSelection(),
                      const SizedBox(height: 24),

                      // Раздел: Примерная стоимость
                      _buildSectionHeader('Стоимость'),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _totalAmountController,
                        decoration: const InputDecoration(
                          labelText: 'Стоимость (₽)',
                          hintText: 'Введите стоимость',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}'))],
                      ),
                      const SizedBox(height: 24),

                      // Раздел: Операторы
                      _buildSectionHeader('Операторы'),
                      const SizedBox(height: 8),
                      if (_isLoadingOperators)
                        const Center(child: CircularProgressIndicator())
                      else if (_operators.isNotEmpty)
                        Card(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.all(16),
                                child: Text(
                                  'Выберите операторов (можно несколько)',
                                  style: Theme.of(context).textTheme.titleMedium,
                                ),
                              ),
                              ..._operators.map((operator) {
                                final isSelected = _selectedOperatorIds.contains(operator.id);
                                return CheckboxListTile(
                                  title: Text(operator.fullName),
                                  subtitle: operator.phone != null ? Text(operator.phone!) : null,
                                  value: isSelected,
                                  onChanged: (value) {
                                    setState(() {
                                      if (value == true) {
                                        _selectedOperatorIds.add(operator.id);
                                      } else {
                                        _selectedOperatorIds.remove(operator.id);
                                      }
                                    });
                                  },
                                );
                              }).toList(),
                            ],
                          ),
                        )
                      else
                        const Text('Операторы не найдены'),
                      const SizedBox(height: 32),

                      // Кнопка сохранения
                      ElevatedButton(
                        onPressed: _isSaving ? null : _saveOrder,
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
                            : const Text('Сохранить изменения'),
                      ),
                      const SizedBox(height: 16),
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

  Widget _buildNomenclatureSelection() {
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Выбранная номенклатура',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                ElevatedButton.icon(
                  onPressed: _showNomenclatureDialog,
                  icon: const Icon(Icons.add),
                  label: const Text('Добавить'),
                ),
              ],
            ),
          ),
          if (_selectedItems.isEmpty)
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
            ..._selectedItems.asMap().entries.map((entry) {
              final index = entry.key;
              final item = entry.value;
              return ListTile(
                title: Text(item.nameSnapshot),
                subtitle: Text(
                  '${item.quantity} ${item.unit} × ${item.unitPrice.toStringAsFixed(2)} ₽ = ${((item.quantity * item.unitPrice) * (1 - item.discount / 100)).toStringAsFixed(2)} ₽',
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () {
                    setState(() {
                      _selectedItems.removeAt(index);
                    });
                  },
                ),
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
        _selectedItems.addAll(result);
      });
    }
  }

  Future<void> _saveOrder() async {
    if (_order == null) return;

    setState(() {
      _isSaving = true;
    });

    try {
      final orderService = ref.read(orderServiceProvider);

      // Получаем стоимость если указана
      double? totalAmount;
      if (_totalAmountController.text.isNotEmpty) {
        totalAmount = double.tryParse(_totalAmountController.text.trim());
      }

      final request = OrderRequest(
        address: _order!.address, // Сохраняем текущий адрес
        startDt: _order!.startDt, // Сохраняем текущую дату начала
        endDt: _order!.endDt, // Сохраняем текущую дату окончания
        description: _order!.description, // Сохраняем текущее описание
        status: _order!.status, // Сохраняем текущий статус
        operatorIds: _selectedOperatorIds.isNotEmpty ? _selectedOperatorIds.toList() : null,
        items: _selectedItems.isNotEmpty ? _selectedItems : null,
        totalAmount: totalAmount,
      );

      await orderService.updateOrder(widget.orderId, request);

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Заявка обновлена')),
        );
      }
    } catch (e) {
      if (mounted) {
        String errorMessage = 'Ошибка при обновлении заявки';
        if (e.toString().contains('400')) {
          errorMessage = 'Ошибка валидации данных. Проверьте заполненные поля.';
        } else if (e.toString().contains('401')) {
          errorMessage = 'Требуется авторизация. Войдите в систему заново.';
        } else if (e.toString().contains('403')) {
          errorMessage = 'Недостаточно прав для редактирования заявки.';
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
        return 'Удалён';
    }
  }
}


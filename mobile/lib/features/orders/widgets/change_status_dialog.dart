import 'package:flutter/material.dart';
import '../models/order_models.dart';

/// Диалог смены статуса заказа
class ChangeStatusDialog extends StatefulWidget {
  final OrderStatus currentStatus;
  final OrderStatus newStatus;

  const ChangeStatusDialog({
    super.key,
    required this.currentStatus,
    required this.newStatus,
  });

  @override
  State<ChangeStatusDialog> createState() => _ChangeStatusDialogState();
}

class _ChangeStatusDialogState extends State<ChangeStatusDialog> {
  final _commentController = TextEditingController();
  final _operatorSalaryController = TextEditingController();
  final _fuelExpenseController = TextEditingController();

  @override
  void dispose() {
    _commentController.dispose();
    _operatorSalaryController.dispose();
    _fuelExpenseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Изменить статус на: ${_getStatusLabel(widget.newStatus)}'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _commentController,
              decoration: const InputDecoration(
                labelText: 'Комментарий',
                hintText: 'Введите комментарий к изменению статуса',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
            // Поля для завершения заявки
            if (widget.newStatus == OrderStatus.completed) ...[
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 8),
              Text(
                'Финансовые данные',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _operatorSalaryController,
                decoration: const InputDecoration(
                  labelText: 'Зарплата оператору (₽)',
                  hintText: '0.00',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person),
                ),
                keyboardType: TextInputType.numberWithOptions(decimal: true),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _fuelExpenseController,
                decoration: const InputDecoration(
                  labelText: 'Расходы на топливо (₽)',
                  hintText: '0.00',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.local_gas_station),
                ),
                keyboardType: TextInputType.numberWithOptions(decimal: true),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Отмена'),
        ),
        ElevatedButton(
          onPressed: () {
            // Парсим финансовые данные
            double? operatorSalary;
            double? fuelExpense;
            
            if (widget.newStatus == OrderStatus.completed) {
              if (_operatorSalaryController.text.isNotEmpty) {
                operatorSalary = double.tryParse(_operatorSalaryController.text.replaceAll(',', '.'));
              }
              if (_fuelExpenseController.text.isNotEmpty) {
                fuelExpense = double.tryParse(_fuelExpenseController.text.replaceAll(',', '.'));
              }
            }
            
            Navigator.pop(
              context,
              OrderStatusRequest(
                status: widget.newStatus,
                comment: _commentController.text,
                operatorSalary: operatorSalary,
                fuelExpense: fuelExpense,
              ),
            );
          },
          child: const Text('Изменить'),
        ),
      ],
    );
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
      case OrderStatus.deleted:
        return 'Удалён';
    }
  }
}


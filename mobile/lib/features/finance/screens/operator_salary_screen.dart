import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/network/dio_client.dart';

/// Экран отчетов по зарплате для оператора
class OperatorSalaryScreen extends ConsumerStatefulWidget {
  const OperatorSalaryScreen({super.key});

  @override
  ConsumerState<OperatorSalaryScreen> createState() => _OperatorSalaryScreenState();
}

class _OperatorSalaryScreenState extends ConsumerState<OperatorSalaryScreen> {
  DateTimeRange? _selectedPeriod;
  List<_OperatorOrderSalary> _orders = [];
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadSalaryData();
  }

  Future<void> _loadSalaryData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Получаем данные с backend /users/operator/salary/
      final dio = ref.read(dioClientProvider);
      final response = await dio.get('/users/operator/salary/');
      final data = response.data as Map<String, dynamic>;

      final ordersJson = (data['orders'] as List?) ?? [];
      var orders = ordersJson
          .map((e) => _OperatorOrderSalary.fromJson(e as Map<String, dynamic>))
          .toList();

      // Фильтр по периоду по дате создания записи зарплаты / заказа
      if (_selectedPeriod != null) {
        orders = orders.where((order) {
          final dt = order.createdAt;
          return dt.isAfter(_selectedPeriod!.start.subtract(const Duration(milliseconds: 1))) &&
                 dt.isBefore(_selectedPeriod!.end.add(const Duration(days: 1)));
        }).toList();
      }

      // Сортируем по дате (новые первыми)
      orders.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      setState(() {
        _orders = orders;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _selectPeriod(BuildContext context) async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: _selectedPeriod,
      locale: const Locale('ru', 'RU'),
    );
    if (picked != null) {
      setState(() {
        _selectedPeriod = picked;
      });
      _loadSalaryData();
    }
  }

  double _calculateTotalSalary() {
    double total = 0.0;
    for (var order in _orders) {
      total += order.salaryAmount;
    }
    return total;
  }

  double _getOrderSalary(_OperatorOrderSalary order) {
    return order.salaryAmount;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Мои зарплаты'),
      ),
      body: Column(
        children: [
          // Фильтр по периоду
          Card(
            margin: const EdgeInsets.all(8),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      decoration: InputDecoration(
                        labelText: 'Период',
                        hintText: 'Все данные',
                        suffixIcon: const Icon(Icons.calendar_today),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      readOnly: true,
                      controller: TextEditingController(
                        text: _selectedPeriod != null
                            ? '${DateFormat('dd.MM.yyyy').format(_selectedPeriod!.start)} - ${DateFormat('dd.MM.yyyy').format(_selectedPeriod!.end)}'
                            : 'Все данные',
                      ),
                      onTap: () => _selectPeriod(context),
                    ),
                  ),
                  if (_selectedPeriod != null)
                    IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        setState(() {
                          _selectedPeriod = null;
                        });
                        _loadSalaryData();
                      },
                      tooltip: 'Очистить период',
                    ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.refresh),
                    onPressed: _loadSalaryData,
                    tooltip: 'Обновить',
                  ),
                ],
              ),
            ),
          ),
          // Итоговая сумма
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: Colors.green.shade50,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Итого заработано:',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  Text(
                    NumberFormat.currency(
                      locale: 'ru_RU',
                      symbol: '₽',
                      decimalDigits: 2,
                    ).format(_calculateTotalSalary()),
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.green.shade700,
                        ),
                  ),
                ],
              ),
            ),
          ),
          // Список заказов с зарплатами
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text('Ошибка: $_error'),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: _loadSalaryData,
                              child: const Text('Повторить'),
                            ),
                          ],
                        ),
                      )
                    : _orders.isEmpty
                        ? const Center(child: Text('Нет данных'))
                        : RefreshIndicator(
                            onRefresh: _loadSalaryData,
                            child: ListView.builder(
                              padding: const EdgeInsets.all(8),
                              itemCount: _orders.length,
                              itemBuilder: (context, index) {
                                final order = _orders[index];
                                final salary = _getOrderSalary(order);
                                return Card(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  child: ListTile(
                                    title: Text('Заказ ${order.number}'),
                                    subtitle: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const SizedBox(height: 4),
                                        Text('Дата: ${DateFormat('dd.MM.yyyy').format(order.createdAt)}'),
                                        if (order.clientName != null)
                                          Text('Клиент: ${order.clientName}'),
                                        Text('Адрес: ${order.address}'),
                                      ],
                                    ),
                                    trailing: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          NumberFormat.currency(
                                            locale: 'ru_RU',
                                            symbol: '₽',
                                            decimalDigits: 2,
                                          ).format(salary),
                                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                                fontWeight: FontWeight.bold,
                                                color: Colors.orange.shade700,
                                              ),
                                        ),
                                        Text(
                                          'Зарплата',
                                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                                color: Colors.grey,
                                              ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
          ),
        ],
      ),
    );
  }
}

/// Локальная модель для зарплаты оператора по заказу,
/// основана на ответе backend /users/operator/salary/
class _OperatorOrderSalary {
  final String id;
  final String number;
  final String? clientName;
  final String status;
  final double totalAmount;
  final double salaryAmount;
  final DateTime createdAt;
  final DateTime? startDt;
  final DateTime? endDt;
  final String address;

  _OperatorOrderSalary({
    required this.id,
    required this.number,
    required this.clientName,
    required this.status,
    required this.totalAmount,
    required this.salaryAmount,
    required this.createdAt,
    required this.startDt,
    required this.endDt,
    required this.address,
  });

  factory _OperatorOrderSalary.fromJson(Map<String, dynamic> json) {
    final salary = json['salary'] as Map<String, dynamic>?;
    return _OperatorOrderSalary(
      id: json['id']?.toString() ?? '',
      number: json['number'] as String? ?? '',
      clientName: json['client_name'] as String?,
      status: json['status'] as String? ?? '',
      totalAmount: double.tryParse(json['total_amount']?.toString() ?? '0') ?? 0.0,
      salaryAmount: salary != null
          ? double.tryParse(salary['amount']?.toString() ?? '0') ?? 0.0
          : 0.0,
      createdAt: DateTime.parse(json['start_dt'] as String? ?? json['created_at'] as String? ?? DateTime.now().toIso8601String()),
      startDt: json['start_dt'] != null ? DateTime.parse(json['start_dt']) : null,
      endDt: json['end_dt'] != null ? DateTime.parse(json['end_dt']) : null,
      address: json['address'] as String? ?? '',
    );
  }
}


import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../services/finance_service.dart';

/// Экран отчётов
class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  DateTimeRange? _selectedPeriod;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    // По умолчанию период не выбран - показываем все данные
    _selectedPeriod = null;
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          // Табы
          Container(
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              border: Border(
                bottom: BorderSide(
                  color: Colors.grey.shade300,
                  width: 1,
                ),
              ),
            ),
            child: TabBar(
              controller: _tabController,
              indicator: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: Theme.of(context).primaryColor,
                    width: 3,
                  ),
                ),
              ),
              labelColor: Theme.of(context).primaryColor,
              unselectedLabelColor: Colors.grey,
              labelStyle: const TextStyle(fontWeight: FontWeight.bold),
              tabs: const [
                Tab(text: 'Общие'),
                Tab(text: 'По технике'),
                Tab(text: 'По сотрудникам'),
              ],
            ),
          ),
          // Фильтры
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
                      },
                      tooltip: 'Очистить период',
                    ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.refresh),
                    onPressed: () => setState(() {}),
                    tooltip: 'Обновить',
                  ),
                ],
              ),
            ),
          ),
          // Контент
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _SummaryReportTab(
                  period: _selectedPeriod,
                  key: ValueKey(_selectedPeriod?.toString()),
                ),
                _EquipmentReportTab(
                  period: _selectedPeriod,
                  key: ValueKey(_selectedPeriod?.toString()),
                ),
                _EmployeeReportTab(
                  period: _selectedPeriod,
                  key: ValueKey(_selectedPeriod?.toString()),
                ),
              ],
            ),
          ),
        ],
      ),
    );
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
    }
  }
}

/// Вкладка общих отчетов
class _SummaryReportTab extends ConsumerStatefulWidget {
  final DateTimeRange? period;

  const _SummaryReportTab({
    super.key,
    required this.period,
  });

  @override
  ConsumerState<_SummaryReportTab> createState() => _SummaryReportTabState();
}

class _SummaryReportTabState extends ConsumerState<_SummaryReportTab> {
  SummaryReport? _report;
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadReport();
  }

  @override
  void didUpdateWidget(_SummaryReportTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.period != widget.period) {
      _loadReport();
    }
  }

  Future<void> _loadReport() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final financeService = ref.read(financeServiceProvider);
      final report = await financeService.getSummaryReport(
        dateFrom: widget.period?.start,
        dateTo: widget.period?.end,
      );
      setState(() {
        _report = report;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Ошибка: $_error'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadReport,
              child: const Text('Повторить'),
            ),
          ],
        ),
      );
    }

    if (_report == null) {
      return const Center(child: Text('Нет данных'));
    }

    final report = _report!;
    final daysCount = widget.period != null
        ? widget.period!.end.difference(widget.period!.start).inDays + 1
        : 1;
    final avgRevenuePerDay = daysCount > 0 ? report.revenue / daysCount : 0.0;
    final avgExpensesPerDay = daysCount > 0 ? (report.expenses + report.salaries) / daysCount : 0.0;

    return RefreshIndicator(
      onRefresh: _loadReport,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Доходы
          Card(
            color: Colors.green.shade50,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.trending_up, color: Colors.green.shade700),
                      const SizedBox(width: 8),
                      Text(
                        'Доходы',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Colors.green.shade700,
                            ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildStatRow(
                    context,
                    'Общая выручка',
                    report.revenue,
                    Colors.green.shade700,
                  ),
                  const SizedBox(height: 12),
                  _buildStatRow(
                    context,
                    '  • С услуг',
                    report.revenueFromServices,
                    Colors.green.shade600,
                    isSmall: true,
                  ),
                  const SizedBox(height: 8),
                  _buildStatRow(
                    context,
                    '  • С техники',
                    report.revenueFromEquipment,
                    Colors.green.shade600,
                    isSmall: true,
                  ),
                  const SizedBox(height: 8),
                  _buildStatRow(
                    context,
                    'Среднее в день',
                    avgRevenuePerDay,
                    Colors.green.shade600,
                    isSmall: true,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Расходы
          Card(
            color: Colors.red.shade50,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.trending_down, color: Colors.red.shade700),
                      const SizedBox(width: 8),
                      Text(
                        'Расходы',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Colors.red.shade700,
                            ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildStatRow(
                    context,
                    'Расходы на технику и материалы',
                    report.expenses,
                    Colors.red.shade700,
                  ),
                  const SizedBox(height: 8),
                  if (report.expensesFuel > 0)
                    _buildStatRow(
                      context,
                      '  • Расходы на топливо',
                      report.expensesFuel,
                      Colors.red.shade600,
                      isSmall: true,
                    ),
                  if (report.expensesFuel > 0) const SizedBox(height: 4),
                  if (report.expensesRepair > 0)
                    _buildStatRow(
                      context,
                      '  • Расходы на ремонт техники',
                      report.expensesRepair,
                      Colors.red.shade600,
                      isSmall: true,
                    ),
                  if (report.expensesRepair > 0) const SizedBox(height: 8),
                  _buildStatRow(
                    context,
                    'Зарплаты сотрудникам',
                    report.salaries,
                    Colors.red.shade700,
                  ),
                  const SizedBox(height: 8),
                  _buildStatRow(
                    context,
                    'Всего расходов',
                    report.expenses + report.salaries,
                    Colors.red.shade800,
                    isBold: true,
                  ),
                  const SizedBox(height: 8),
                  _buildStatRow(
                    context,
                    'Среднее в день',
                    avgExpensesPerDay,
                    Colors.red.shade600,
                    isSmall: true,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Итоги
          Card(
            color: Colors.blue.shade50,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.account_balance, color: Colors.blue.shade700),
                      const SizedBox(width: 8),
                      Text(
                        'Итоги',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Colors.blue.shade700,
                            ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildStatRow(
                    context,
                    'Маржа (прибыль)',
                    report.margin,
                    report.margin >= 0 ? Colors.green.shade700 : Colors.red.shade700,
                    isBold: true,
                  ),
                  const SizedBox(height: 8),
                  _buildStatRow(
                    context,
                    'Количество заказов',
                    report.ordersCount.toDouble(),
                    Colors.blue.shade700,
                    isCount: true,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatRow(
    BuildContext context,
    String label,
    double value,
    Color color, {
    bool isBold = false,
    bool isSmall = false,
    bool isCount = false,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: isSmall ? 14 : 16,
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        Text(
          isCount
              ? value.toInt().toString()
              : '${NumberFormat.currency(locale: 'ru_RU', symbol: '₽', decimalDigits: 2).format(value)}',
          style: TextStyle(
            fontSize: isSmall ? 14 : 16,
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            color: color,
          ),
        ),
      ],
    );
  }
}

/// Вкладка отчетов по технике
class _EquipmentReportTab extends ConsumerStatefulWidget {
  final DateTimeRange? period;

  const _EquipmentReportTab({
    super.key,
    required this.period,
  });

  @override
  ConsumerState<_EquipmentReportTab> createState() => _EquipmentReportTabState();
}

class _EquipmentReportTabState extends ConsumerState<_EquipmentReportTab> {
  List<EquipmentReportItem> _equipment = [];
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadReport();
  }

  @override
  void didUpdateWidget(_EquipmentReportTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.period != widget.period) {
      _loadReport();
    }
  }

  Future<void> _loadReport() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final financeService = ref.read(financeServiceProvider);
      final equipment = await financeService.getEquipmentReport(
        dateFrom: widget.period?.start,
        dateTo: widget.period?.end,
      );
      setState(() {
        _equipment = equipment;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Ошибка: $_error'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadReport,
              child: const Text('Повторить'),
            ),
          ],
        ),
      );
    }

    if (_equipment.isEmpty) {
      return const Center(child: Text('Нет данных по технике'));
    }

    return RefreshIndicator(
      onRefresh: _loadReport,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ..._equipment.map((item) => Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ExpansionTile(
                  leading: const Icon(Icons.construction),
                  title: Text(item.equipmentName),
                  subtitle: Text('Код: ${item.code}'),
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildEquipmentStatRow(
                            context,
                            'Статус',
                            item.status,
                            Colors.grey,
                          ),
                          const Divider(),
                          _buildEquipmentStatRow(
                            context,
                            'Доходы',
                            NumberFormat.currency(
                              locale: 'ru_RU',
                              symbol: '₽',
                              decimalDigits: 2,
                            ).format(item.revenue),
                            Colors.green,
                            isBold: true,
                          ),
                          const SizedBox(height: 8),
                          _buildEquipmentStatRow(
                            context,
                            'Расходы',
                            NumberFormat.currency(
                              locale: 'ru_RU',
                              symbol: '₽',
                              decimalDigits: 2,
                            ).format(item.expenses),
                            Colors.red,
                            isBold: true,
                          ),
                          if (item.fuelExpenses > 0) ...[
                            const SizedBox(height: 4),
                            _buildEquipmentStatRow(
                              context,
                              '  • Расходы на топливо',
                              NumberFormat.currency(
                                locale: 'ru_RU',
                                symbol: '₽',
                                decimalDigits: 2,
                              ).format(item.fuelExpenses),
                              Colors.orange,
                            ),
                          ],
                          if (item.repairExpenses > 0) ...[
                            const SizedBox(height: 4),
                            _buildEquipmentStatRow(
                              context,
                              '  • Расходы на ремонт',
                              NumberFormat.currency(
                                locale: 'ru_RU',
                                symbol: '₽',
                                decimalDigits: 2,
                              ).format(item.repairExpenses),
                              Colors.red.shade600,
                            ),
                          ],
                          const Divider(),
                          _buildEquipmentStatRow(
                            context,
                            'Прибыль',
                            NumberFormat.currency(
                              locale: 'ru_RU',
                              symbol: '₽',
                              decimalDigits: 2,
                            ).format(item.revenue - item.expenses),
                            item.revenue - item.expenses >= 0
                                ? Colors.green
                                : Colors.red,
                            isBold: true,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  Widget _buildEquipmentStatRow(
    BuildContext context,
    String label,
    String value,
    Color color, {
    bool isBold = false,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            color: color,
          ),
        ),
      ],
    );
  }
}

/// Вкладка отчетов по сотрудникам
class _EmployeeReportTab extends ConsumerStatefulWidget {
  final DateTimeRange? period;

  const _EmployeeReportTab({
    super.key,
    required this.period,
  });

  @override
  ConsumerState<_EmployeeReportTab> createState() => _EmployeeReportTabState();
}

class _EmployeeReportTabState extends ConsumerState<_EmployeeReportTab> {
  List<EmployeeReportItem> _employees = [];
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadReport();
  }

  @override
  void didUpdateWidget(_EmployeeReportTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.period != widget.period) {
      _loadReport();
    }
  }

  Future<void> _loadReport() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final financeService = ref.read(financeServiceProvider);
      final employees = await financeService.getEmployeesReport(
        dateFrom: widget.period?.start,
        dateTo: widget.period?.end,
      );
      setState(() {
        _employees = employees;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Ошибка: $_error'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadReport,
              child: const Text('Повторить'),
            ),
          ],
        ),
      );
    }

    if (_employees.isEmpty) {
      return const Center(child: Text('Нет данных по сотрудникам'));
    }

    return RefreshIndicator(
      onRefresh: _loadReport,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ..._employees.map((item) => Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: CircleAvatar(
                    child: Text(item.fullName[0].toUpperCase()),
                  ),
                  title: Text(item.fullName),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),
                      Text('Заказов: ${item.assignments}'),
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
                        ).format(item.totalAmount),
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
              )),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/status_colors.dart';
import '../../../core/offline/cache_service.dart';
import '../../../core/providers/navigation_provider.dart';
import '../../auth/providers/auth_providers.dart';
import '../models/order_models.dart';
import '../services/order_service.dart';
import 'create_order_screen.dart';

/// Экран Dashboard с KPI
class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  bool _isLoading = true;
  int _newOrdersCount = 0;
  int _assignedOrdersCount = 0;
  double _profit = 0.0;
  List<Order> _allOrders = [];

  @override
  void initState() {
    super.initState();
    _loadKPIData();
  }

  Future<void> _loadKPIData({bool useCache = true}) async {
    setState(() {
      _isLoading = true;
    });

    try {
      final orderService = ref.read(orderServiceProvider);
      
      // ОПТИМИЗАЦИЯ: Сначала загружаем из кэша для мгновенного отображения
      if (useCache) {
        try {
          final cacheService = ref.read(cacheServiceProvider);
          final cachedOrders = await cacheService.getCachedOrders();
          if (cachedOrders != null && cachedOrders.isNotEmpty) {
            final orders = cachedOrders
                .map((json) => Order.fromJson(json as Map<String, dynamic>))
                .toList();
            
            // Вычисляем KPI из кэша
            final newOrders = orders.where((o) => 
              o.status == OrderStatus.created || o.status == OrderStatus.approved
            ).length;
            final assignedOrders = orders.where((o) => o.status == OrderStatus.inProgress).length;
            final profit = orders
                .where((o) => o.status == OrderStatus.completed)
                .fold(0.0, (sum, o) => sum + o.totalAmount);

            // Показываем кэшированные данные МГНОВЕННО
            setState(() {
              _newOrdersCount = newOrders;
              _assignedOrdersCount = assignedOrders;
              _profit = profit;
              _allOrders = orders;
              _isLoading = false; // UI готов, данные из кэша
            });
          }
        } catch (e) {
          // Если кэш недоступен, продолжаем загрузку с сервера
        }
      }
      
      // Затем в ФОНЕ обновляем данные с сервера
      try {
        final allOrders = await orderService.getOrders(useCache: true);
        // Новые заявки = CREATED + APPROVED (созданные и подтвержденные)
        final newOrders = allOrders.where((o) => 
          o.status == OrderStatus.created || o.status == OrderStatus.approved
        ).length;
        final assignedOrders = allOrders.where((o) => o.status == OrderStatus.inProgress).length;
        final profit = allOrders
            .where((o) => o.status == OrderStatus.completed)
            .fold(0.0, (sum, o) => sum + o.totalAmount);

        setState(() {
          _newOrdersCount = newOrders;
          _assignedOrdersCount = assignedOrders;
          _profit = profit;
          _allOrders = allOrders;
          _isLoading = false;
        });
      } catch (e) {
        // Если обновление не удалось, оставляем данные из кэша
        if (_allOrders.isEmpty) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          // Кнопка обновления
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: _loadKPIData,
                ),
              ],
            ),
          ),
          // Контент
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: _loadKPIData,
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // KPI карточки
                          _buildKPICards(),
                          const SizedBox(height: 24),

                          // Мини-графики (заглушка)
                          _buildMiniCharts(),
                          const SizedBox(height: 24),

                          // Быстрые действия
                          _buildQuickActions(),
                        ],
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildKPICards() {
    final authState = ref.watch(authStateProvider);
    final user = authState.user;
    final isAdmin = user?.role == 'admin';
    final navigationNotifier = ref.read(navigationIndexProvider.notifier);
    
    return Row(
      children: [
        Expanded(
          child: _KPICard(
            title: 'Новые заявки',
            value: _newOrdersCount.toString(),
            icon: Icons.add_circle,
            color: StatusColors.created,
            onTap: () {
              // Переключаемся на экран заявок через нижнюю панель
              navigationNotifier.navigateToOrders();
            },
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _KPICard(
            title: 'Назначенные',
            value: _assignedOrdersCount.toString(),
            icon: Icons.assignment,
            color: StatusColors.inProgress,
            onTap: () {
              // Переключаемся на экран заявок через нижнюю панель
              navigationNotifier.navigateToOrders();
            },
          ),
        ),
        if (isAdmin) ...[
          const SizedBox(width: 12),
          Expanded(
            child: _KPICard(
              title: 'Доход',
              value: '${_profit.toStringAsFixed(0)} ₽',
              icon: Icons.attach_money,
              color: StatusColors.completed,
              onTap: () {
                // Переключаемся на экран отчетов через нижнюю панель
                navigationNotifier.setIndex(3); // Индекс экрана отчетов для админа
              },
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildMiniCharts() {
    // Получаем данные для графика за последние 7 дней
    final now = DateTime.now();
    final last7Days = List.generate(7, (index) {
      final date = now.subtract(Duration(days: 6 - index));
      return date;
    });
    
    // Подсчитываем заявки по дням (по дате создания, а не по startDt)
    final ordersByDay = last7Days.map((date) {
      final startOfDay = DateTime(date.year, date.month, date.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));
      
      return _allOrders.where((order) {
        final orderDate = order.createdAt;
        return orderDate.isAfter(startOfDay.subtract(const Duration(milliseconds: 1))) &&
               orderDate.isBefore(endOfDay);
      }).length;
    }).toList();
    
    // Находим максимальное значение для правильного масштабирования графика
    final maxValue = ordersByDay.isNotEmpty 
        ? ordersByDay.reduce((a, b) => a > b ? a : b)
        : 1;
    final maxValueDouble = maxValue > 0 ? maxValue.toDouble() : 1.0;
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Статистика за последние 7 дней',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            Container(
              height: 200,
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: List.generate(7, (index) {
                    final day = last7Days[index];
                    final dayName = _getDayName(day.weekday);
                    final value = ordersByDay[index].toDouble();
                    final height = maxValueDouble > 0 ? (value / maxValueDouble * 150) : 0.0;
                    
                    return Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Container(
                            width: double.infinity,
                            height: height,
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            decoration: BoxDecoration(
                              color: Theme.of(context).primaryColor.withOpacity(0.7),
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(4),
                              ),
                            ),
                            child: height > 0
                                ? Center(
                                    child: Text(
                                      value.toInt().toString(),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  )
                                : null,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            dayName,
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.info_outline, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Text(
                  'Количество новых заявок по дням',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
  
  String _getDayName(int weekday) {
    const days = ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'];
    return days[weekday - 1];
  }

  Widget _buildQuickActions() {
    final authState = ref.watch(authStateProvider);
    final user = authState.user;
    final role = user?.role ?? 'user';
    final isAdmin = role == 'admin';
    final isOperator = role == 'operator';
    final navigationNotifier = ref.read(navigationIndexProvider.notifier);

    // Для оператора быстрые действия скрываем полностью
    if (isOperator) {
      return const SizedBox.shrink();
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Быстрые действия',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.add),
              title: const Text('Создать заявку'),
              onTap: () async {
                // Открываем экран создания заявки с AppBar и кнопкой назад
                final result = await Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => Scaffold(
                      appBar: AppBar(
                        title: const Text('Создать заявку'),
                      ),
                      body: const CreateOrderScreen(),
                    ),
                  ),
                );
                // Обновляем данные если заявка создана
                if (result == true) {
                  _loadKPIData();
                }
              },
            ),
            if (isAdmin) ...[
              const Divider(),
              ListTile(
                leading: const Icon(Icons.report),
                title: const Text('Отчёты'),
                onTap: () {
                  // Переключаемся на экран отчетов через нижнюю панель
                  navigationNotifier.setIndex(3); // Индекс экрана отчетов для админа
                },
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _KPICard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  const _KPICard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // Определяем размер шрифта в зависимости от длины значения
    final valueLength = value.length;
    double fontSize;
    if (valueLength <= 4) {
      fontSize = 24; // Для небольших чисел (до 4 символов)
    } else if (valueLength <= 6) {
      fontSize = 20; // Для средних чисел (5-6 символов)
    } else if (valueLength <= 8) {
      fontSize = 16; // Для больших чисел (7-8 символов)
    } else {
      fontSize = 14; // Для очень больших чисел (9+ символов)
    }

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(icon, color: color, size: 24),
                  ),
                  Flexible(
                    child: Text(
                      value,
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: color,
                            fontSize: fontSize,
                          ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.end,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.grey[600],
                      fontSize: 14,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}


import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/status_colors.dart';
import '../../../shared/widgets/offline_banner.dart';
import '../../../shared/widgets/offline_queue_indicator.dart';
import '../../../features/auth/providers/auth_providers.dart';
import '../models/order_models.dart';
import '../services/order_service.dart';
import 'order_detail_screen.dart';

/// Экран списка заявок
class OrdersListScreen extends ConsumerStatefulWidget {
  const OrdersListScreen({super.key});

  @override
  ConsumerState<OrdersListScreen> createState() => _OrdersListScreenState();
}

class _OrdersListScreenState extends ConsumerState<OrdersListScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _searchController = TextEditingController();
  List<Order> _allOrders = [];
  bool _isLoading = false;
  String? _error;
  
  // Порядок статусов для табов (без черновика)
  final List<OrderStatus> _statusOrder = [
    OrderStatus.created,
    OrderStatus.approved,
    OrderStatus.inProgress,
    OrderStatus.completed,
    OrderStatus.cancelled,
  ];

  @override
  void initState() {
    super.initState();
    // +1 для вкладки "Все"
    _tabController = TabController(length: _statusOrder.length + 1, vsync: this);
    _loadOrders();
  }

  // Публичный метод для обновления списка извне
  void refreshOrders() {
    _loadOrders();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadOrders() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final orderService = ref.read(orderServiceProvider);
      final authState = ref.read(authStateProvider);
      final user = authState.user;
      
      // Загружаем все заявки без фильтра по статусу
      var orders = await orderService.getOrders(
        search: _searchController.text.isEmpty ? null : _searchController.text,
      );
      
      // Если пользователь - оператор, фильтруем только его заявки
      if (user?.role == 'operator' && user?.id != null) {
        final operatorId = user!.id;
        orders = orders.where((order) {
          final byId = order.operatorId == operatorId;
          final byObject = order.operator != null && order.operator!.id == operatorId;
          return byId || byObject;
        }).toList();
      }
      
      setState(() {
        _allOrders = orders;
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
    return Scaffold(
      body: Column(
        children: [
          // Оффлайн баннер
          const OfflineBanner(),
          // Действия
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                const OfflineQueueIndicator(),
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: _loadOrders,
                ),
              ],
            ),
          ),
          // Поиск
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Поиск по номеру, клиенту, адресу...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          setState(() {
                            _searchController.clear();
                          });
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onChanged: (_) => setState(() {}), // Обновляем UI для фильтрации
              onSubmitted: (_) => _loadOrders(),
            ),
          ),
          // Табы по этапам
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
            child: AnimatedBuilder(
              animation: _tabController,
              builder: (context, child) {
                // Определяем цвет для активной вкладки
                Color currentTabColor;
                if (_tabController.index == 0) {
                  // Вкладка "Все"
                  currentTabColor = Theme.of(context).primaryColor;
                } else {
                  final currentStatus = _statusOrder[_tabController.index - 1];
                  currentTabColor = StatusColors.getOrderStatusColor(
                    currentStatus.toString().split('.').last.toUpperCase(),
                  );
                }
                
                return TabBar(
                  controller: _tabController,
                  isScrollable: true,
                  indicator: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: currentTabColor,
                        width: 3,
                      ),
                    ),
                  ),
                  indicatorSize: TabBarIndicatorSize.tab,
                  labelColor: currentTabColor,
                  labelStyle: const TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                  unselectedLabelStyle: const TextStyle(
                    fontWeight: FontWeight.normal,
                  ),
                  unselectedLabelColor: Colors.grey,
                  tabs: [
                    // Вкладка "Все"
                    Tab(
                      child: AnimatedBuilder(
                        animation: _tabController,
                        builder: (context, child) {
                          final isSelected = _tabController.index == 0;
                          return Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.list,
                                size: 16,
                                color: isSelected ? Theme.of(context).primaryColor : Colors.grey,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Все',
                                style: TextStyle(
                                  color: isSelected ? Theme.of(context).primaryColor : Colors.grey,
                                ),
                              ),
                              if (_allOrders.isNotEmpty) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Theme.of(context).primaryColor.withOpacity(isSelected ? 0.3 : 0.15),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    _allOrders.length.toString(),
                                    style: TextStyle(
                                      color: Theme.of(context).primaryColor,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          );
                        },
                      ),
                    ),
                    // Вкладки по статусам
                    ..._statusOrder.asMap().entries.map((entry) {
                      final index = entry.key + 1; // +1 потому что первая вкладка "Все"
                      final status = entry.value;
                      final statusColor = StatusColors.getOrderStatusColor(
                        status.toString().split('.').last.toUpperCase(),
                      );
                      final ordersCount = _allOrders.where((o) => o.status == status).length;
                      
                      return Tab(
                        child: AnimatedBuilder(
                          animation: _tabController,
                          builder: (context, child) {
                            final isSelected = _tabController.index == index;
                            return Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    color: statusColor,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  _getStatusLabel(status),
                                  style: TextStyle(
                                    color: isSelected ? statusColor : Colors.grey,
                                  ),
                                ),
                                if (ordersCount > 0) ...[
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: statusColor.withOpacity(isSelected ? 0.3 : 0.15),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                      ordersCount.toString(),
                                      style: TextStyle(
                                        color: statusColor,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            );
                          },
                        ),
                      );
                    }).toList(),
                  ],
                );
              },
            ),
          ),
          // Контент табов
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
                              onPressed: _loadOrders,
                              child: const Text('Повторить'),
                            ),
                          ],
                        ),
                      )
                    : TabBarView(
                        controller: _tabController,
                        children: [
                          // Вкладка "Все" с цветными индикаторами
                          _AllOrdersTab(
                            orders: _allOrders,
                            search: _searchController.text,
                            onRefresh: _loadOrders,
                          ),
                          // Вкладки по статусам
                          ..._statusOrder.map((status) {
                            return _OrderStatusTab(
                              status: status,
                              orders: _allOrders,
                              search: _searchController.text,
                              onRefresh: _loadOrders,
                            );
                          }).toList(),
                        ],
                      ),
          ),
        ],
      ),
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
    }
  }
}

/// Вкладка всех заявок с цветами этапов
class _AllOrdersTab extends StatelessWidget {
  final List<Order> orders;
  final String search;
  final VoidCallback onRefresh;

  const _AllOrdersTab({
    required this.orders,
    required this.search,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    // Фильтруем заявки по поисковому запросу
    var filteredOrders = orders;
    
    // Применяем поиск, если есть
    if (search.isNotEmpty) {
      final searchLower = search.toLowerCase();
      filteredOrders = filteredOrders.where((order) {
        return order.number.toLowerCase().contains(searchLower) ||
            order.address.toLowerCase().contains(searchLower) ||
            (order.client != null && order.client!.name.toLowerCase().contains(searchLower));
      }).toList();
    }

    if (filteredOrders.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.inbox,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'Заявки не найдены',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 16,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async => onRefresh(),
      child: ListView.builder(
        itemCount: filteredOrders.length,
        itemBuilder: (context, index) {
          final order = filteredOrders[index];
          return _OrderCard(
            order: order,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => OrderDetailScreen(orderId: order.id),
                ),
              ).then((_) => onRefresh());
            },
          );
        },
      ),
    );
  }
}

/// Вкладка заявок по статусу
class _OrderStatusTab extends StatelessWidget {
  final OrderStatus status;
  final List<Order> orders;
  final String search;
  final VoidCallback onRefresh;

  const _OrderStatusTab({
    required this.status,
    required this.orders,
    required this.search,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    // Фильтруем заявки по статусу и поисковому запросу
    var filteredOrders = orders.where((order) => order.status == status).toList();
    
    // Применяем поиск, если есть
    if (search.isNotEmpty) {
      final searchLower = search.toLowerCase();
      filteredOrders = filteredOrders.where((order) {
        return order.number.toLowerCase().contains(searchLower) ||
            order.address.toLowerCase().contains(searchLower) ||
            (order.client != null && order.client!.name.toLowerCase().contains(searchLower));
      }).toList();
    }

    if (filteredOrders.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.inbox,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'Заявки не найдены',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 16,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async => onRefresh(),
      child: ListView.builder(
        itemCount: filteredOrders.length,
        itemBuilder: (context, index) {
          final order = filteredOrders[index];
          return _OrderCard(
            order: order,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => OrderDetailScreen(orderId: order.id),
                ),
              ).then((_) => onRefresh());
            },
          );
        },
      ),
    );
  }
}

/// Карточка заявки
class _OrderCard extends ConsumerWidget {
  final Order order;
  final VoidCallback onTap;

  const _OrderCard({
    required this.order,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statusColor = StatusColors.getOrderStatusColor(
      order.status.toString().split('.').last.toUpperCase(),
    );
    final authState = ref.watch(authStateProvider);
    final user = authState.user;
    final isOperator = user?.role == 'operator';

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Заказ ${order.number}',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: statusColor),
                    ),
                    child: Text(
                      _getStatusLabel(order.status),
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (order.client != null)
                Text(
                  'Клиент: ${order.client!.name}',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              const SizedBox(height: 4),
              Text(
                order.address,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey[600],
                    ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${_formatDate(order.startDt)} - ${order.endDt != null ? _formatDate(order.endDt!) : "..."}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  if (!isOperator)
                    Text(
                      '${order.totalAmount.toStringAsFixed(2)} ₽',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).primaryColor,
                          ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
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
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}.${date.month}.${date.year}';
  }
}


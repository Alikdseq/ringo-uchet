import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/status_colors.dart';
import '../../../core/offline/cache_service.dart';
import '../../../core/utils/debouncer.dart';
import '../../../shared/widgets/offline_banner.dart';
import '../../../shared/widgets/offline_queue_indicator.dart';
import '../../../features/auth/providers/auth_providers.dart';
import '../models/order_models.dart';
import '../services/order_service.dart';
import 'order_detail_screen.dart';

/// Экран списка заявок
class OrdersListScreen extends ConsumerStatefulWidget {
  final int? refreshKey; // Ключ для принудительного обновления
  
  const OrdersListScreen({super.key, this.refreshKey});

  @override
  ConsumerState<OrdersListScreen> createState() => _OrdersListScreenState();
}

class _OrdersListScreenState extends ConsumerState<OrdersListScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _searchController = TextEditingController();
  final _debouncer = Debouncer(delay: const Duration(milliseconds: 300));
  List<Order> _allOrders = [];
  List<Order> _filteredOrders = []; // Кэшированные отфильтрованные заявки
  bool _isLoading = false;
  String? _error;
  
  // Порядок статусов для табов (без черновика и удаленных)
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
    // Оптимизация: debounce для поиска
    _searchController.addListener(_onSearchChanged);
  }
  
  void _onSearchChanged() {
    // Используем debounce чтобы не фильтровать на каждое нажатие клавиши
    _debouncer.call(() {
      if (mounted) {
        setState(() {
          _updateFilteredOrders();
        });
      }
    });
  }
  
  void _updateFilteredOrders() {
    // Мгновенная фильтрация в памяти (быстро)
    final searchQuery = _searchController.text.toLowerCase();
    if (searchQuery.isEmpty) {
      _filteredOrders = _allOrders;
    } else {
      _filteredOrders = _allOrders.where((order) {
        return order.number.toLowerCase().contains(searchQuery) ||
            order.address.toLowerCase().contains(searchQuery) ||
            (order.client != null && order.client!.name.toLowerCase().contains(searchQuery));
      }).toList();
    }
  }
  
  @override
  void didUpdateWidget(OrdersListScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Если изменился refreshKey, обновляем список
    if (widget.refreshKey != null && widget.refreshKey != oldWidget.refreshKey) {
      // СНАЧАЛА загружаем из кэша для мгновенного отображения новой заявки
      _loadOrdersFromCache();
      // Затем в фоне обновляем с сервера
      _loadOrders(useCache: false);
    }
  }

  /// Мгновенная загрузка заявок из кэша (без индикатора загрузки)
  Future<void> _loadOrdersFromCache() async {
    try {
      final cacheService = ref.read(cacheServiceProvider);
      final cachedOrders = await cacheService.getCachedOrders();
      if (cachedOrders != null && cachedOrders.isNotEmpty) {
        final authState = ref.read(authStateProvider);
        final user = authState.user;
        
        var orders = cachedOrders
            .map((json) => Order.fromJson(json as Map<String, dynamic>))
            .toList();
        
        // Если пользователь - оператор, фильтруем только его заявки
        if (user?.role == 'operator' && user?.id != null) {
          final operatorId = user!.id;
          orders = orders.where((order) {
            final byId = order.operatorId == operatorId;
            final byObject = order.operator != null && order.operator!.id == operatorId;
            return byId || byObject;
          }).toList();
        }
        
        // Мгновенно обновляем UI
        if (mounted) {
          setState(() {
            _allOrders = orders;
          });
        }
      }
    } catch (e) {
      // Игнорируем ошибки кэша, основной список загрузится с сервера
    }
  }

  // Публичный метод для обновления списка извне
  void refreshOrders() {
    _loadOrders();
  }

  @override
  void dispose() {
    _debouncer.dispose();
    _searchController.removeListener(_onSearchChanged);
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadOrders({bool useCache = true}) async {
    // КРИТИЧНО: Сначала загружаем из кэша БЕЗ показа индикатора загрузки
    // Данные из кэша доступны мгновенно, UI не блокируется
    if (useCache) {
      try {
        final cacheService = ref.read(cacheServiceProvider);
        final authState = ref.read(authStateProvider);
        final user = authState.user;
        final cachedOrders = await cacheService.getCachedOrders();
        
        if (cachedOrders != null && cachedOrders.isNotEmpty) {
          var orders = cachedOrders
              .map((json) => Order.fromJson(json as Map<String, dynamic>))
              .toList();
          
          // Если пользователь - оператор, фильтруем только его заявки
          if (user?.role == 'operator' && user?.id != null) {
            final operatorId = user!.id;
            orders = orders.where((order) {
              final byId = order.operatorId == operatorId;
              final byObject = order.operator != null && order.operator!.id == operatorId;
              return byId || byObject;
            }).toList();
          }
          
          // МГНОВЕННО показываем данные из кэша без индикатора загрузки
          if (mounted) {
            setState(() {
              _allOrders = orders;
              _updateFilteredOrders();
              _isLoading = false; // UI готов сразу
              _error = null;
            });
          }
        }
      } catch (e) {
        // Если кэш недоступен, продолжаем загрузку с сервера
      }
    }
    
    // Только если кэша нет или нужно обновление - показываем индикатор и загружаем с сервера
    if (_allOrders.isEmpty || !useCache) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    }

    try {
      final orderService = ref.read(orderServiceProvider);
      final authState = ref.read(authStateProvider);
      final user = authState.user;
      
      // Обновляем данные с сервера в фоне (не блокирует UI если есть кэш)
      var orders = await orderService.getOrders(
        search: _searchController.text.isEmpty ? null : _searchController.text,
        useCache: true,
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
      
      if (mounted) {
        setState(() {
          _allOrders = orders;
          _updateFilteredOrders();
          _isLoading = false;
        });
      }
    } catch (e) {
      // Если обновление не удалось, оставляем данные из кэша (если есть)
      if (mounted) {
        if (_allOrders.isEmpty) {
          setState(() {
            _error = e.toString();
            _isLoading = false;
          });
        } else {
          // Данные из кэша уже показаны, просто скрываем индикатор
          setState(() {
            _isLoading = false;
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.read(authStateProvider); // Используем read вместо watch для избежания перерисовок
    final isOperator = authState.user?.role == 'operator';
    
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
              // Оптимизация: фильтрация происходит через debounce в _onSearchChanged
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
                            orders: _filteredOrders,
                            search: _searchController.text,
                            isOperator: isOperator,
                            onRefresh: _loadOrders,
                          ),
                          // Вкладки по статусам
                          ..._statusOrder.map((status) {
                            return _OrderStatusTab(
                              status: status,
                              orders: _filteredOrders,
                              search: _searchController.text,
                              isOperator: isOperator,
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
/// Оптимизация: поиск уже применен на уровне родителя через _filteredOrders
class _AllOrdersTab extends StatelessWidget {
  final List<Order> orders;
  final String search;
  final bool isOperator;
  final VoidCallback onRefresh;

  const _AllOrdersTab({
    required this.orders,
    required this.search,
    required this.isOperator,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    // Поиск уже применен на уровне родителя через _filteredOrders
    final filteredOrders = orders;

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
          // Оптимизация: используем key для эффективного обновления списка
          return _OrderCard(
            key: ValueKey(order.id), // Ключ для оптимизации перерисовок
            order: order,
            isOperator: isOperator, // Передаем роль
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
/// Оптимизация: поиск уже применен на уровне родителя, фильтруем только по статусу
class _OrderStatusTab extends StatelessWidget {
  final OrderStatus status;
  final List<Order> orders;
  final String search;
  final bool isOperator;
  final VoidCallback onRefresh;

  const _OrderStatusTab({
    required this.status,
    required this.orders,
    required this.search,
    required this.isOperator,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    // Поиск уже применен на уровне родителя, фильтруем только по статусу
    final filteredOrders = orders.where((order) => order.status == status).toList();

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
          // Оптимизация: используем key для эффективного обновления списка
          return _OrderCard(
            key: ValueKey(order.id), // Ключ для оптимизации перерисовок
            order: order,
            isOperator: isOperator, // Передаем роль
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
/// Оптимизация: используем StatelessWidget вместо ConsumerWidget для избежания лишних перерисовок
class _OrderCard extends StatelessWidget {
  final Order order;
  final VoidCallback onTap;
  final bool isOperator; // Передаем извне вместо ref.watch

  const _OrderCard({
    super.key, // Добавляем key для оптимизации списков
    required this.order,
    required this.onTap,
    this.isOperator = false,
  });

  @override
  Widget build(BuildContext context) {
    final statusColor = StatusColors.getOrderStatusColor(
      order.status.toString().split('.').last.toUpperCase(),
    );

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


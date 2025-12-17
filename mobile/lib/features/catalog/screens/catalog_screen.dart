import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/utils/debouncer.dart';
import '../../../core/offline/cache_service.dart';
import '../../auth/providers/auth_providers.dart';
import '../models/catalog_models.dart';
import '../services/catalog_service.dart';

/// Экран номенклатуры
class CatalogScreen extends ConsumerStatefulWidget {
  const CatalogScreen({super.key});

  @override
  ConsumerState<CatalogScreen> createState() => _CatalogScreenState();
}

class _CatalogScreenState extends ConsumerState<CatalogScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _searchController = TextEditingController();
  final _debouncer = Debouncer(delay: const Duration(milliseconds: 300));
  int _refreshKey = 0; // Ключ для принудительного обновления табов

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this); // Техника, Услуги, Грунт, Инструмент, Навеска
    // Оптимизация: debounce для поиска
    _searchController.addListener(_onSearchChanged);
  }

  void _onSearchChanged() {
    // Используем debounce чтобы не перерисовывать на каждое нажатие клавиши
    _debouncer.call(() {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _debouncer.dispose();
    _searchController.removeListener(_onSearchChanged);
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Оптимизация: используем read вместо watch для избежания лишних перерисовок
    final authState = ref.read(authStateProvider);
    final isAdmin = authState.user?.role == 'admin';
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Номенклатура'),
        actions: isAdmin
            ? [
                IconButton(
                  icon: const Icon(Icons.add_circle_outline),
                  tooltip: 'Добавить',
                  onPressed: () {
                    final currentIndex = _tabController.index;
                    String type;
                    if (currentIndex == 0) {
                      type = 'equipment';
                    } else if (currentIndex == 1) {
                      type = 'service';
                    } else {
                      type = 'material';
                    }
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => _NomenclatureEditScreen(
                          type: type,
                          tabIndex: currentIndex,
                        ),
                      ),
                    ).then((result) {
                      // Мгновенно обновляем данные после создания/обновления
                      // Инкрементируем refreshKey для принудительного обновления табов
                      if (result == true) {
                        setState(() {
                          _refreshKey++;
                        });
                      }
                    });
                  },
                ),
              ]
            : null,
      ),
      floatingActionButton: isAdmin
          ? FloatingActionButton(
              onPressed: () {
                final currentIndex = _tabController.index;
                String type;
                if (currentIndex == 0) {
                  type = 'equipment';
                } else if (currentIndex == 1) {
                  type = 'service';
                } else {
                  type = 'material';
                }
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => _NomenclatureEditScreen(
                      type: type,
                      tabIndex: currentIndex,
                    ),
                  ),
                ).then((_) {
                  // Обновляем данные после возврата
                  setState(() {});
                });
              },
              child: const Icon(Icons.add),
              tooltip: 'Добавить элемент',
            )
          : null,
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
            indicatorSize: TabBarIndicatorSize.tab,
            labelColor: Theme.of(context).primaryColor,
            unselectedLabelColor: Colors.grey,
            labelStyle: const TextStyle(
              fontWeight: FontWeight.bold,
            ),
            tabs: const [
              Tab(text: 'Техника'),
              Tab(text: 'Услуги'),
              Tab(text: 'Грунт'),
              Tab(text: 'Инструмент'),
              Tab(text: 'Навеска'),
            ],
          ),
        ),
        // Поиск
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Поиск...',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            // Оптимизация: фильтрация происходит через debounce в _onSearchChanged
          ),
        ),
        // Контент
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _EquipmentTab(
                key: ValueKey('equipment_$_refreshKey'),
                search: _searchController.text,
                isAdmin: isAdmin,
              ),
              _ServicesTab(
                key: ValueKey('services_$_refreshKey'),
                search: _searchController.text,
                isAdmin: isAdmin,
              ),
              _SoilTab(
                key: ValueKey('soil_$_refreshKey'),
                search: _searchController.text,
                isAdmin: isAdmin,
              ),
              _ToolTab(
                key: ValueKey('tool_$_refreshKey'),
                search: _searchController.text,
                isAdmin: isAdmin,
              ),
              _AttachmentTab(
                key: ValueKey('attachment_$_refreshKey'),
                search: _searchController.text,
                isAdmin: isAdmin,
              ),
            ],
          ),
        ),
      ],
      ),
    );
  }
}

/// Вкладка техники
class _EquipmentTab extends ConsumerStatefulWidget {
  final String search;
  final bool isAdmin;

  const _EquipmentTab({super.key, required this.search, required this.isAdmin});

  @override
  ConsumerState<_EquipmentTab> createState() => _EquipmentTabState();
}

class _EquipmentTabState extends ConsumerState<_EquipmentTab> {
  Future<List<Equipment>>? _equipmentFuture;

  @override
  void initState() {
    super.initState();
    _loadEquipment();
  }

  @override
  void didUpdateWidget(_EquipmentTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.search != widget.search) {
      _loadEquipment();
    }
  }

  void _loadEquipment() {
    final catalogService = ref.read(catalogServiceProvider);
    final cacheService = ref.read(cacheServiceProvider);
    
    // ОПТИМИЗАЦИЯ: Сначала загружаем из кэша для мгновенного отображения
    Future<List<Equipment>> loadFromCache() async {
      try {
        final cached = await cacheService.getCachedEquipment();
        if (cached != null && cached.isNotEmpty) {
          return cached
              .map((json) => Equipment.fromJson(json as Map<String, dynamic>))
              .toList();
        }
      } catch (e) {
        // Игнорируем ошибки кэша
      }
      return [];
    }
    
    // Загружаем из кэша сразу, затем обновляем с сервера
    setState(() {
      _equipmentFuture = loadFromCache().then((cachedEquipment) {
        // После загрузки из кэша, обновляем с сервера
        return catalogService.getEquipment(
          search: widget.search.isEmpty ? null : widget.search,
        ).then((serverEquipment) {
          // Фильтруем по поиску если нужно
          if (widget.search.isNotEmpty) {
            final searchLower = widget.search.toLowerCase();
            return serverEquipment.where((e) {
              return e.name.toLowerCase().contains(searchLower) ||
                  e.description.toLowerCase().contains(searchLower);
            }).toList();
          }
          return serverEquipment;
        }).catchError((e) {
          // Если ошибка загрузки с сервера, возвращаем кэш
          if (cachedEquipment.isNotEmpty) {
            return cachedEquipment;
          }
          throw e;
        });
      });
    });
  }

  @override
  Widget build(BuildContext context) {
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
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 48, color: Colors.red),
                const SizedBox(height: 16),
                Text(
                  'Ошибка загрузки: ${snapshot.error}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.red),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _loadEquipment,
                  child: const Text('Повторить'),
                ),
              ],
            ),
          );
        }
        final equipment = snapshot.data ?? [];
        if (equipment.isEmpty) {
          return const Center(child: Text('Техника не найдена'));
        }
        return ListView.builder(
          itemCount: equipment.length,
          itemBuilder: (context, index) {
            final item = equipment[index];
            return _EquipmentCard(
              key: ValueKey(item.id), // Ключ для оптимизации перерисовок
              equipment: item,
              isAdmin: widget.isAdmin,
              onRefresh: _loadEquipment,
            );
          },
        );
      },
    );
  }
}

/// Карточка техники
class _EquipmentCard extends ConsumerWidget {
  final Equipment equipment;
  final bool isAdmin;
  final VoidCallback onRefresh;

  const _EquipmentCard({
    super.key, // Добавляем key для оптимизации списков
    required this.equipment,
    required this.isAdmin,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: ListTile(
        leading: equipment.photos.isNotEmpty
            ? Image.network(
                equipment.photos.first,
                width: 50,
                height: 50,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return const Icon(Icons.construction, size: 50);
                },
              )
            : const Icon(Icons.construction, size: 50),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              equipment.name,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            if (equipment.description.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                equipment.description,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey[600],
                    ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
        subtitle: Text('${equipment.code} • ${equipment.hourlyRate} ₽/час'),
        trailing: isAdmin
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit, color: Colors.blue),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => _NomenclatureEditScreen(
                            type: 'equipment',
                            item: equipment,
                            tabIndex: 0,
                          ),
                        ),
                      ).then((_) => onRefresh());
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () async {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Удалить?'),
                          content: Text('Вы уверены, что хотите удалить "${equipment.name}"?'),
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
                      if (confirm == true) {
                        try {
                          final catalogService = ref.read(catalogServiceProvider);
                          await catalogService.deleteEquipment(equipment.id);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Удалено успешно')),
                            );
                            onRefresh();
                          }
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Ошибка: ${e.toString()}')),
                            );
                          }
                        }
                      }
                    },
                  ),
                ],
              )
            : Text(
                _getStatusLabel(equipment.status),
                style: TextStyle(
                  color: _getStatusColor(equipment.status),
                  fontWeight: FontWeight.bold,
                ),
              ),
        onTap: () {
          // TODO: Деталь техники
        },
      ),
    );
  }

  String _getStatusLabel(EquipmentStatus status) {
    switch (status) {
      case EquipmentStatus.available:
        return 'Доступна';
      case EquipmentStatus.busy:
        return 'Занята';
      case EquipmentStatus.maintenance:
        return 'Обслуживание';
      case EquipmentStatus.inactive:
        return 'Неактивна';
    }
  }

  Color _getStatusColor(EquipmentStatus status) {
    switch (status) {
      case EquipmentStatus.available:
        return Colors.green;
      case EquipmentStatus.busy:
        return Colors.orange;
      case EquipmentStatus.maintenance:
        return Colors.blue;
      case EquipmentStatus.inactive:
        return Colors.grey;
    }
  }
}

/// Вкладка услуг
class _ServicesTab extends ConsumerStatefulWidget {
  final String search;
  final bool isAdmin;

  const _ServicesTab({super.key, required this.search, required this.isAdmin});

  @override
  ConsumerState<_ServicesTab> createState() => _ServicesTabState();
}

class _ServicesTabState extends ConsumerState<_ServicesTab> {
  Future<List<ServiceItem>>? _servicesFuture;

  @override
  void initState() {
    super.initState();
    _loadServices();
  }

  @override
  void didUpdateWidget(_ServicesTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.search != widget.search) {
      _loadServices();
    }
  }

  void _loadServices() {
    final catalogService = ref.read(catalogServiceProvider);
    final cacheService = ref.read(cacheServiceProvider);
    
    // ОПТИМИЗАЦИЯ: Сначала загружаем из кэша для мгновенного отображения
    Future<List<ServiceItem>> loadFromCache() async {
      try {
        final cached = await cacheService.getCachedServices();
        if (cached != null && cached.isNotEmpty) {
          return cached
              .map((json) => ServiceItem.fromJson(json as Map<String, dynamic>))
              .toList();
        }
      } catch (e) {
        // Игнорируем ошибки кэша
      }
      return [];
    }
    
    // Загружаем из кэша сразу, затем обновляем с сервера
    setState(() {
      _servicesFuture = loadFromCache().then((cachedServices) {
        // После загрузки из кэша, обновляем с сервера
        return catalogService.getServices(
          search: widget.search.isEmpty ? null : widget.search,
        ).then((serverServices) {
          // Фильтруем по поиску если нужно
          if (widget.search.isNotEmpty) {
            final searchLower = widget.search.toLowerCase();
            return serverServices.where((s) {
              return s.name.toLowerCase().contains(searchLower);
            }).toList();
          }
          return serverServices;
        }).catchError((e) {
          // Если ошибка загрузки с сервера, возвращаем кэш
          if (cachedServices.isNotEmpty) {
            return cachedServices;
          }
          throw e;
        });
      });
    });
  }

  @override
  Widget build(BuildContext context) {
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
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 48, color: Colors.red),
                const SizedBox(height: 16),
                Text(
                  'Ошибка загрузки: ${snapshot.error}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.red),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _loadServices,
                  child: const Text('Повторить'),
                ),
              ],
            ),
          );
        }
        final services = snapshot.data ?? [];
        if (services.isEmpty) {
          return const Center(child: Text('Услуги не найдены'));
        }
        return ListView.builder(
          itemCount: services.length,
          itemBuilder: (context, index) {
            final service = services[index];
            return Card(
              key: ValueKey(service.id), // Ключ для оптимизации перерисовок
              margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: ListTile(
                title: Text(service.name),
                subtitle: Text('${service.price ?? 0} ₽/${service.unit}'),
                trailing: widget.isAdmin
                    ? Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit, color: Colors.blue, size: 24),
                            tooltip: 'Редактировать',
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => _NomenclatureEditScreen(
                                    type: 'service',
                                    item: service,
                                    tabIndex: 1,
                                  ),
                                ),
                              ).then((result) {
                                // Обновляем список после редактирования
                                if (result == true) {
                                  _loadServices();
                                }
                              });
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red, size: 24),
                            tooltip: 'Удалить',
                            onPressed: () async {
                              final confirm = await showDialog<bool>(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: const Text('Удалить?'),
                                  content: Text('Вы уверены, что хотите удалить "${service.name}"?'),
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
                              if (confirm == true) {
                                try {
                                  final catalogService = ref.read(catalogServiceProvider);
                                  await catalogService.deleteService(service.id);
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Удалено успешно')),
                                    );
                                    _loadServices();
                                  }
                                } catch (e) {
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('Ошибка: ${e.toString()}')),
                                    );
                                  }
                                }
                              }
                            },
                          ),
                        ],
                      )
                    : (service.isActive
                        ? const Icon(Icons.check_circle, color: Colors.green)
                        : const Icon(Icons.cancel, color: Colors.grey)),
              ),
            );
          },
        );
      },
    );
  }
}

/// Вкладка грунта
class _SoilTab extends ConsumerStatefulWidget {
  final String search;
  final bool isAdmin;

  const _SoilTab({super.key, required this.search, required this.isAdmin});

  @override
  ConsumerState<_SoilTab> createState() => _SoilTabState();
}

class _SoilTabState extends ConsumerState<_SoilTab> {
  Future<List<MaterialItem>>? _materialsFuture;

  @override
  void initState() {
    super.initState();
    _loadMaterials();
  }

  @override
  void didUpdateWidget(_SoilTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.search != widget.search) {
      _loadMaterials();
    }
  }

  void _loadMaterials() {
    final catalogService = ref.read(catalogServiceProvider);
    final cacheService = ref.read(cacheServiceProvider);
    
    // ОПТИМИЗАЦИЯ: Сначала загружаем из кэша для мгновенного отображения
    Future<List<MaterialItem>> loadFromCache() async {
      try {
        final cached = await cacheService.getCachedMaterials();
        if (cached != null && cached.isNotEmpty) {
          final allMaterials = cached
              .map((json) => MaterialItem.fromJson(json as Map<String, dynamic>))
              .toList();
          // Фильтруем по категории
          return allMaterials.where((m) => m.category == 'soil').toList();
        }
      } catch (e) {
        // Игнорируем ошибки кэша
      }
      return [];
    }
    
    // Загружаем из кэша сразу, затем обновляем с сервера
    setState(() {
      _materialsFuture = loadFromCache().then((cachedMaterials) {
        // После загрузки из кэша, обновляем с сервера
        return catalogService.getMaterials(
          search: widget.search.isEmpty ? null : widget.search,
          category: 'soil', // Грунт
        ).then((serverMaterials) {
          // Фильтруем по поиску если нужно
          if (widget.search.isNotEmpty) {
            final searchLower = widget.search.toLowerCase();
            return serverMaterials.where((m) {
              return m.name.toLowerCase().contains(searchLower);
            }).toList();
          }
          return serverMaterials;
        }).catchError((e) {
          // Если ошибка загрузки с сервера, возвращаем кэш
          if (cachedMaterials.isNotEmpty) {
            return cachedMaterials;
          }
          throw e;
        });
      });
    });
  }

  @override
  Widget build(BuildContext context) {
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
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 48, color: Colors.red),
                const SizedBox(height: 16),
                Text(
                  'Ошибка загрузки: ${snapshot.error}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.red),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _loadMaterials,
                  child: const Text('Повторить'),
                ),
              ],
            ),
          );
        }
        final materials = snapshot.data ?? [];
        if (materials.isEmpty) {
          return const Center(child: Text('Грунт не найден'));
        }
        return ListView.builder(
          itemCount: materials.length,
          itemBuilder: (context, index) {
            final material = materials[index];
            return _MaterialCard(
              key: ValueKey(material.id),
              material: material,
              isAdmin: widget.isAdmin,
              onRefresh: _loadMaterials,
              category: 'soil',
            );
          },
        );
      },
    );
  }
}

/// Вкладка инструментов
class _ToolTab extends ConsumerStatefulWidget {
  final String search;
  final bool isAdmin;

  const _ToolTab({super.key, required this.search, required this.isAdmin});

  @override
  ConsumerState<_ToolTab> createState() => _ToolTabState();
}

class _ToolTabState extends ConsumerState<_ToolTab> {
  Future<List<MaterialItem>>? _materialsFuture;

  @override
  void initState() {
    super.initState();
    _loadMaterials();
  }

  @override
  void didUpdateWidget(_ToolTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.search != widget.search) {
      _loadMaterials();
    }
  }

  void _loadMaterials() {
    final catalogService = ref.read(catalogServiceProvider);
    final cacheService = ref.read(cacheServiceProvider);
    
    // ОПТИМИЗАЦИЯ: Сначала загружаем из кэша для мгновенного отображения
    Future<List<MaterialItem>> loadFromCache() async {
      try {
        final cached = await cacheService.getCachedMaterials();
        if (cached != null && cached.isNotEmpty) {
          final allMaterials = cached
              .map((json) => MaterialItem.fromJson(json as Map<String, dynamic>))
              .toList();
          // Фильтруем по категории
          return allMaterials.where((m) => m.category == 'tool').toList();
        }
      } catch (e) {
        // Игнорируем ошибки кэша
      }
      return [];
    }
    
    // Загружаем из кэша сразу, затем обновляем с сервера
    setState(() {
      _materialsFuture = loadFromCache().then((cachedMaterials) {
        // После загрузки из кэша, обновляем с сервера
        return catalogService.getMaterials(
          search: widget.search.isEmpty ? null : widget.search,
          category: 'tool', // Инструмент
        ).then((serverMaterials) {
          // Фильтруем по поиску если нужно
          if (widget.search.isNotEmpty) {
            final searchLower = widget.search.toLowerCase();
            return serverMaterials.where((m) {
              return m.name.toLowerCase().contains(searchLower);
            }).toList();
          }
          return serverMaterials;
        }).catchError((e) {
          // Если ошибка загрузки с сервера, возвращаем кэш
          if (cachedMaterials.isNotEmpty) {
            return cachedMaterials;
          }
          throw e;
        });
      });
    });
  }

  @override
  Widget build(BuildContext context) {
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
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 48, color: Colors.red),
                const SizedBox(height: 16),
                Text(
                  'Ошибка загрузки: ${snapshot.error}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.red),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _loadMaterials,
                  child: const Text('Повторить'),
                ),
              ],
            ),
          );
        }
        final materials = snapshot.data ?? [];
        if (materials.isEmpty) {
          return const Center(child: Text('Инструменты не найдены'));
        }
        return ListView.builder(
          itemCount: materials.length,
          itemBuilder: (context, index) {
            final material = materials[index];
            return _MaterialCard(
              key: ValueKey(material.id),
              material: material,
              isAdmin: widget.isAdmin,
              onRefresh: _loadMaterials,
              category: 'tool',
            );
          },
        );
      },
    );
  }
}

/// Вкладка навесок
class _AttachmentTab extends ConsumerStatefulWidget {
  final String search;
  final bool isAdmin;

  const _AttachmentTab({super.key, required this.search, required this.isAdmin});

  @override
  ConsumerState<_AttachmentTab> createState() => _AttachmentTabState();
}

class _AttachmentTabState extends ConsumerState<_AttachmentTab> {
  Future<List<MaterialItem>>? _materialsFuture;

  @override
  void initState() {
    super.initState();
    _loadMaterials();
  }

  @override
  void didUpdateWidget(_AttachmentTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.search != widget.search) {
      _loadMaterials();
    }
  }

  void _loadMaterials() {
    final catalogService = ref.read(catalogServiceProvider);
    final cacheService = ref.read(cacheServiceProvider);
    
    // ОПТИМИЗАЦИЯ: Сначала загружаем из кэша для мгновенного отображения
    Future<List<MaterialItem>> loadFromCache() async {
      try {
        final cached = await cacheService.getCachedMaterials();
        if (cached != null && cached.isNotEmpty) {
          final allMaterials = cached
              .map((json) => MaterialItem.fromJson(json as Map<String, dynamic>))
              .toList();
          // Фильтруем по категории
          return allMaterials.where((m) => m.category == 'attachment').toList();
        }
      } catch (e) {
        // Игнорируем ошибки кэша
      }
      return [];
    }
    
    // Загружаем из кэша сразу, затем обновляем с сервера
    setState(() {
      _materialsFuture = loadFromCache().then((cachedMaterials) {
        // После загрузки из кэша, обновляем с сервера
        return catalogService.getMaterials(
          search: widget.search.isEmpty ? null : widget.search,
          category: 'attachment', // Навеска
        ).then((serverMaterials) {
          // Фильтруем по поиску если нужно
          if (widget.search.isNotEmpty) {
            final searchLower = widget.search.toLowerCase();
            return serverMaterials.where((m) {
              return m.name.toLowerCase().contains(searchLower);
            }).toList();
          }
          return serverMaterials;
        }).catchError((e) {
          // Если ошибка загрузки с сервера, возвращаем кэш
          if (cachedMaterials.isNotEmpty) {
            return cachedMaterials;
          }
          throw e;
        });
      });
    });
  }

  @override
  Widget build(BuildContext context) {
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
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 48, color: Colors.red),
                const SizedBox(height: 16),
                Text(
                  'Ошибка загрузки: ${snapshot.error}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.red),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _loadMaterials,
                  child: const Text('Повторить'),
                ),
              ],
            ),
          );
        }
        final materials = snapshot.data ?? [];
        if (materials.isEmpty) {
          return const Center(child: Text('Навески не найдены'));
        }
        return ListView.builder(
          itemCount: materials.length,
          itemBuilder: (context, index) {
            final material = materials[index];
            return _MaterialCard(
              key: ValueKey(material.id),
              material: material,
              isAdmin: widget.isAdmin,
              onRefresh: _loadMaterials,
              category: 'attachment',
            );
          },
        );
      },
    );
  }
}

/// Карточка материала с кнопками управления
class _MaterialCard extends ConsumerWidget {
  final MaterialItem material;
  final bool isAdmin;
  final VoidCallback onRefresh;
  final String category;

  const _MaterialCard({
    super.key, // Добавляем key для оптимизации списков
    required this.material,
    required this.isAdmin,
    required this.onRefresh,
    required this.category,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: ListTile(
        title: Text(material.name),
        subtitle: Text('${material.price} ₽/${material.unit}'),
        trailing: isAdmin
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit, color: Colors.blue, size: 24),
                    tooltip: 'Редактировать',
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => _NomenclatureEditScreen(
                            type: 'material',
                            item: material,
                            tabIndex: category == 'soil' ? 2 : category == 'tool' ? 3 : 4,
                          ),
                        ),
                      ).then((_) => onRefresh());
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red, size: 24),
                    tooltip: 'Удалить',
                    onPressed: () async {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Удалить?'),
                          content: Text('Вы уверены, что хотите удалить "${material.name}"?'),
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
                      if (confirm == true) {
                        try {
                          final catalogService = ref.read(catalogServiceProvider);
                          await catalogService.deleteMaterial(material.id);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Удалено успешно')),
                            );
                            onRefresh();
                          }
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Ошибка: ${e.toString()}')),
                            );
                          }
                        }
                      }
                    },
                  ),
                ],
              )
            : (material.isActive
                ? const Icon(Icons.check_circle, color: Colors.green)
                : const Icon(Icons.cancel, color: Colors.grey)),
      ),
    );
  }
}

/// Экран редактирования номенклатуры
class _NomenclatureEditScreen extends ConsumerStatefulWidget {
  final String type; // 'equipment', 'service', 'material'
  final dynamic item; // null для создания
  final int tabIndex;

  const _NomenclatureEditScreen({
    required this.type,
    this.item,
    required this.tabIndex,
  });

  @override
  ConsumerState<_NomenclatureEditScreen> createState() => _NomenclatureEditScreenState();
}

class _NomenclatureEditScreenState extends ConsumerState<_NomenclatureEditScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isSaving = false;

  // Контроллеры для Equipment
  final _codeController = TextEditingController();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _hourlyRateController = TextEditingController();
  final _dailyRateController = TextEditingController();

  // Контроллеры для ServiceItem
  final _serviceNameController = TextEditingController();
  final _servicePriceController = TextEditingController();

  // Контроллеры для MaterialItem
  final _materialNameController = TextEditingController();
  final _materialPriceController = TextEditingController();
  final _materialUnitController = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.item != null) {
      _loadItemData();
    } else {
      if (widget.type == 'material') {
        _materialUnitController.text = widget.tabIndex == 2 ? 'м³' : 'шт';
      }
    }
  }

  void _loadItemData() {
    if (widget.item is Equipment) {
      final eq = widget.item as Equipment;
      _codeController.text = eq.code;
      _nameController.text = eq.name;
      _descriptionController.text = eq.description;
      _hourlyRateController.text = eq.hourlyRate.toString();
      _dailyRateController.text = eq.dailyRate?.toString() ?? '';
    } else if (widget.item is ServiceItem) {
      final svc = widget.item as ServiceItem;
      _serviceNameController.text = svc.name;
      _servicePriceController.text = svc.price?.toString() ?? '';
    } else if (widget.item is MaterialItem) {
      final mat = widget.item as MaterialItem;
      _materialNameController.text = mat.name;
      _materialPriceController.text = mat.price.toString();
      _materialUnitController.text = mat.unit;
    }
  }

  @override
  void dispose() {
    _codeController.dispose();
    _nameController.dispose();
    _descriptionController.dispose();
    _hourlyRateController.dispose();
    _dailyRateController.dispose();
    _serviceNameController.dispose();
    _servicePriceController.dispose();
    _materialNameController.dispose();
    _materialPriceController.dispose();
    _materialUnitController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSaving = true;
    });

    try {
      final catalogService = ref.read(catalogServiceProvider);

      switch (widget.type) {
        case 'equipment':
          final code = _codeController.text.trim();
          final name = _nameController.text.trim();
          final description = _descriptionController.text.trim();
          final hourlyRate = double.parse(_hourlyRateController.text.trim());
          final dailyRate = double.tryParse(_dailyRateController.text.trim());
          if (widget.item == null) {
            await catalogService.createEquipment(
              code: code,
              name: name,
              description: description,
              hourlyRate: hourlyRate,
              dailyRate: dailyRate,
            );
          } else {
            await catalogService.updateEquipment(
              (widget.item as Equipment).id,
              code: code,
              name: name,
              description: description,
              hourlyRate: hourlyRate,
              dailyRate: dailyRate,
            );
          }
          break;
        case 'service':
          final price = double.tryParse(_servicePriceController.text.trim()) ?? 0.0;
          if (widget.item == null) {
            await catalogService.createService(
              name: _serviceNameController.text.trim(),
              price: price > 0 ? price : null,
            );
          } else {
            await catalogService.updateService(
              (widget.item as ServiceItem).id,
              name: _serviceNameController.text.trim(),
              price: price > 0 ? price : null,
            );
          }
          break;
        case 'material':
          String category;
          if (widget.tabIndex == 2) {
            category = 'soil';
          } else if (widget.tabIndex == 3) {
            category = 'tool';
          } else {
            category = 'attachment';
          }
          final price = double.parse(_materialPriceController.text.trim());
          if (widget.item == null) {
            await catalogService.createMaterial(
              name: _materialNameController.text.trim(),
              price: price,
              unit: _materialUnitController.text.trim(),
              category: category,
            );
          } else {
            await catalogService.updateMaterial(
              (widget.item as MaterialItem).id,
              name: _materialNameController.text.trim(),
              price: price,
              unit: _materialUnitController.text.trim(),
              category: category,
            );
          }
          break;
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(widget.item == null ? 'Создано' : 'Обновлено')),
        );
        // Возвращаем true для индикации успешного создания/обновления
        // Это триггерит обновление списков в родительском виджете
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка: ${e.toString()}')),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.item == null ? 'Добавить' : 'Редактировать'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              if (widget.type == 'equipment') ..._buildEquipmentFields(),
              if (widget.type == 'service') ..._buildServiceFields(),
              if (widget.type == 'material') ..._buildMaterialFields(),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _isSaving ? null : _save,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 48),
                ),
                child: _isSaving
                    ? const CircularProgressIndicator()
                    : Text(widget.item == null ? 'Добавить' : 'Сохранить'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildEquipmentFields() {
    return [
      TextFormField(
        controller: _codeController,
        decoration: const InputDecoration(labelText: 'Код *', border: OutlineInputBorder()),
        validator: (v) => v?.isEmpty ?? true ? 'Обязательное поле' : null,
      ),
      const SizedBox(height: 16),
      TextFormField(
        controller: _nameController,
        decoration: const InputDecoration(labelText: 'Название *', border: OutlineInputBorder()),
        validator: (v) => v?.isEmpty ?? true ? 'Обязательное поле' : null,
      ),
      const SizedBox(height: 16),
      TextFormField(
        controller: _descriptionController,
        decoration: const InputDecoration(labelText: 'Описание', border: OutlineInputBorder()),
        maxLines: 3,
      ),
      const SizedBox(height: 16),
      TextFormField(
        controller: _hourlyRateController,
        decoration: const InputDecoration(labelText: 'Почасовая ставка *', border: OutlineInputBorder()),
        keyboardType: TextInputType.numberWithOptions(decimal: true),
        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}'))],
        validator: (v) => v?.isEmpty ?? true ? 'Обязательное поле' : null,
      ),
      const SizedBox(height: 16),
      TextFormField(
        controller: _dailyRateController,
        decoration: const InputDecoration(labelText: 'Дневная ставка', border: OutlineInputBorder()),
        keyboardType: TextInputType.numberWithOptions(decimal: true),
        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}'))],
      ),
    ];
  }

  List<Widget> _buildServiceFields() {
    return [
      TextFormField(
        controller: _serviceNameController,
        decoration: const InputDecoration(labelText: 'Название услуги *', border: OutlineInputBorder()),
        validator: (v) => v?.isEmpty ?? true ? 'Обязательное поле' : null,
      ),
      const SizedBox(height: 16),
      TextFormField(
        controller: _servicePriceController,
        decoration: const InputDecoration(labelText: 'Цена услуги', border: OutlineInputBorder()),
        keyboardType: TextInputType.numberWithOptions(decimal: true),
        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}'))],
      ),
    ];
  }

  List<Widget> _buildMaterialFields() {
    return [
      TextFormField(
        controller: _materialNameController,
        decoration: const InputDecoration(labelText: 'Название материала *', border: OutlineInputBorder()),
        validator: (v) => v?.isEmpty ?? true ? 'Обязательное поле' : null,
      ),
      const SizedBox(height: 16),
      TextFormField(
        controller: _materialPriceController,
        decoration: const InputDecoration(labelText: 'Цена материала *', border: OutlineInputBorder()),
        keyboardType: TextInputType.numberWithOptions(decimal: true),
        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}'))],
        validator: (v) => v?.isEmpty ?? true ? 'Обязательное поле' : null,
      ),
      const SizedBox(height: 16),
      TextFormField(
        controller: _materialUnitController,
        decoration: const InputDecoration(labelText: 'Единица измерения *', border: OutlineInputBorder()),
        validator: (v) => v?.isEmpty ?? true ? 'Обязательное поле' : null,
      ),
    ];
  }
}


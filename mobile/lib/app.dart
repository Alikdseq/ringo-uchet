import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/app_localizations.dart';
import 'core/config/firebase_service.dart';
import 'core/offline/sync_service.dart';
import 'core/offline/cache_service.dart';
import 'core/network/connectivity_service.dart';
import 'core/constants/app_constants.dart';
import 'features/auth/providers/auth_providers.dart';
import 'features/auth/screens/login_screen.dart';
import 'features/orders/screens/dashboard_screen.dart';
import 'features/orders/screens/orders_list_screen.dart';
import 'features/orders/screens/create_order_screen.dart';
import 'features/orders/screens/order_detail_screen.dart';
import 'features/orders/services/order_service.dart';
import 'features/orders/models/order_models.dart';
import 'features/catalog/screens/catalog_screen.dart';
import 'features/catalog/services/catalog_service.dart';
import 'features/catalog/models/catalog_models.dart';
import 'features/finance/screens/reports_screen.dart';
import 'features/finance/screens/operator_salary_screen.dart';
import 'features/profile/screens/profile_screen.dart';
import 'features/orders/screens/offline_queue_screen.dart';
import 'features/notifications/screens/notification_settings_screen.dart';
import 'features/notifications/services/notification_service.dart';
import 'shared/widgets/screen_wrapper.dart';
import 'shared/widgets/offline_banner.dart';
import 'core/providers/navigation_provider.dart';

// Глобальный ключ для навигации (для deep links)
final navigatorKey = GlobalKey<NavigatorState>();

class RingoApp extends ConsumerStatefulWidget {
  const RingoApp({super.key});

  @override
  ConsumerState<RingoApp> createState() => _RingoAppState();
}

class _RingoAppState extends ConsumerState<RingoApp> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeNotifications();
    });
  }

  Future<void> _initializeNotifications() async {
    try {
      final firebaseService = ref.read(firebaseServiceProvider);

      // На web Firebase может быть недоступен
      if (firebaseService.messaging == null) {
        debugPrint('Firebase Messaging not available (web or disabled)');
        return;
      }

      // Настройка обработчика для deep links
      final updatedService = FirebaseService(
        messaging: firebaseService.messaging,
        crashlytics: firebaseService.crashlytics,
        onNotificationTapped: _handleNotificationTap,
      );

      await updatedService.initializeFCM();

      // Регистрация токена после авторизации
      ref.listen(authStateProvider, (previous, next) {
        if (next.isAuthenticated && previous?.isAuthenticated != true) {
          _registerDeviceToken();
          // Запускаем автосинхронизацию (только если не web)
          if (!kIsWeb) {
            try {
              final syncService = ref.read(syncServiceProvider);
              syncService.startAutoSync();
            } catch (e) {
              debugPrint('Sync service error (non-critical): $e');
            }
          }
          // КРИТИЧНО: Предзагрузка данных из кэша ПЕРЕД открытием экрана
          // Затем обновление с сервера в фоне
          _preloadDataFromCacheFirst();
        }
      });
    } catch (e) {
      debugPrint('Notification initialization error (non-critical): $e');
      // Продолжаем работу даже если уведомления не инициализированы
    }
  }

  void _handleNotificationTap(RemoteMessage message) {
    final data = message.data;
    final type = data['type'] as String?;
    final orderId = data['order_id'] as String?;

    if (type == 'order' &&
        orderId != null &&
        navigatorKey.currentContext != null) {
      Navigator.of(navigatorKey.currentContext!).push(
        MaterialPageRoute(
          builder: (_) => OrderDetailScreen(orderId: orderId),
        ),
      );
    }
  }

  Future<void> _registerDeviceToken() async {
    try {
      final firebaseService = ref.read(firebaseServiceProvider);
      if (firebaseService.messaging == null) return;

      final token = await firebaseService.messaging!.getToken();
      if (token == null) return;

      final notificationService = ref.read(notificationServiceProvider);
      final platform =
          Theme.of(context).platform == TargetPlatform.iOS ? 'ios' : 'android';

      await notificationService.registerDeviceToken(
        token: token,
        platform: platform,
      );
    } catch (e) {
      debugPrint('Error registering device token: $e');
    }
  }

  /// Предзагрузка данных: СНАЧАЛА из кэша (мгновенно), затем с сервера (в фоне)
  /// ПОЛНАЯ ОФФЛАЙН ПОДДЕРЖКА: Приложение работает даже без интернета
  Future<void> _preloadDataFromCacheFirst() async {
    try {
      final orderService = ref.read(orderServiceProvider);
      final catalogService = ref.read(catalogServiceProvider);
      final cacheService = ref.read(cacheServiceProvider);
      final connectivityService = ref.read(connectivityServiceProvider);
      
      // ШАГ 1: Мгновенная загрузка из кэша (если есть) - не блокирует UI
      // КРИТИЧНО: Данные из кэша доступны мгновенно, даже БЕЗ интернета
      try {
        final cachedOrders = await cacheService.getCachedOrders();
        final cachedEquipment = await cacheService.getCachedEquipment();
        final cachedServices = await cacheService.getCachedServices();
        final cachedMaterials = await cacheService.getCachedMaterials();
        
        if (cachedOrders != null || cachedEquipment != null || 
            cachedServices != null || cachedMaterials != null) {
          debugPrint('✅ Cache data available - app works OFFLINE instantly');
        }
      } catch (e) {
        // Кэш недоступен - не критично
        debugPrint('Cache check error (non-critical): $e');
      }
      
      // ШАГ 2: Проверяем наличие интернета перед обновлением
      final hasConnection = await connectivityService.hasConnection();
      
      if (!hasConnection) {
        debugPrint('📴 No internet - using cache only. App works OFFLINE.');
        // Запускаем автосинхронизацию для автоматического обновления при появлении интернета
        if (!kIsWeb) {
          try {
            final syncService = ref.read(syncServiceProvider);
            syncService.startAutoSync();
          } catch (e) {
            debugPrint('Sync service error (non-critical): $e');
          }
        }
        return; // Нет интернета - используем только кэш
      }
      
      // ШАГ 3: Обновление с сервера в фоне (если есть интернет)
      // ОПТИМИЗАЦИЯ ДЛЯ VPN: Увеличенный таймаут для медленных соединений
      // При таймауте/ошибке используется кэш, поэтому UI не блокируется
      Future.microtask(() async {
        try {
          final startTime = DateTime.now();
          
          await Future.wait([
            orderService.getOrders(useCache: true).catchError((e) {
              debugPrint('Preload orders error: $e');
              return <Order>[];
            }),
            catalogService.getEquipment().catchError((e) {
              debugPrint('Preload equipment error: $e');
              return <Equipment>[];
            }),
            catalogService.getServices().catchError((e) {
              debugPrint('Preload services error: $e');
              return <ServiceItem>[];
            }),
            catalogService.getMaterials().catchError((e) {
              debugPrint('Preload materials error: $e');
              return <MaterialItem>[];
            }),
          ], eagerError: false).timeout(
            const Duration(seconds: AppConstants.preloadTimeoutSeconds),
            onTimeout: () {
              final elapsed = DateTime.now().difference(startTime);
              debugPrint('⚠️ Preload timeout (${AppConstants.preloadTimeoutSeconds}s, elapsed: ${elapsed.inSeconds}s) - cache will be used');
              return [<Order>[], <Equipment>[], <ServiceItem>[], <MaterialItem>[]];
            },
          );
          
          final elapsed = DateTime.now().difference(startTime);
          debugPrint('✅ Data updated from server in background (${elapsed.inSeconds}s)');
          
          // После успешного обновления синхронизируем оффлайн очередь
          if (!kIsWeb) {
            try {
              final syncService = ref.read(syncServiceProvider);
              await syncService.syncQueue();
            } catch (e) {
              debugPrint('Queue sync error (non-critical): $e');
            }
          }
        } catch (e) {
          debugPrint('⚠️ Background preload error (cache will be used): $e');
        }
      });
    } catch (e) {
      debugPrint('Preload critical error (non-critical): $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateProvider);

    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'Ringo Uchet',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('ru', 'RU'), // По умолчанию русский
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(1.0)),
          child: child!,
        );
      },
      // Навигация на основе состояния аутентификации
      // Показываем красивый splash screen пока идет загрузка/проверка авторизации
      // Затем показываем главный экран если авторизован, иначе экран входа
      home: authState.isLoading
          ? const _SplashScreen()
          : authState.isAuthenticated
              ? const _HomeScreenWithOfflineBanner()
              : const LoginScreen(),
      routes: {
        '/login': (context) => const LoginScreen(),
        '/home': (context) => const _HomeScreenWithOfflineBanner(),
      },
    );
  }
}

/// Красивый экран загрузки с индикатором
class _SplashScreen extends StatefulWidget {
  const _SplashScreen();

  @override
  State<_SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<_SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);

    _fadeAnimation = Tween<double>(
      begin: 0.5,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));

    _scaleAnimation = Tween<double>(
      begin: 0.9,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? [
                    theme.colorScheme.surface,
                    theme.colorScheme.surface.withOpacity(0.8),
                  ]
                : [
                    theme.colorScheme.primaryContainer.withOpacity(0.3),
                    theme.colorScheme.surface,
                  ],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Анимированный логотип/иконка
              AnimatedBuilder(
                animation: _controller,
                builder: (context, child) {
                  return Transform.scale(
                    scale: _scaleAnimation.value,
                    child: Opacity(
                      opacity: _fadeAnimation.value,
                      child: Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: theme.colorScheme.primary.withOpacity(0.3),
                              blurRadius: 20,
                              spreadRadius: 5,
                            ),
                          ],
                        ),
                        child: Icon(
                          Icons.account_circle,
                          size: 80,
                          color: theme.colorScheme.onPrimary,
                        ),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 48),
              
              // Название приложения
              Text(
                AppLocalizations.of(context)?.appName ?? 'Ringo Uchet',
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              
              // Подзаголовок
              Text(
                'Загрузка...',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.7),
                ),
              ),
              const SizedBox(height: 48),
              
              // Индикатор загрузки
              SizedBox(
                width: 40,
                height: 40,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    theme.colorScheme.primary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Главный экран с оффлайн баннером
class _HomeScreenWithOfflineBanner extends ConsumerWidget {
  const _HomeScreenWithOfflineBanner();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      children: [
        // Оффлайн баннер (показывается только когда нет интернета)
        const OfflineBanner(),
        // Главный экран
        const Expanded(child: _HomeScreen()),
      ],
    );
  }
}

/// Главный экран (после авторизации) с навигацией
class _HomeScreen extends ConsumerStatefulWidget {
  const _HomeScreen();

  @override
  ConsumerState<_HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<_HomeScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  int _ordersRefreshKey = 0; // Ключ для принудительного обновления OrdersListScreen

  @override
  void initState() {
    super.initState();
  }


  @override
  Widget build(BuildContext context) {
    // Оптимизация: используем watch только для authState (нужен для навигации)
    // Остальные данные читаем через read для избежания лишних перерисовок
    final authState = ref.watch(authStateProvider);
    final user = authState.user;
    final userRole = user?.role ?? 'user';
    final isAdmin = userRole == 'admin';
    final isOperator = userRole == 'operator';
    
    // Используем провайдер для управления индексом навигации
    final currentIndex = ref.watch(navigationIndexProvider);
    
    // Определяем доступные вкладки в зависимости от роли
    final availableIndices = <int>[];
    final availableTitles = <String>[];
    final availableScreens = <Widget>[];
    final availableBottomNavItems = <BottomNavigationBarItem>[];
    final availableDrawerItems = <Widget>[];
    
    // Главная - всегда доступна
    availableIndices.add(0);
    availableTitles.add('Главная');
    availableScreens.add(ScreenWrapper(builder: (_) => const DashboardScreen()));
    availableBottomNavItems.add(const BottomNavigationBarItem(
      icon: Icon(Icons.dashboard),
      label: 'Главная',
    ));
    availableDrawerItems.add(_buildDrawerItem(context, icon: Icons.dashboard, title: 'Главная', index: 0));
    
    // Заявки - всегда доступны
    availableIndices.add(1);
    availableTitles.add('Заявки');
    availableScreens.add(ScreenWrapper(
      key: ValueKey('orders_list_$_ordersRefreshKey'),
      builder: (_) => OrdersListScreen(
        refreshKey: _ordersRefreshKey,
      ),
    ));
    availableBottomNavItems.add(const BottomNavigationBarItem(
      icon: Icon(Icons.list_alt),
      label: 'Заявки',
    ));
    availableDrawerItems.add(_buildDrawerItem(context, icon: Icons.list_alt, title: 'Заявки', index: 1));
    
    // Номенклатура - только для админа и менеджера
    if (!isOperator) {
      availableIndices.add(2);
      availableTitles.add('Номенклатура');
      availableScreens.add(ScreenWrapper(builder: (_) => const CatalogScreen()));
      availableBottomNavItems.add(const BottomNavigationBarItem(
        icon: Icon(Icons.inventory),
        label: 'Номенклатура',
      ));
      availableDrawerItems.add(_buildDrawerItem(context, icon: Icons.inventory, title: 'Номенклатура', index: 2));
    }
    
    // Отчёты - для админа, зарплаты для оператора
    if (isAdmin) {
      availableIndices.add(3);
      availableTitles.add('Отчёты');
      availableScreens.add(ScreenWrapper(builder: (_) => const ReportsScreen()));
      availableBottomNavItems.add(const BottomNavigationBarItem(
        icon: Icon(Icons.analytics),
        label: 'Отчёты',
      ));
      availableDrawerItems.add(_buildDrawerItem(context, icon: Icons.analytics, title: 'Отчёты', index: 3));
    } else if (isOperator) {
      // Для оператора показываем экран зарплат вместо отчетов
      availableIndices.add(2);
      availableTitles.add('Мои зарплаты');
      availableScreens.add(ScreenWrapper(builder: (_) => const OperatorSalaryScreen()));
      availableBottomNavItems.add(const BottomNavigationBarItem(
        icon: Icon(Icons.payments),
        label: 'Зарплаты',
      ));
      availableDrawerItems.add(_buildDrawerItem(context, icon: Icons.payments, title: 'Мои зарплаты', index: 2));
    }
    
    // Профиль - всегда доступен
    final profileIndex = availableIndices.length;
    availableIndices.add(profileIndex);
    availableTitles.add('Профиль');
    availableScreens.add(ScreenWrapper(builder: (_) => const ProfileScreen()));
    availableBottomNavItems.add(const BottomNavigationBarItem(
      icon: Icon(Icons.person),
      label: 'Профиль',
    ));
    availableDrawerItems.add(_buildDrawerItem(context, icon: Icons.person, title: 'Профиль', index: profileIndex));
    
    // Нормализуем текущий индекс
    int normalizedIndex = currentIndex;
    if (normalizedIndex >= availableIndices.length) {
      normalizedIndex = 0;
    }

    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        title: Text(availableTitles[normalizedIndex]),
        leading: IconButton(
          icon: const Icon(Icons.menu),
          onPressed: () {
            _scaffoldKey.currentState?.openDrawer();
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Выход'),
                  content: const Text('Вы уверены, что хотите выйти?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      child: const Text('Отмена'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      child: const Text('Выйти'),
                    ),
                  ],
                ),
              );

              if (confirmed == true && context.mounted) {
                await ref.read(authStateProvider.notifier).logout();
                if (context.mounted) {
                  Navigator.of(context).pushReplacementNamed('/login');
                }
              }
            },
            tooltip: 'Выйти',
          ),
        ],
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: Colors.white,
                    child: Text(
                      user?.fullName[0].toUpperCase() ?? 'U',
                      style: TextStyle(
                        fontSize: 24,
                        color: Theme.of(context).primaryColor,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    user?.fullName ?? 'Пользователь',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (user?.role != null)
                    Text(
                      user!.role,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                ],
              ),
            ),
            ...availableDrawerItems,
            const Divider(),
            ListTile(
              leading: const Icon(Icons.sync),
              title: const Text('Оффлайн очередь'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const OfflineQueueScreen(),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.settings),
              title: const Text('Настройки уведомлений'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const NotificationSettingsScreen(),
                  ),
                );
              },
            ),
          ],
        ),
      ),
      body: IndexedStack(
        index: normalizedIndex,
        // Lazy loading: загружаем экраны только когда они нужны
        // IndexedStack уже реализует lazy loading - виджеты создаются только при первом обращении
        children: availableScreens,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: normalizedIndex,
        onTap: (index) {
          ref.read(navigationIndexProvider.notifier).setIndex(index);
          // Закрываем drawer, если открыт
          if (_scaffoldKey.currentState?.isDrawerOpen ?? false) {
            Navigator.pop(context);
          }
        },
        type: BottomNavigationBarType.fixed,
        items: availableBottomNavItems,
      ),
      floatingActionButton: (normalizedIndex == 1 && !isOperator) // На экране заявок и не оператор
          ? FloatingActionButton(
              heroTag: 'create_order_fab', // Уникальный тег для Hero
              onPressed: () async {
                final result = await Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const CreateOrderScreen(),
                  ),
                );
                // Обновляем список заявок после создания
                // result может быть Order (созданная заявка) или true (успешное создание)
                if ((result != null && result != false) && mounted) {
                  setState(() {
                    // Обновляем ключ для принудительного обновления OrdersListScreen
                    _ordersRefreshKey++;
                  });
                  // Мгновенно обновляем список заявок
                  // OrdersListScreen автоматически подхватит новую заявку из кэша
                }
              },
              child: const Icon(Icons.add),
              tooltip: 'Создать заявку',
            )
          : null,
    );
  }

  Widget _buildDrawerItem(BuildContext context, {required IconData icon, required String title, required int index}) {
    final currentIndex = ref.watch(navigationIndexProvider);
    final isSelected = currentIndex == index;
    return ListTile(
      leading: Icon(icon, color: isSelected ? Theme.of(context).primaryColor : null),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          color: isSelected ? Theme.of(context).primaryColor : null,
        ),
      ),
      selected: isSelected,
      onTap: () {
        ref.read(navigationIndexProvider.notifier).setIndex(index);
        Navigator.pop(context);
      },
    );
  }
}

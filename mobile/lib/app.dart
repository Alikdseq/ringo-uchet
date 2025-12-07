import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/app_localizations.dart';
import 'core/config/firebase_service.dart';
import 'core/offline/sync_service.dart';
import 'features/auth/providers/auth_providers.dart';
import 'features/auth/screens/login_screen.dart';
import 'features/orders/screens/dashboard_screen.dart';
import 'features/orders/screens/orders_list_screen.dart';
import 'features/orders/screens/create_order_screen.dart';
import 'features/orders/screens/order_detail_screen.dart';
import 'features/catalog/screens/catalog_screen.dart';
import 'features/finance/screens/reports_screen.dart';
import 'features/finance/screens/operator_salary_screen.dart';
import 'features/profile/screens/profile_screen.dart';
import 'features/orders/screens/offline_queue_screen.dart';
import 'features/notifications/screens/notification_settings_screen.dart';
import 'features/notifications/services/notification_service.dart';
import 'shared/widgets/screen_wrapper.dart';

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
      home: authState.isLoading
          ? const _SplashScreen()
          : authState.isAuthenticated
              ? const _HomeScreen()
              : const LoginScreen(),
      routes: {
        '/login': (context) => const LoginScreen(),
        '/home': (context) => const _HomeScreen(),
      },
    );
  }
}

/// Экран загрузки
class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 24),
            Text(
              AppLocalizations.of(context)?.appName ?? 'Ringo Uchet',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
          ],
        ),
      ),
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
  int _currentIndex = 0;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  int _ordersRefreshKey = 0; // Ключ для принудительного обновления OrdersListScreen

  void setCurrentIndex(int index) {
    setState(() {
      _currentIndex = index;
    });
  }


  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateProvider);
    final user = authState.user;
    final userRole = user?.role ?? 'user';
    final isAdmin = userRole == 'admin';
    final isOperator = userRole == 'operator';
    
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
      builder: (_) => const OrdersListScreen(),
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
    int normalizedIndex = _currentIndex;
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
        children: availableScreens,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: normalizedIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
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
                if (result == true && mounted) {
                  setState(() {
                    // Обновляем ключ для принудительного пересоздания OrdersListScreen
                    _ordersRefreshKey++;
                  });
                }
              },
              child: const Icon(Icons.add),
              tooltip: 'Создать заявку',
            )
          : null,
    );
  }

  Widget _buildDrawerItem(BuildContext context, {required IconData icon, required String title, required int index}) {
    final isSelected = _currentIndex == index;
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
        setState(() {
          _currentIndex = index;
        });
        Navigator.pop(context);
      },
    );
  }
}

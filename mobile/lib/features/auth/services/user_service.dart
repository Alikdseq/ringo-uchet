import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/dio_client.dart';
import '../../../shared/models/user.dart';
import '../../orders/services/order_service.dart';

/// Провайдер сервиса пользователей
final userServiceProvider = Provider<UserService>((ref) {
  final dio = ref.watch(dioClientProvider);
  final orderService = ref.watch(orderServiceProvider);
  return UserService(dio, orderService);
});

/// Сервис для работы с пользователями
class UserService {
  final Dio _dio;
  final OrderService _orderService;

  UserService(this._dio, this._orderService);

  /// Получить список операторов (пользователи с ролью operator)
  /// Использует несколько способов получения операторов для гарантированной доступности
  Future<List<UserInfo>> getOperators() async {
    // Способ 1: Пробуем получить через API пользователей
    final operatorsFromApi = await _getOperatorsFromApi();
    if (operatorsFromApi.isNotEmpty) {
      return operatorsFromApi;
    }

    // Способ 2: Получаем операторов из существующих заявок
    final operatorsFromOrders = await _getOperatorsFromOrders();
    if (operatorsFromOrders.isNotEmpty) {
      return operatorsFromOrders;
    }

    // Если ничего не получилось, возвращаем пустой список
    // Но UI все равно покажет возможность ввода ID оператора
    return [];
  }

  /// Получить операторов через API пользователей
  Future<List<UserInfo>> _getOperatorsFromApi() async {
    // Список возможных эндпоинтов для получения операторов
    final possibleEndpoints = [
      '/users/operators/',  // Новый endpoint для получения списка операторов
      '/api/v1/users/operators/',
      '/api/users/operators/',
      '/users/',  // Fallback на старый endpoint
      '/api/users/',
      '/api/v1/users/',
    ];

    for (final endpoint in possibleEndpoints) {
      try {
        // Для нового endpoint /users/operators/ просто получаем список
        if (endpoint.contains('/operators/')) {
          final response = await _dio.get(endpoint);
          final operators = _parseUsersFromResponse(response.data);
          if (operators.isNotEmpty) {
            return operators;
          }
          continue;
        }

        // Для старых endpoints пробуем с фильтром по роли
        try {
          final response = await _dio.get(
            endpoint,
            queryParameters: {'role': 'operator'},
          );
          final operators = _parseUsersFromResponse(response.data);
          if (operators.isNotEmpty) {
            return operators;
          }
        } catch (e) {
          // Если с фильтром не получилось, пробуем без фильтра
        }

        // Пробуем получить всех пользователей и отфильтровать на клиенте
        final response = await _dio.get(endpoint);
        final allUsers = _parseUsersFromResponse(response.data);
        final operators = allUsers
            .where((user) => user.role?.toLowerCase() == 'operator')
            .toList();
        if (operators.isNotEmpty) {
          return operators;
        }
      } on DioException catch (e) {
        // Если 404, пробуем следующий эндпоинт
        if (e.response?.statusCode == 404) {
          continue;
        }
        // Для других ошибок тоже пробуем следующий эндпоинт
        continue;
      } catch (e) {
        // Продолжаем пробовать другие эндпоинты
        continue;
      }
    }

    return [];
  }

  /// Получить операторов из существующих заявок
  Future<List<UserInfo>> _getOperatorsFromOrders() async {
    try {
      final orders = await _orderService.getOrders(useCache: true);
      final operatorsMap = <int, UserInfo>{};

      for (final order in orders) {
        if (order.operator != null) {
          operatorsMap[order.operator!.id] = order.operator!;
        }
      }

      return operatorsMap.values.toList();
    } catch (e) {
      // Если не получилось получить заявки, возвращаем пустой список
      return [];
    }
  }

  /// Парсинг пользователей из ответа API
  List<UserInfo> _parseUsersFromResponse(dynamic data) {
    List<UserInfo> users = [];
    
    if (data is List) {
      users = data
          .map((json) {
            try {
              return UserInfo.fromJson(json as Map<String, dynamic>);
            } catch (e) {
              return null;
            }
          })
          .whereType<UserInfo>()
          .toList();
    } else if (data is Map && data.containsKey('results')) {
      final results = data['results'];
      if (results is List) {
        users = results
            .map((json) {
              try {
                return UserInfo.fromJson(json as Map<String, dynamic>);
              } catch (e) {
                return null;
              }
            })
            .whereType<UserInfo>()
            .toList();
      }
    }

    return users;
  }

  /// Получить информацию о зарплатах оператора (для ЛК оператора)
  Future<Map<String, dynamic>> getOperatorSalary() async {
    try {
      final response = await _dio.get('/users/operator/salary/');
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      // Если endpoint не найден, возвращаем пустые данные
      if (e.response?.statusCode == 404) {
        return {
          'total_salary': '0',
          'salary_records': [],
          'orders': [],
        };
      }
      rethrow;
    }
  }
}


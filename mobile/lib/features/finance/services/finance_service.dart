import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/errors/app_exception.dart';

/// Провайдер сервиса финансов
final financeServiceProvider = Provider<FinanceService>((ref) {
  final dio = ref.watch(dioClientProvider);
  return FinanceService(dio);
});

/// Модели для отчетов
class SummaryReport {
  final double revenue;
  final double revenueFromServices;
  final double revenueFromEquipment;
  final double expenses;
  final double expensesFuel;
  final double expensesRepair;
  final double salaries;
  final double margin;
  final int ordersCount;
  final Map<String, String>? period;

  SummaryReport({
    required this.revenue,
    required this.revenueFromServices,
    required this.revenueFromEquipment,
    required this.expenses,
    required this.expensesFuel,
    required this.expensesRepair,
    required this.salaries,
    required this.margin,
    required this.ordersCount,
    this.period,
  });

  factory SummaryReport.fromJson(Map<String, dynamic> json) {
    // Безопасная обработка period - может содержать null значения
    Map<String, String>? periodMap;
    if (json['period'] != null && json['period'] is Map) {
      try {
        final periodData = json['period'] as Map;
        periodMap = <String, String>{};
        periodData.forEach((key, value) {
          if (value != null) {
            periodMap![key.toString()] = value.toString();
          }
        });
        // Если все значения null, устанавливаем period в null
        if (periodMap.isEmpty) {
          periodMap = null;
        }
      } catch (e) {
        periodMap = null;
      }
    }
    
    return SummaryReport(
      revenue: _safeParseDouble(json['revenue']) ?? 0.0,
      revenueFromServices: _safeParseDouble(json['revenue_from_services']) ?? 0.0,
      revenueFromEquipment: _safeParseDouble(json['revenue_from_equipment']) ?? 0.0,
      expenses: _safeParseDouble(json['expenses']) ?? 0.0,
      expensesFuel: _safeParseDouble(json['expenses_fuel']) ?? 0.0,
      expensesRepair: _safeParseDouble(json['expenses_repair']) ?? 0.0,
      salaries: _safeParseDouble(json['salaries']) ?? 0.0,
      margin: _safeParseDouble(json['margin']) ?? 0.0,
      ordersCount: (json['orders_count'] as num?)?.toInt() ?? 0,
      period: periodMap,
    );
  }
  
  static double? _safeParseDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    if (value is String) {
      if (value.isEmpty) return null;
      return double.tryParse(value);
    }
    return double.tryParse(value.toString());
  }
}

class EquipmentReportItem {
  final int equipmentId;
  final String equipmentName;
  final String code;
  final String status;
  final double totalHours;
  final double revenue;
  final double expenses;
  final double fuelExpenses;
  final double repairExpenses;

  EquipmentReportItem({
    required this.equipmentId,
    required this.equipmentName,
    required this.code,
    required this.status,
    required this.totalHours,
    required this.revenue,
    required this.expenses,
    required this.fuelExpenses,
    required this.repairExpenses,
  });

  factory EquipmentReportItem.fromJson(Map<String, dynamic> json) {
    return EquipmentReportItem(
      equipmentId: (json['equipment_id'] as num?)?.toInt() ?? 0,
      equipmentName: json['equipment_name'] as String? ?? '',
      code: json['code'] as String? ?? '',
      status: json['status'] as String? ?? '',
      totalHours: SummaryReport._safeParseDouble(json['total_hours']) ?? 0.0,
      revenue: SummaryReport._safeParseDouble(json['revenue']) ?? 0.0,
      expenses: SummaryReport._safeParseDouble(json['expenses']) ?? 0.0,
      fuelExpenses: SummaryReport._safeParseDouble(json['fuel_expenses']) ?? 0.0,
      repairExpenses: SummaryReport._safeParseDouble(json['repair_expenses']) ?? 0.0,
    );
  }
}

class EmployeeReportItem {
  final int userId;
  final String fullName;
  final double totalAmount;
  final double totalHours;
  final int assignments;

  EmployeeReportItem({
    required this.userId,
    required this.fullName,
    required this.totalAmount,
    required this.totalHours,
    required this.assignments,
  });

  factory EmployeeReportItem.fromJson(Map<String, dynamic> json) {
    return EmployeeReportItem(
      userId: (json['user_id'] as num?)?.toInt() ?? 0,
      fullName: json['full_name'] as String? ?? '',
      totalAmount: SummaryReport._safeParseDouble(json['total_amount']) ?? 0.0,
      totalHours: SummaryReport._safeParseDouble(json['total_hours']) ?? 0.0,
      assignments: (json['assignments'] as num?)?.toInt() ?? 0,
    );
  }
}

/// Сервис для работы с финансовыми отчетами
class FinanceService {
  final Dio _dio;

  FinanceService(this._dio);

  /// Получить общий отчет
  Future<SummaryReport> getSummaryReport({
    DateTime? dateFrom,
    DateTime? dateTo,
  }) async {
    try {
      final queryParams = <String, dynamic>{};
      if (dateFrom != null) {
        queryParams['from'] = dateFrom.toIso8601String().split('T')[0];
      }
      if (dateTo != null) {
        queryParams['to'] = dateTo.toIso8601String().split('T')[0];
      }

      final response = await _dio.get(
        '/reports/summary/',
        queryParameters: queryParams,
      );

      return SummaryReport.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw AppException.unknown('Ошибка при загрузке общего отчета: ${e.message ?? e.toString()}');
    } catch (e) {
      throw AppException.unknown('Ошибка при загрузке общего отчета: ${e.toString()}');
    }
  }

  /// Получить отчет по технике
  Future<List<EquipmentReportItem>> getEquipmentReport({
    DateTime? dateFrom,
    DateTime? dateTo,
  }) async {
    try {
      final queryParams = <String, dynamic>{};
      if (dateFrom != null) {
        queryParams['from'] = dateFrom.toIso8601String().split('T')[0];
      }
      if (dateTo != null) {
        queryParams['to'] = dateTo.toIso8601String().split('T')[0];
      }

      final response = await _dio.get(
        '/reports/equipment/',
        queryParameters: queryParams,
      );

      if (response.data is List) {
        return (response.data as List)
            .map((item) => EquipmentReportItem.fromJson(item as Map<String, dynamic>))
            .toList();
      }
      return [];
    } on DioException catch (e) {
      throw AppException.unknown('Ошибка при загрузке отчета по технике: ${e.message ?? e.toString()}');
    } catch (e) {
      throw AppException.unknown('Ошибка при загрузке отчета по технике: ${e.toString()}');
    }
  }

  /// Получить отчет по сотрудникам
  Future<List<EmployeeReportItem>> getEmployeesReport({
    DateTime? dateFrom,
    DateTime? dateTo,
  }) async {
    try {
      final queryParams = <String, dynamic>{};
      if (dateFrom != null) {
        queryParams['from'] = dateFrom.toIso8601String().split('T')[0];
      }
      if (dateTo != null) {
        queryParams['to'] = dateTo.toIso8601String().split('T')[0];
      }

      final response = await _dio.get(
        '/reports/employees/',
        queryParameters: queryParams,
      );

      if (response.data is List) {
        return (response.data as List)
            .map((item) => EmployeeReportItem.fromJson(item as Map<String, dynamic>))
            .toList();
      }
      return [];
    } on DioException catch (e) {
      throw AppException.unknown('Ошибка при загрузке отчета по сотрудникам: ${e.message ?? e.toString()}');
    } catch (e) {
      throw AppException.unknown('Ошибка при загрузке отчета по сотрудникам: ${e.toString()}');
    }
  }
}


from __future__ import annotations

from hashlib import md5
from typing import Optional

from django.core.cache import cache
from django.http import HttpResponse
from drf_spectacular.utils import extend_schema, OpenApiParameter, OpenApiResponse
from rest_framework import status
from rest_framework.response import Response
from rest_framework.views import APIView

from .exporters import build_dataset, export_dataset
from .reports import employees_report, equipment_report, summary_report


def clear_reports_cache():
    """Очищает весь кэш отчетов при изменении данных (завершение заявки и т.д.)"""
    try:
        # Получаем бэкенд кэша
        cache_backend = cache
        
        # Пытаемся использовать delete_pattern если доступен (django-redis)
        if hasattr(cache_backend, 'delete_pattern'):
            cache_backend.delete_pattern("report:*")
        elif hasattr(cache_backend, '_cache'):
            # Пытаемся получить доступ к Redis клиенту напрямую
            try:
                # Для django-redis
                if hasattr(cache_backend._cache, 'delete_pattern'):
                    cache_backend._cache.delete_pattern("report:*")
                elif hasattr(cache_backend._cache, 'client'):
                    # Прямой доступ к Redis клиенту
                    client = cache_backend._cache.client
                    # Используем SCAN для поиска всех ключей с префиксом
                    keys = []
                    cursor = 0
                    while True:
                        cursor, partial_keys = client.scan(cursor, match="report:*", count=100)
                        keys.extend(partial_keys)
                        if cursor == 0:
                            break
                    if keys:
                        client.delete(*keys)
            except (AttributeError, Exception):
                # Если не удалось очистить через pattern, используем версионирование
                # Устанавливаем новую версию кэша, что инвалидирует старые ключи
                # Для этого можно использовать отдельный ключ версии
                cache.set("report:cache_version", cache.get("report:cache_version", 0) + 1, timeout=None)
    except Exception as e:
        # Логируем ошибку, но не прерываем выполнение
        import logging
        logger = logging.getLogger(__name__)
        logger.warning(f"Failed to clear reports cache: {e}")


class BaseReportView(APIView):
    cache_namespace = "report"
    
    def check_permissions(self, request):
        """Проверка прав доступа к отчетам"""
        user = request.user
        if not user.is_authenticated:
            return False
        # Только админ может видеть отчеты
        return user.role == "admin" or user.is_superuser

    def get(self, request, *args, **kwargs):
        # Проверяем права доступа
        if not self.check_permissions(request):
            return Response(
                {"detail": "Доступ к отчетам разрешен только администраторам"},
                status=status.HTTP_403_FORBIDDEN
            )
        try:
            params = request.query_params
            cache_key = self._build_cache_key(request.path, params)
            data = cache.get(cache_key)
            if data is None:
                try:
                    data = self.generate_data(params)
                    cache.set(cache_key, data, timeout=60)
                except Exception as e:
                    import logging
                    logger = logging.getLogger(__name__)
                    logger.error(f"Error generating report data: {e}", exc_info=True)
                    # Возвращаем пустые данные вместо ошибки, чтобы не ломать UI
                    data = self._get_empty_data()
            export_format = params.get("export")
            if export_format:
                return self.export_response(data, export_format)
            return Response(data)
        except Exception as e:
            import logging
            logger = logging.getLogger(__name__)
            logger.error(f"Error generating report: {e}", exc_info=True)
            # Возвращаем пустые данные вместо ошибки
            try:
                return Response(self._get_empty_data())
            except:
                return Response(
                    {"detail": f"Ошибка при генерации отчета: {str(e)}"},
                    status=status.HTTP_500_INTERNAL_SERVER_ERROR
                )
    
    def _get_empty_data(self):
        """Возвращает пустые данные для отчета"""
        raise NotImplementedError("Subclasses must implement _get_empty_data")

    def generate_data(self, params):
        raise NotImplementedError

    def export_response(self, data, export_format: str):
        dataset, filename = self.dataset_from_data(data)
        binary, content_type, ext = export_dataset(dataset, export_format)
        response = HttpResponse(binary, content_type=content_type)
        response["Content-Disposition"] = f'attachment; filename="{filename}.{ext}"'
        return response

    def dataset_from_data(self, data):
        raise NotImplementedError

    def _build_cache_key(self, path: str, params) -> str:
        raw = f"{path}:{sorted(params.items())}"
        digest = md5(raw.encode("utf-8")).hexdigest()
        return f"{self.cache_namespace}:{digest}"


@extend_schema(
    summary="Общий отчёт",
    description="Получить общий финансовый отчёт за период (доходы, расходы, маржа). Требуется роль Admin.",
    parameters=[
        OpenApiParameter("from", str, description="Дата начала (YYYY-MM-DD)", required=False),
        OpenApiParameter("to", str, description="Дата окончания (YYYY-MM-DD)", required=False),
        OpenApiParameter("export", str, description="Формат экспорта (csv/xlsx/pdf)", required=False),
    ],
    responses={
        200: OpenApiResponse(description="Данные отчёта"),
    },
    tags=["Reports"],
)
class SummaryReportView(BaseReportView):
    cache_namespace = "report:summary"

    def generate_data(self, params):
        return summary_report(params.get("from"), params.get("to"))
    
    def _get_empty_data(self):
        """Возвращает пустые данные для общего отчета"""
        return {
            "revenue": "0",
            "revenue_from_services": "0",
            "revenue_from_services_details": {
                "total_amount": "0",
                "total_quantity": "0",
                "average_price_per_unit": "0",
            },
            "revenue_from_equipment": "0",
            "revenue_from_equipment_details": {
                "total_amount": "0",
                "total_hours": "0",
                "total_shifts": "0",
                "average_price_per_hour": "0",
            },
            "expenses": "0",
            "expenses_fuel": "0",
            "expenses_repair": "0",
            "salaries": "0",
            "margin": "0",
            "orders_count": 0,
            "period": {"from": None, "to": None},
        }

    def dataset_from_data(self, data):
        headers = ["metric", "value", "details"]
        rows = [
            ("Revenue", data["revenue"], ""),
            ("Revenue from Services", data["revenue_from_services"], 
             f"Total quantity: {data.get('revenue_from_services_details', {}).get('total_quantity', 'N/A')}, "
             f"Avg price per unit: {data.get('revenue_from_services_details', {}).get('average_price_per_unit', 'N/A')}"),
            ("Revenue from Equipment", data["revenue_from_equipment"],
             f"Total hours: {data.get('revenue_from_equipment_details', {}).get('total_hours', 'N/A')}, "
             f"Avg price per hour: {data.get('revenue_from_equipment_details', {}).get('average_price_per_hour', 'N/A')}"),
            ("Expenses", data["expenses"], ""),
            ("Expenses - Fuel", data.get("expenses_fuel", "0"), "Расходы на топливо"),
            ("Salaries", data["salaries"], ""),
            ("Margin", data["margin"], ""),
            ("Orders", data["orders_count"], ""),
        ]
        dataset = build_dataset(headers, rows)
        return dataset, "summary-report"


@extend_schema(
    summary="Отчёт по технике",
    description="Получить отчёт по технике (загрузка, часы работы, доходы, расходы). Требуется роль Admin.",
    parameters=[
        OpenApiParameter("from", str, description="Дата начала (YYYY-MM-DD)", required=False),
        OpenApiParameter("to", str, description="Дата окончания (YYYY-MM-DD)", required=False),
        OpenApiParameter("export", str, description="Формат экспорта (csv/xlsx/pdf)", required=False),
    ],
    responses={
        200: OpenApiResponse(description="Данные отчёта"),
    },
    tags=["Reports"],
)
class EquipmentReportView(BaseReportView):
    cache_namespace = "report:equipment"

    def generate_data(self, params):
        return equipment_report(params.get("from"), params.get("to"))
    
    def _get_empty_data(self):
        """Возвращает пустые данные для отчета по технике"""
        return []

    def dataset_from_data(self, data):
        headers = ["equipment_id", "name", "code", "status", "total_hours", "revenue", "expenses", "fuel_expenses"]
        rows = [
            (
                entry["equipment_id"],
                entry["equipment_name"],
                entry["code"],
                entry["status"],
                entry["total_hours"],
                entry["revenue"],
                entry["expenses"],
                entry.get("fuel_expenses", "0"),
            )
            for entry in data
        ]
        dataset = build_dataset(headers, rows)
        return dataset, "equipment-report"


@extend_schema(
    summary="Отчёт по сотрудникам",
    description="Получить отчёт по сотрудникам (выручка, часы, назначения). Требуется роль Admin.",
    parameters=[
        OpenApiParameter("from", str, description="Дата начала (YYYY-MM-DD)", required=False),
        OpenApiParameter("to", str, description="Дата окончания (YYYY-MM-DD)", required=False),
        OpenApiParameter("export", str, description="Формат экспорта (csv/xlsx/pdf)", required=False),
    ],
    responses={
        200: OpenApiResponse(description="Данные отчёта"),
    },
    tags=["Reports"],
)
class EmployeesReportView(BaseReportView):
    cache_namespace = "report:employees"

    def generate_data(self, params):
        return employees_report(params.get("from"), params.get("to"))
    
    def _get_empty_data(self):
        """Возвращает пустые данные для отчета по сотрудникам"""
        return []

    def dataset_from_data(self, data):
        headers = ["user_id", "full_name", "total_amount", "total_hours", "assignments"]
        rows = [
            (
                entry["user_id"],
                entry["full_name"],
                entry["total_amount"],
                entry["total_hours"],
                entry["assignments"],
            )
            for entry in data
        ]
        dataset = build_dataset(headers, rows)
        return dataset, "employees-report"


"""
Prometheus metrics для мониторинга приложения.
"""
from __future__ import annotations

from prometheus_client import Counter, Histogram, Gauge, generate_latest
from django.http import HttpResponse
from django.views.decorators.http import require_http_methods


# Метрики для HTTP запросов
http_requests_total = Counter(
    "http_requests_total",
    "Total number of HTTP requests",
    ["method", "endpoint", "status_code"],
)

http_request_duration_seconds = Histogram(
    "http_request_duration_seconds",
    "HTTP request duration in seconds",
    ["method", "endpoint"],
    buckets=[0.01, 0.05, 0.1, 0.2, 0.5, 1.0, 2.0, 5.0, 10.0],
)

# Метрики для Celery задач
celery_tasks_total = Counter(
    "celery_tasks_total",
    "Total number of Celery tasks",
    ["task_name", "status"],
)

celery_task_duration_seconds = Histogram(
    "celery_task_duration_seconds",
    "Celery task duration in seconds",
    ["task_name"],
    buckets=[1.0, 5.0, 10.0, 30.0, 60.0, 300.0, 600.0],
)

celery_queue_length = Gauge(
    "celery_queue_length",
    "Number of tasks in Celery queue",
    ["queue_name"],
)

# Метрики для базы данных
db_connections_active = Gauge(
    "db_connections_active",
    "Number of active database connections",
)

db_query_duration_seconds = Histogram(
    "db_query_duration_seconds",
    "Database query duration in seconds",
    ["operation"],
    buckets=[0.001, 0.005, 0.01, 0.05, 0.1, 0.5, 1.0, 5.0],
)

# Метрики для бизнес-логики
orders_created_total = Counter(
    "orders_created_total",
    "Total number of orders created",
    ["status"],
)

orders_status_changes_total = Counter(
    "orders_status_changes_total",
    "Total number of order status changes",
    ["from_status", "to_status"],
)

invoices_generated_total = Counter(
    "invoices_generated_total",
    "Total number of invoices generated",
)

# Метрики для ошибок
errors_total = Counter(
    "errors_total",
    "Total number of errors",
    ["error_type", "endpoint"],
)


@require_http_methods(["GET"])
def metrics_view(request):
    """
    Endpoint для Prometheus метрик.
    Доступ: /metrics
    """
    return HttpResponse(
        generate_latest(),
        content_type="text/plain; version=0.0.4; charset=utf-8",
    )


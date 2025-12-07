"""
Middleware для сбора Prometheus метрик HTTP запросов.
"""
from __future__ import annotations

import time
from typing import Callable

from django.http import HttpRequest, HttpResponse
from ringo_backend.prometheus import (
    http_requests_total,
    http_request_duration_seconds,
    errors_total,
)


class PrometheusMetricsMiddleware:
    """
    Middleware для сбора метрик HTTP запросов.
    """

    def __init__(self, get_response: Callable):
        self.get_response = get_response

    def __call__(self, request: HttpRequest) -> HttpResponse:
        start_time = time.time()
        
        # Получаем response
        response = self.get_response(request)
        
        # Вычисляем длительность запроса
        duration = time.time() - start_time
        
        # Извлекаем endpoint (без query параметров)
        endpoint = request.path
        if len(endpoint) > 100:  # Ограничиваем длину для метрик
            endpoint = endpoint[:100]
        
        # Метки для метрик
        method = request.method
        status_code = str(response.status_code)
        
        # Записываем метрики
        http_requests_total.labels(
            method=method,
            endpoint=endpoint,
            status_code=status_code,
        ).inc()
        
        http_request_duration_seconds.labels(
            method=method,
            endpoint=endpoint,
        ).observe(duration)
        
        # Записываем ошибки
        if response.status_code >= 400:
            errors_total.labels(
                error_type=f"http_{response.status_code}",
                endpoint=endpoint,
            ).inc()
        
        return response


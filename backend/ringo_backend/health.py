"""
Health check endpoint для мониторинга состояния API.
Используется в load balancer, CI/CD и системах мониторинга.
"""
from __future__ import annotations

from django.db import connection
from django.http import JsonResponse
from django.views.decorators.http import require_http_methods
from django.views.decorators.cache import never_cache

import redis
from celery import current_app


@never_cache
@require_http_methods(["GET"])
def health_check(request):
    """
    Health check endpoint.
    
    Returns:
        - 200 OK: Все системы работают
        - 503 Service Unavailable: Проблемы с зависимостями
    """
    status = {
        "status": "healthy",
        "service": "ringo-backend",
        "version": "1.0.0",
    }
    
    checks = {}
    overall_healthy = True
    
    # Проверка базы данных
    try:
        with connection.cursor() as cursor:
            cursor.execute("SELECT 1")
            cursor.fetchone()
        checks["database"] = {"status": "healthy"}
    except Exception as e:
        checks["database"] = {"status": "unhealthy", "error": str(e)}
        overall_healthy = False
    
    # Проверка Redis (Celery broker)
    try:
        broker_url = current_app.conf.broker_url
        if broker_url.startswith("redis://"):
            # Извлекаем параметры подключения из URL
            import urllib.parse
            parsed = urllib.parse.urlparse(broker_url)
            redis_client = redis.Redis(
                host=parsed.hostname or "localhost",
                port=parsed.port or 6379,
                db=int(parsed.path.lstrip("/")) if parsed.path else 0,
                socket_connect_timeout=2,
            )
            redis_client.ping()
            checks["redis"] = {"status": "healthy"}
        else:
            checks["redis"] = {"status": "unknown", "message": "Non-redis broker"}
    except Exception as e:
        checks["redis"] = {"status": "unhealthy", "error": str(e)}
        overall_healthy = False
    
    # Проверка Celery workers
    try:
        inspect = current_app.control.inspect()
        active_workers = inspect.active()
        if active_workers:
            checks["celery"] = {
                "status": "healthy",
                "active_workers": len(active_workers),
            }
        else:
            checks["celery"] = {"status": "warning", "message": "No active workers"}
    except Exception as e:
        checks["celery"] = {"status": "unhealthy", "error": str(e)}
        # Не считаем это критичным для health check
        # overall_healthy = False
    
    status["checks"] = checks
    
    if not overall_healthy:
        status["status"] = "unhealthy"
        return JsonResponse(status, status=503)
    
    return JsonResponse(status, status=200)


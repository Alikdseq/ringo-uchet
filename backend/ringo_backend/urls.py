from __future__ import annotations

from django.contrib import admin
from django.urls import include, path
from drf_spectacular.views import SpectacularAPIView, SpectacularRedocView, SpectacularSwaggerView

from ringo_backend.health import health_check
from ringo_backend.prometheus import metrics_view

# Импортируем admin.py для отключения токенов в админке
import ringo_backend.admin  # noqa: F401

# Убрано из админки по требованию - токены не нужны в админке
# import ringo_backend.token_blacklist_admin  # noqa: F401

# Настройка админ-сайта на русский
admin.site.site_header = "Администрирование Ringo Uchet"
admin.site.site_title = "Ringo Uchet"
admin.site.index_title = "Панель управления"

urlpatterns = [
    path("admin/", admin.site.urls),
    # Health check endpoint для load balancer и мониторинга
    path("api/health/", health_check, name="health_check"),
    # Prometheus metrics endpoint
    path("metrics", metrics_view, name="prometheus_metrics"),
    # API v1
    path("api/v1/", include("ringo_backend.api_urls")),
    # OpenAPI Schema
    path("api/schema/", SpectacularAPIView.as_view(), name="schema"),
    # Swagger UI
    path("api/docs/", SpectacularSwaggerView.as_view(url_name="schema"), name="swagger-ui"),
    # ReDoc
    path("api/redoc/", SpectacularRedocView.as_view(url_name="schema"), name="redoc"),
]


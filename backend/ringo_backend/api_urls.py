from __future__ import annotations

from django.urls import include, path
from rest_framework.routers import DefaultRouter
from rest_framework_simplejwt.views import TokenRefreshView, TokenBlacklistView

from catalog.views import AttachmentViewSet, EquipmentViewSet, MaterialItemViewSet, ServiceItemViewSet
from crm.views import ClientViewSet
from finance.api import EmployeesReportView, EquipmentReportView, SummaryReportView
from orders.views import OrderViewSet
from users.views import (
    CustomTokenObtainPairView,
    current_user_view,
    operators_list_view,
    operator_salary_view,
    change_password_view,
    register_view,
)

router = DefaultRouter()
router.register(r"equipment", EquipmentViewSet, basename="equipment")
router.register(r"services", ServiceItemViewSet, basename="services")
router.register(r"materials", MaterialItemViewSet, basename="materials")
router.register(r"attachments", AttachmentViewSet, basename="attachments")
router.register(r"clients", ClientViewSet, basename="clients")
router.register(r"orders", OrderViewSet, basename="orders")

urlpatterns = [
    # JWT Authentication endpoints
    path("token/", CustomTokenObtainPairView.as_view(), name="token_obtain_pair"),
    path("token/refresh/", TokenRefreshView.as_view(), name="token_refresh"),
    path("token/blacklist/", TokenBlacklistView.as_view(), name="token_blacklist"),
    # User endpoints
    path("users/register/", register_view, name="register"),
    path("users/me/", current_user_view, name="current_user"),
    path("users/operators/", operators_list_view, name="operators_list"),
    path("users/operator/salary/", operator_salary_view, name="operator_salary"),
    path("users/change-password/", change_password_view, name="change_password"),
    # API routes
    path("", include(router.urls)),
    path("reports/summary/", SummaryReportView.as_view(), name="reports-summary"),
    path("reports/equipment/", EquipmentReportView.as_view(), name="reports-equipment"),
    path("reports/employees/", EmployeesReportView.as_view(), name="reports-employees"),
    path("notifications/", include("notifications.urls")),
]


from __future__ import annotations

from rest_framework import permissions


class IsOwnerOrManager(permissions.BasePermission):
    """
    Разрешение: администратор и менеджер видят все заявки.
    Оператор видит только назначенные ему заявки.
    """

    def has_permission(self, request, view):
        user = request.user
        if not user or not user.is_authenticated:
            return False
        return (
            getattr(user, "role", None) in ("admin", "manager", "operator")
            or user.is_superuser
        )

    def has_object_permission(self, request, view, obj):
        user = request.user
        if not user or not user.is_authenticated:
            return False

        # Админ видит всё
        if user.role == "admin" or user.is_superuser:
            return True

        # Менеджер видит все заявки (как администратор)
        if user.role == "manager":
            return True

        # Оператор — только назначенные ему заявки (M2M operators и/или legacy FK)
        if user.role == "operator":
            in_operators = False
            if hasattr(obj, "operators"):
                try:
                    in_operators = obj.operators.filter(id=user.id).exists()
                except Exception:
                    in_operators = False
            if in_operators:
                return True
            # Обратная совместимость: старое поле operator
            operator_id = getattr(obj, "operator_id", None)
            if operator_id is not None and operator_id == user.id:
                return True
            operator = getattr(obj, "operator", None)
            if operator is not None and operator == user:
                return True
            return False

        return False


class IsManagerOrAdmin(permissions.BasePermission):
    """Разрешение: только менеджер или админ"""

    def has_permission(self, request, view):
        user = request.user
        if not user or not user.is_authenticated:
            return False
        return user.role in ["admin", "manager"] or user.is_superuser


class IsOperatorOrAbove(permissions.BasePermission):
    """Разрешение: оператор и выше (оператор, менеджер, админ)"""

    def has_permission(self, request, view):
        user = request.user
        if not user or not user.is_authenticated:
            return False
        return user.role in ["admin", "manager", "operator"] or user.is_superuser


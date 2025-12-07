from __future__ import annotations

from rest_framework import permissions


class IsOwnerOrManager(permissions.BasePermission):
    """
    Разрешение: администратор и менеджер видят все заявки.
    Оператор видит только назначенные ему заявки.
    """

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

        # Оператор видит только назначенные ему заявки
        if user.role == "operator":
            if hasattr(obj, "operators"):
                # Проверяем, есть ли пользователь в operators
                return obj.operators.filter(id=user.id).exists()
            # Для обратной совместимости проверяем старый operator
            if hasattr(obj, "operator"):
                return obj.operator == user
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


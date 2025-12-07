from __future__ import annotations

from functools import wraps
from typing import Iterable

from django.http import HttpResponseForbidden
from rest_framework.permissions import BasePermission
from rest_framework.request import Request
from rest_framework.views import APIView


def role_required(*roles: str):
    """
    Decorator for function-based views.
    """

    def decorator(view_func):
        @wraps(view_func)
        def _wrapped(request: Request, *args, **kwargs):
            user = request.user
            if not user.is_authenticated or (roles and getattr(user, "role", None) not in roles):
                return HttpResponseForbidden("Insufficient role permissions")
            return view_func(request, *args, **kwargs)

        return _wrapped

    return decorator


class RolePermission(BasePermission):
    """
    DRF permission class that checks allowed roles on API views.
    """

    allowed_roles: Iterable[str] = ()

    def has_permission(self, request: Request, view: APIView) -> bool:
        if not request.user or not request.user.is_authenticated:
            return False
        allowed = getattr(view, "allowed_roles", None) or self.allowed_roles
        if not allowed:
            return True
        return request.user.role in allowed


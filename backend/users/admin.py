from __future__ import annotations

from django.contrib import admin
from django.contrib.auth.admin import UserAdmin

from .models import User


@admin.register(User)
class CustomUserAdmin(UserAdmin):
    list_display = ("id", "full_name", "email", "phone", "role", "is_active", "last_login")
    list_filter = ("role", "is_active", "is_staff")
    search_fields = ("email", "phone", "first_name", "last_name")
    ordering = ("email",)
    fieldsets = UserAdmin.fieldsets + (
        (
            "Профиль",
            {
                "fields": (
                    "role",
                    "phone",
                    "avatar",
                    "locale",
                    "position",
                    "permissions_snapshot",
                )
            },
        ),
    )

    def full_name(self, obj: User) -> str:
        return obj.get_full_name() or "-"

    full_name.short_description = "ФИО"


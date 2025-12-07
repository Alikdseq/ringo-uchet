from __future__ import annotations

from django.contrib import admin

from .models import Client


@admin.register(Client)
class ClientAdmin(admin.ModelAdmin):
    list_display = ("name", "contact_person", "phone", "email", "city", "is_active")
    search_fields = ("name", "contact_person", "phone", "email", "inn", "kpp")
    list_filter = ("is_active", "city")
    ordering = ("name",)


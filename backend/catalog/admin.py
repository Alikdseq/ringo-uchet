from __future__ import annotations

from django.contrib import admin

from .models import (
    AttachmentMaterialItem,
    Equipment,
    MaterialItem,
    SoilItem,
    ServiceItem,
    ToolItem,
)


@admin.register(Equipment)
class EquipmentAdmin(admin.ModelAdmin):
    list_display = ("code", "name", "status", "hourly_rate", "daily_rate", "last_maintenance_date")
    list_filter = ("status",)
    search_fields = ("code", "name", "description")
    ordering = ("code",)


@admin.register(ServiceItem)
class ServiceItemAdmin(admin.ModelAdmin):
    list_display = ("name", "category", "unit", "is_active")
    list_filter = ("category", "is_active")
    search_fields = ("name", "category__name")
    exclude = ("price",)  # Убираем поле цены, так как услуги не имеют фиксированной цены


class MaterialItemAdmin(admin.ModelAdmin):
    """Базовый админ для материалов. Не регистрируется напрямую, чтобы не было общего раздела 'Материалы'."""

    list_display = ("name", "category", "unit", "price", "supplier", "is_active")
    list_filter = ("category", "is_active")
    search_fields = ("name", "supplier")
    ordering = ("category", "name")


@admin.register(SoilItem)
class SoilItemAdmin(MaterialItemAdmin):
    """Отдельный раздел номенклатуры для грунта."""

    def get_queryset(self, request):
        qs = super().get_queryset(request)
        return qs.filter(category=MaterialItem.MaterialCategory.SOIL)


@admin.register(ToolItem)
class ToolItemAdmin(MaterialItemAdmin):
    """Отдельный раздел номенклатуры для инструмента."""

    def get_queryset(self, request):
        qs = super().get_queryset(request)
        return qs.filter(category=MaterialItem.MaterialCategory.TOOL)


@admin.register(AttachmentMaterialItem)
class AttachmentMaterialItemAdmin(MaterialItemAdmin):
    """Отдельный раздел номенклатуры для навески (из каталога материалов)."""

    list_display = ("name", "unit", "price", "supplier", "is_active")
    list_filter = ("is_active",)
    search_fields = ("name", "supplier")
    ordering = ("name",)
    
    # Скрываем поле category, так как в этом разделе только навески
    exclude = ("category",)
    readonly_fields = ("created_at", "updated_at")
    
    def get_queryset(self, request):
        qs = super().get_queryset(request)
        return qs.filter(category=MaterialItem.MaterialCategory.ATTACHMENT)
    
    def save_model(self, request, obj, form, change):
        """Автоматически устанавливаем категорию 'attachment' и единицу измерения 'шт' при сохранении"""
        obj.category = MaterialItem.MaterialCategory.ATTACHMENT
        # Если единица измерения не указана, устанавливаем 'шт' по умолчанию для навесок
        if not obj.unit:
            obj.unit = "шт"
        super().save_model(request, obj, form, change)
    
    def get_form(self, request, obj=None, **kwargs):
        """Переопределяем форму, чтобы установить default для unit"""
        form = super().get_form(request, obj, **kwargs)
        # Устанавливаем значение по умолчанию для unit в форме
        if obj is None:  # Только при создании нового объекта
            form.base_fields['unit'].initial = "шт"
        return form


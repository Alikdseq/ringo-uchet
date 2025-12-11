from __future__ import annotations

from rest_framework import serializers

from .models import (
    Attachment,
    Equipment,
    MaintenanceRecord,
    MaterialItem,
    ServiceCategory,
    ServiceItem,
)


class EquipmentSerializer(serializers.ModelSerializer):
    class Meta:
        model = Equipment
        fields = "__all__"
        read_only_fields = ("created_at", "updated_at")


class ServiceCategorySerializer(serializers.ModelSerializer):
    class Meta:
        model = ServiceCategory
        fields = "__all__"
        read_only_fields = ("created_at", "updated_at")


class ServiceItemSerializer(serializers.ModelSerializer):
    category = ServiceCategorySerializer(read_only=True)
    category_id = serializers.PrimaryKeyRelatedField(
        queryset=ServiceCategory.objects.all(), source="category", write_only=True, required=False, allow_null=True
    )

    class Meta:
        model = ServiceItem
        fields = (
            "id",
            "name",
            "unit",
            "price",
            "default_duration",
            "included_items",
            "is_active",
            "category",
            "category_id",
            "created_at",
            "updated_at",
        )
        read_only_fields = ("created_at", "updated_at", "category")
    
    def validate(self, attrs):
        """Валидация данных при создании/обновлении услуги"""
        # Если category не указана при создании, создаем или получаем категорию по умолчанию
        if self.instance is None and 'category' not in attrs:
            # Создаем или получаем категорию "Прочее" по умолчанию
            default_category, _ = ServiceCategory.objects.get_or_create(
                name="Прочее",
                defaults={"description": "Категория по умолчанию для услуг без категории"}
            )
            attrs['category'] = default_category
        # При обновлении, если category_id не указан, сохраняем существующую категорию
        elif self.instance is not None and 'category' not in attrs:
            # При обновлении сохраняем существующую категорию
            pass
        return attrs
    
    def create(self, validated_data):
        """Создание услуги с обработкой категории"""
        # Убеждаемся, что category установлена
        if 'category' not in validated_data:
            default_category, _ = ServiceCategory.objects.get_or_create(
                name="Прочее",
                defaults={"description": "Категория по умолчанию для услуг без категории"}
            )
            validated_data['category'] = default_category
        return super().create(validated_data)


class MaterialItemSerializer(serializers.ModelSerializer):
    class Meta:
        model = MaterialItem
        fields = "__all__"
        read_only_fields = ("created_at", "updated_at")


class AttachmentSerializer(serializers.ModelSerializer):
    equipment_name = serializers.CharField(source='equipment.name', read_only=True)
    equipment_code = serializers.CharField(source='equipment.code', read_only=True)
    
    class Meta:
        model = Attachment
        fields = "__all__"
        read_only_fields = ("created_at", "updated_at")


class MaintenanceRecordSerializer(serializers.ModelSerializer):
    class Meta:
        model = MaintenanceRecord
        fields = "__all__"
        read_only_fields = ("created_at", "updated_at")


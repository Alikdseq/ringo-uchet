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
        queryset=ServiceCategory.objects.all(), source="category", write_only=True, required=True
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
        # Проверяем, что category_id указан при создании
        if self.instance is None:
            # При создании category обязательна (через category_id)
            # Проверяем в attrs (после обработки PrimaryKeyRelatedField) и в initial_data
            if 'category' not in attrs:
                # Если category не в attrs, проверяем initial_data
                if hasattr(self, 'initial_data') and self.initial_data:
                    category_id = self.initial_data.get('category_id')
                    if not category_id:
                        raise serializers.ValidationError({"category_id": "Категория обязательна для указания"})
                else:
                    raise serializers.ValidationError({"category_id": "Категория обязательна для указания"})
        return attrs


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


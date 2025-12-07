from __future__ import annotations

from rest_framework import serializers

from notifications.models import DeviceToken, NotificationLog, NotificationSubscription


class DeviceTokenSerializer(serializers.ModelSerializer):
    class Meta:
        model = DeviceToken
        fields = ["id", "token", "platform", "app_version", "device_info"]
        read_only_fields = ["id", "last_active_at", "created_at"]


class NotificationSubscriptionSerializer(serializers.ModelSerializer):
    class Meta:
        model = NotificationSubscription
        fields = ["id", "channel", "endpoint", "enabled", "preferences"]
        read_only_fields = ["id", "created_at", "updated_at"]


class NotificationPreferenceSerializer(serializers.Serializer):
    """Сериализатор для настроек уведомлений по ролям"""
    order_created = serializers.BooleanField(default=True)
    status_changed = serializers.BooleanField(default=True)
    payment_received = serializers.BooleanField(default=True)
    invoice_ready = serializers.BooleanField(default=True)
    kassa_full = serializers.BooleanField(default=True)


from __future__ import annotations

from rest_framework import status
from rest_framework.decorators import action
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from rest_framework.viewsets import ModelViewSet, ViewSet

from notifications.models import DeviceToken, NotificationLog, NotificationSubscription
from notifications.serializers import (
    DeviceTokenSerializer,
    NotificationPreferenceSerializer,
    NotificationSubscriptionSerializer,
)


class DeviceTokenViewSet(ModelViewSet):
    """Регистрация и управление FCM device tokens"""
    serializer_class = DeviceTokenSerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        return DeviceToken.objects.filter(user=self.request.user)

    def perform_create(self, serializer):
        token = serializer.validated_data.get("token")
        platform = serializer.validated_data.get("platform")

        # Обновляем существующий токен или создаём новый
        device_token, created = DeviceToken.objects.update_or_create(
            token=token,
            defaults={
                "user": self.request.user,
                "platform": platform,
                "app_version": serializer.validated_data.get("app_version", ""),
                "device_info": serializer.validated_data.get("device_info", {}),
            },
        )
        return device_token


class NotificationSubscriptionViewSet(ModelViewSet):
    """Управление подписками на уведомления"""
    serializer_class = NotificationSubscriptionSerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        return NotificationSubscription.objects.filter(user=self.request.user)

    def perform_create(self, serializer):
        serializer.save(user=self.request.user)


class NotificationPreferenceViewSet(ViewSet):
    """Preference center для настройки уведомлений"""
    permission_classes = [IsAuthenticated]

    @action(detail=False, methods=["get", "post"])
    def preferences(self, request):
        """Получить/обновить настройки уведомлений"""
        if request.method == "GET":
            # Получаем текущие preferences из NotificationSubscription
            subscriptions = NotificationSubscription.objects.filter(user=request.user)
            prefs = {}
            for sub in subscriptions:
                prefs.update(sub.preferences or {})

            serializer = NotificationPreferenceSerializer(prefs)
            return Response(serializer.data)

        # POST - обновление preferences
        serializer = NotificationPreferenceSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)

        # Сохраняем preferences для каждого канала
        for channel in ["push", "email", "telegram", "sms"]:
            subscription, _ = NotificationSubscription.objects.get_or_create(
                user=request.user,
                channel=channel,
                defaults={"endpoint": "", "enabled": True},
            )
            subscription.preferences = serializer.validated_data
            subscription.save(update_fields=["preferences"])

        return Response(serializer.data, status=status.HTTP_200_OK)

    @action(detail=False, methods=["get"])
    def logs(self, request):
        """История уведомлений пользователя"""
        logs = NotificationLog.objects.filter(user=request.user).order_by("-created_at")[:50]
        return Response(
            [
                {
                    "id": log.id,
                    "channel": log.channel,
                    "event_type": log.event_type,
                    "status": log.status,
                    "sent_at": log.sent_at,
                    "error_message": log.error_message,
                    "created_at": log.created_at,
                }
                for log in logs
            ]
        )


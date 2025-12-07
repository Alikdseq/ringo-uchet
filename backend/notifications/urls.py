from __future__ import annotations

from django.urls import path
from rest_framework.routers import DefaultRouter

from notifications.views import (
    DeviceTokenViewSet,
    NotificationPreferenceViewSet,
    NotificationSubscriptionViewSet,
)

router = DefaultRouter()
router.register(r"device-tokens", DeviceTokenViewSet, basename="device-token")
router.register(r"subscriptions", NotificationSubscriptionViewSet, basename="subscription")
router.register(r"preferences", NotificationPreferenceViewSet, basename="preference")

urlpatterns = router.urls


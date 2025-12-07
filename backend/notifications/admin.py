from __future__ import annotations

from django.contrib import admin

# Убрано из админки по требованию
# from notifications.models import DeviceToken, NotificationLog, NotificationSubscription


# @admin.register(DeviceToken)
# class DeviceTokenAdmin(admin.ModelAdmin):
#     list_display = ["token", "user", "platform", "app_version", "last_active_at", "created_at"]
#     list_filter = ["platform", "created_at"]
#     search_fields = ["token", "user__phone", "user__email"]
#     readonly_fields = ["created_at", "last_active_at"]


# @admin.register(NotificationSubscription)
# class NotificationSubscriptionAdmin(admin.ModelAdmin):
#     list_display = ["user", "channel", "endpoint", "enabled", "last_used_at", "created_at"]
#     list_filter = ["channel", "enabled", "created_at"]
#     search_fields = ["user__phone", "user__email", "endpoint"]
#     readonly_fields = ["created_at", "updated_at", "last_used_at"]


# @admin.register(NotificationLog)
# class NotificationLogAdmin(admin.ModelAdmin):
#     list_display = ["user", "channel", "event_type", "status", "retry_count", "sent_at", "created_at"]
#     list_filter = ["channel", "status", "event_type", "created_at"]
#     search_fields = ["user__phone", "user__email", "endpoint", "event_type"]
#     readonly_fields = ["created_at", "sent_at", "error_message", "payload"]
#     ordering = ["-created_at"]


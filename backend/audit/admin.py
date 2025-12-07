from __future__ import annotations

from django.contrib import admin

# Убрано из админки по требованию
# from audit.models import AuditLog


# @admin.register(AuditLog)
# class AuditLogAdmin(admin.ModelAdmin):
#     list_display = ["actor", "action", "entity_type", "entity_id", "ip_address", "created_at"]
#     list_filter = ["action", "entity_type", "created_at"]
#     search_fields = ["actor__phone", "actor__email", "entity_id", "request_id", "ip_address"]
#     readonly_fields = ["actor", "action", "entity_type", "entity_id", "payload", "ip_address", "user_agent", "request_id", "created_at"]
#     ordering = ["-created_at"]
#     date_hierarchy = "created_at"
#
#     def has_add_permission(self, request):
#         return False
#
#     def has_change_permission(self, request, obj=None):
#         return False
#
#     def has_delete_permission(self, request, obj=None):
#         # Только админы могут удалять логи (для GDPR compliance)
#         return request.user.is_superuser


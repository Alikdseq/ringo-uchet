from __future__ import annotations

import logging

from django.db.models.signals import post_delete, post_save, pre_save
from django.dispatch import receiver

from audit.models import AuditAction
from audit.services import log_action

logger = logging.getLogger(__name__)


def get_client_ip(request) -> str | None:
    """Получение IP адреса клиента из request"""
    if not request:
        return None
    x_forwarded_for = request.META.get("HTTP_X_FORWARDED_FOR")
    if x_forwarded_for:
        ip = x_forwarded_for.split(",")[0]
    else:
        ip = request.META.get("REMOTE_ADDR")
    return ip


def get_user_agent(request) -> str | None:
    """Получение User Agent из request"""
    if not request:
        return None
    return request.META.get("HTTP_USER_AGENT", "")


# Глобальный словарь для хранения старых значений перед сохранением
_pre_save_data = {}


@receiver(pre_save)
def store_pre_save_data(sender, instance, **kwargs):
    """Сохраняем старые значения перед обновлением"""
    if hasattr(instance, "pk") and instance.pk:
        try:
            old_instance = sender.objects.get(pk=instance.pk)
            _pre_save_data[id(instance)] = {
                field.name: getattr(old_instance, field.name, None)
                for field in sender._meta.fields
                if field.name not in ["created_at", "updated_at", "last_login"]
            }
        except sender.DoesNotExist:
            pass


@receiver(post_save)
def log_model_changes(sender, instance, created, **kwargs):
    """Автоматическое логирование изменений моделей"""
    # Исключаем системные модели
    if sender._meta.app_label in ["admin", "auth", "contenttypes", "sessions", "audit"]:
        return
    
    # Исключаем во время миграций (проверяем, что таблица существует)
    from django.db import connection
    try:
        with connection.cursor() as cursor:
            cursor.execute("""
                SELECT EXISTS (
                    SELECT FROM information_schema.tables 
                    WHERE table_schema = 'public' AND table_name = 'audit_auditlog'
                );
            """)
            table_exists = cursor.fetchone()[0]
            if not table_exists:
                return
    except Exception:
        # Если не можем проверить, пропускаем логирование (вероятно, миграции)
        return

    # Получаем request из thread-local (если доступен)
    from django.utils.functional import SimpleLazyObject

    request = None
    try:
        from django.contrib.auth.middleware import get_user

        request = getattr(SimpleLazyObject(lambda: None), "_request", None)
    except Exception:
        pass

    actor = None
    ip_address = None
    user_agent = None
    request_id = None

    if request and hasattr(request, "user"):
        actor = request.user if request.user.is_authenticated else None
        ip_address = get_client_ip(request)
        user_agent = get_user_agent(request)
        request_id = getattr(request, "request_id", None)

    entity_type = sender.__name__
    entity_id = str(instance.pk) if hasattr(instance, "pk") and instance.pk else "new"

    if created:
        action = AuditAction.CREATE
        payload = {
            "fields": {field.name: str(getattr(instance, field.name, None)) for field in sender._meta.fields if hasattr(instance, field.name)},
        }
    else:
        action = AuditAction.UPDATE
        old_data = _pre_save_data.pop(id(instance), {})
        changed_fields = {}
        for field_name, old_value in old_data.items():
            new_value = getattr(instance, field_name, None)
            if old_value != new_value:
                changed_fields[field_name] = {"old": str(old_value), "new": str(new_value)}
        payload = {"changed_fields": changed_fields}

    try:
        log_action(
            actor=actor,
            action=action,
            entity_type=entity_type,
            entity_id=entity_id,
            payload=payload,
            ip_address=ip_address,
            user_agent=user_agent,
            request_id=request_id,
        )
    except Exception as e:
        logger.error(f"Failed to log audit action: {e}", exc_info=True)


@receiver(post_delete)
def log_model_deletion(sender, instance, **kwargs):
    """Логирование удаления моделей"""
    if sender._meta.app_label in ["admin", "auth", "contenttypes", "sessions", "audit"]:
        return
    
    # Исключаем во время миграций (проверяем, что таблица существует)
    from django.db import connection
    try:
        with connection.cursor() as cursor:
            cursor.execute("""
                SELECT EXISTS (
                    SELECT FROM information_schema.tables 
                    WHERE table_schema = 'public' AND table_name = 'audit_auditlog'
                );
            """)
            table_exists = cursor.fetchone()[0]
            if not table_exists:
                return
    except Exception:
        # Если не можем проверить, пропускаем логирование (вероятно, миграции)
        return

    from django.utils.functional import SimpleLazyObject

    request = None
    try:
        from django.contrib.auth.middleware import get_user

        request = getattr(SimpleLazyObject(lambda: None), "_request", None)
    except Exception:
        pass

    actor = None
    ip_address = None
    user_agent = None
    request_id = None

    if request and hasattr(request, "user"):
        actor = request.user if request.user.is_authenticated else None
        ip_address = get_client_ip(request)
        user_agent = get_user_agent(request)
        request_id = getattr(request, "request_id", None)

    entity_type = sender.__name__
    entity_id = str(instance.pk) if hasattr(instance, "pk") else "unknown"

    try:
        log_action(
            actor=actor,
            action=AuditAction.DELETE,
            entity_type=entity_type,
            entity_id=entity_id,
            payload={"deleted_object": str(instance)},
            ip_address=ip_address,
            user_agent=user_agent,
            request_id=request_id,
        )
    except Exception as e:
        logger.error(f"Failed to log audit deletion: {e}", exc_info=True)


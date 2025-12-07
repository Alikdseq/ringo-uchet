from __future__ import annotations

from typing import Any

from audit.models import AuditAction, AuditLog


def log_action(
    actor: Any | None,
    action: AuditAction | str,
    entity_type: str,
    entity_id: str | int,
    payload: dict | None = None,
    ip_address: str | None = None,
    user_agent: str | None = None,
    request_id: str | None = None,
) -> AuditLog:
    """
    Универсальная функция для логирования действий в AuditLog.

    Args:
        actor: Пользователь (User instance или None для системных действий)
        action: Тип действия (AuditAction enum или строка)
        entity_type: Тип сущности (Order, Invoice, User, etc.)
        entity_id: ID сущности (может быть UUID строкой)
        payload: Дополнительные данные (изменённые поля, значения)
        ip_address: IP адрес запроса
        user_agent: User agent браузера/клиента
        request_id: Request ID для трейсинга

    Returns:
        AuditLog: Созданная запись лога
    """
    if isinstance(action, str):
        # Проверяем что это валидный action
        try:
            action = AuditAction(action)
        except ValueError:
            # Если не валидный, используем как есть (для расширяемости)
            pass

    return AuditLog.objects.create(
        actor=actor,
        action=action,
        entity_type=entity_type,
        entity_id=str(entity_id),
        payload=payload or {},
        ip_address=ip_address,
        user_agent=user_agent or "",
        request_id=request_id or "",
    )


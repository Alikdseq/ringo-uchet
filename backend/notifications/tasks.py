from __future__ import annotations

import logging

from celery import shared_task
from django.conf import settings
from django.utils import timezone

from notifications.models import DeviceToken, NotificationLog, NotificationSubscription
from notifications.services import EmailService, FCMService, SMSService, TelegramService

logger = logging.getLogger(__name__)


@shared_task(bind=True, max_retries=3, default_retry_delay=60)
def send_notification_task(
    self,
    user_id: int | None,
    event_type: str,
    channel: str,
    title: str,
    body: str,
    data: dict | None = None,
    endpoint: str | None = None,
):
    """
    Celery задача для отправки уведомления.

    Args:
        user_id: ID пользователя (опционально)
        event_type: Тип события (order_created, status_changed, etc.)
        channel: Канал (push, email, telegram, sms)
        title: Заголовок
        body: Текст
        data: Дополнительные данные
        endpoint: Адрес получателя (email, chat_id, phone, device_token)
    """
    from users.models import User

    user = None
    if user_id:
        try:
            user = User.objects.get(pk=user_id)
        except User.DoesNotExist:
            logger.warning(f"User {user_id} not found for notification")
            return

    # Проверка preferences
    if user:
        subscription = NotificationSubscription.objects.filter(
            user=user, channel=channel, enabled=True
        ).first()
        if not subscription:
            logger.info(f"User {user_id} has disabled {channel} notifications")
            return

    log_entry = NotificationLog.objects.create(
        user=user,
        channel=channel,
        endpoint=endpoint or "",
        event_type=event_type,
        payload={"title": title, "body": body, "data": data or {}},
        status="pending",
    )

    try:
        success = False

        if channel == "push":
            if not endpoint:
                # Получаем device tokens пользователя
                tokens = DeviceToken.objects.filter(user=user, platform__in=["ios", "android"]).values_list(
                    "token", flat=True
                )
                if not tokens:
                    logger.warning(f"No device tokens for user {user_id}")
                    return
                device_tokens = list(tokens)
            else:
                device_tokens = [endpoint]

            service = FCMService()
            result = service.send_notification(device_tokens, title, body, data)
            success = result.get("success_count", 0) > 0

        elif channel == "email":
            if not endpoint and user:
                endpoint = user.email
            if not endpoint:
                logger.warning(f"No email endpoint for notification")
                return

            service = EmailService()
            success = service.send_email(endpoint, title, "notification", {"body": body, "data": data or {}})

        elif channel == "telegram":
            if not endpoint:
                subscription = NotificationSubscription.objects.filter(
                    user=user, channel="telegram", enabled=True
                ).first()
                if subscription:
                    endpoint = subscription.endpoint
            if not endpoint:
                logger.warning(f"No Telegram endpoint for notification")
                return

            service = TelegramService()
            success = service.send_message(endpoint, body)

        elif channel == "sms":
            if not endpoint and user:
                endpoint = user.phone
            if not endpoint:
                logger.warning(f"No SMS endpoint for notification")
                return

            service = SMSService()
            success = service.send_sms(endpoint, body)

        if success:
            log_entry.status = "sent"
            log_entry.sent_at = timezone.now()
            log_entry.save(update_fields=["status", "sent_at"])
            logger.info(f"Notification sent via {channel} to {endpoint}")
        else:
            raise Exception(f"Notification service returned failure for {channel}")

    except Exception as exc:
        log_entry.status = "failed"
        log_entry.error_message = str(exc)
        log_entry.retry_count = self.request.retries + 1
        log_entry.save(update_fields=["status", "error_message", "retry_count"])

        logger.error(f"Notification failed: {exc}", exc_info=True)
        raise self.retry(exc=exc)


@shared_task
def notify_order_created(order_id: str):
    """Уведомление о создании заказа"""
    from orders.models import Order

    try:
        order = Order.objects.select_related("manager", "client").get(id=order_id)
    except Order.DoesNotExist:
        logger.error(f"Order {order_id} not found")
        return

    # Уведомление менеджеру
    if order.manager:
        send_notification_task.delay(
            order.manager.id,
            "order_created",
            "push",
            f"Новый заказ #{order.number}",
            f"Клиент: {order.client.name if order.client else 'N/A'}, Сумма: {order.total_amount} ₽",
            {"order_id": str(order.id), "type": "order"},
        )

    # Email клиенту (если есть)
    if order.client and order.client.email:
        send_notification_task.delay(
            None,
            "order_created",
            "email",
            f"Заказ #{order.number} создан",
            f"Ваш заказ #{order.number} успешно создан. Сумма: {order.total_amount} ₽",
            {"order_id": str(order.id)},
            endpoint=order.client.email,
        )


@shared_task
def notify_order_status_changed(order_id: str, new_status: str, comment: str = ""):
    """Уведомление об изменении статуса заказа"""
    from orders.models import Order

    try:
        order = Order.objects.select_related("operator", "client").get(id=order_id)
    except Order.DoesNotExist:
        logger.error(f"Order {order_id} not found")
        return

    status_labels = {
        "APPROVED": "утверждён",
        "IN_PROGRESS": "в работе",
        "COMPLETED": "выполнен",
        "CANCELLED": "отменён",
    }

    status_label = status_labels.get(new_status, new_status)

    # Уведомление оператору
    if order.operator:
        send_notification_task.delay(
            order.operator.id,
            "status_changed",
            "push",
            f"Заказ #{order.number} {status_label}",
            comment or f"Статус заказа изменён на: {status_label}",
            {"order_id": str(order.id), "status": new_status},
        )

    # Email клиенту
    if order.client and order.client.email:
        send_notification_task.delay(
            None,
            "status_changed",
            "email",
            f"Заказ #{order.number} {status_label}",
            f"Статус вашего заказа изменён на: {status_label}",
            {"order_id": str(order.id), "status": new_status},
            endpoint=order.client.email,
        )


from __future__ import annotations

import logging

from django.conf import settings

logger = logging.getLogger(__name__)


class FCMService:
    """Firebase Cloud Messaging service для push уведомлений"""

    def __init__(self):
        self.server_key = getattr(settings, "FCM_SERVER_KEY", "")
        self.api_url = "https://fcm.googleapis.com/fcm/send"

    def send_notification(
        self,
        device_tokens: list[str],
        title: str,
        body: str,
        data: dict | None = None,
        priority: str = "high",
    ) -> dict:
        """
        Отправка push уведомления через FCM.

        Args:
            device_tokens: Список FCM токенов устройств
            title: Заголовок уведомления
            body: Текст уведомления
            data: Дополнительные данные (для deep linking)
            priority: Приоритет (high/normal)

        Returns:
            dict: Результат отправки {success_count, failure_count, results}
        """
        if not self.server_key:
            logger.warning("FCM_SERVER_KEY not configured, skipping push notification")
            return {"success_count": 0, "failure_count": len(device_tokens), "results": []}

        if not device_tokens:
            return {"success_count": 0, "failure_count": 0, "results": []}

        import requests

        headers = {
            "Authorization": f"key={self.server_key}",
            "Content-Type": "application/json",
        }

        payload = {
            "registration_ids": device_tokens,
            "notification": {"title": title, "body": body},
            "priority": priority,
        }

        if data:
            payload["data"] = data

        try:
            response = requests.post(self.api_url, json=payload, headers=headers, timeout=10)
            response.raise_for_status()
            result = response.json()

            success_count = result.get("success", 0)
            failure_count = result.get("failure", 0)

            logger.info(
                f"FCM notification sent: {success_count} success, {failure_count} failures",
                extra={"tokens_count": len(device_tokens)},
            )

            return {
                "success_count": success_count,
                "failure_count": failure_count,
                "results": result.get("results", []),
            }
        except Exception as e:
            logger.error(f"FCM notification failed: {e}", exc_info=True)
            return {"success_count": 0, "failure_count": len(device_tokens), "results": [], "error": str(e)}


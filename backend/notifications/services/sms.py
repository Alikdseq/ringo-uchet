from __future__ import annotations

import logging

from django.conf import settings

logger = logging.getLogger(__name__)


class SMSService:
    """SMS уведомления (stub для интеграции с провайдерами)"""

    def __init__(self):
        self.api_key = getattr(settings, "SMS_API_KEY", "")
        self.api_url = getattr(settings, "SMS_API_URL", "")

    def send_sms(self, phone: str, text: str) -> bool:
        """
        Отправка SMS (stub).

        Args:
            phone: Номер телефона
            text: Текст сообщения

        Returns:
            bool: Успешность отправки
        """
        if not self.api_key or not self.api_url:
            logger.warning("SMS not configured, skipping SMS notification")
            return False

        # TODO: Интеграция с SMS провайдером (Twilio, SMS.ru, etc.)
        logger.info(f"SMS stub: would send to {phone}: {text[:50]}...")
        return True


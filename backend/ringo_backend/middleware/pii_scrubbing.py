"""
Middleware для очистки PII (Personally Identifiable Information) из логов.
"""
from __future__ import annotations

import re
import logging
from typing import Callable, Any
from django.http import HttpRequest, HttpResponse

logger = logging.getLogger(__name__)


class PIIScrubbingMiddleware:
    """
    Middleware для удаления PII данных из логов.
    """

    # Паттерны для обнаружения PII данных
    PII_PATTERNS = {
        "email": re.compile(r"\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Z|a-z]{2,}\b"),
        "phone": re.compile(r"(\+?\d{1,3}[-.\s]?)?\(?\d{3}\)?[-.\s]?\d{3}[-.\s]?\d{4}"),
        "credit_card": re.compile(r"\b\d{4}[\s-]?\d{4}[\s-]?\d{4}[\s-]?\d{4}\b"),
        "ssn": re.compile(r"\b\d{3}-\d{2}-\d{4}\b"),
        "passport": re.compile(r"\b[A-Z]{1,2}\d{6,9}\b"),
    }

    # Поля, которые точно содержат PII
    PII_FIELDS = [
        "password",
        "token",
        "secret",
        "api_key",
        "access_key",
        "secret_key",
        "credit_card",
        "card_number",
        "ssn",
        "passport",
        "phone",
        "email",
    ]

    def __init__(self, get_response: Callable):
        self.get_response = get_response

    def _scrub_value(self, value: str) -> str:
        """Очищает значение от PII данных."""
        if not isinstance(value, str):
            return value

        scrubbed = value

        # Заменяем email адреса
        scrubbed = self.PII_PATTERNS["email"].sub("[EMAIL_REDACTED]", scrubbed)

        # Заменяем телефонные номера
        scrubbed = self.PII_PATTERNS["phone"].sub("[PHONE_REDACTED]", scrubbed)

        # Заменяем кредитные карты
        scrubbed = self.PII_PATTERNS["credit_card"].sub("[CARD_REDACTED]", scrubbed)

        # Заменяем SSN
        scrubbed = self.PII_PATTERNS["ssn"].sub("[SSN_REDACTED]", scrubbed)

        return scrubbed

    def _scrub_dict(self, data: dict) -> dict:
        """Очищает словарь от PII данных."""
        scrubbed = {}
        for key, value in data.items():
            key_lower = key.lower()

            # Проверяем, является ли поле PII
            if any(pii_field in key_lower for pii_field in self.PII_FIELDS):
                scrubbed[key] = "[REDACTED]"
            elif isinstance(value, str):
                scrubbed[key] = self._scrub_value(value)
            elif isinstance(value, dict):
                scrubbed[key] = self._scrub_dict(value)
            elif isinstance(value, list):
                scrubbed[key] = [
                    self._scrub_dict(item) if isinstance(item, dict) else self._scrub_value(item) if isinstance(item, str) else item
                    for item in value
                ]
            else:
                scrubbed[key] = value

        return scrubbed

    def __call__(self, request: HttpRequest) -> HttpResponse:
        response = self.get_response(request)

        # Очищаем данные из request для логирования
        if hasattr(request, "_log_data"):
            request._log_data = self._scrub_dict(request._log_data)

        return response


class LoggingFilter(logging.Filter):
    """
    Filter для очистки PII из логов на уровне logging.
    """

    def __init__(self, name: str = ""):
        super().__init__(name)
        # Создаем экземпляр scrubber для использования методов
        self.scrubber = PIIScrubbingMiddleware(lambda x: x)

    def filter(self, record: logging.LogRecord) -> bool:
        try:
            # Очищаем сообщение лога
            if hasattr(record, "msg") and isinstance(record.msg, str):
                record.msg = self.scrubber._scrub_value(record.msg)

            # Очищаем дополнительные данные
            if hasattr(record, "extra") and isinstance(record.extra, dict):
                record.extra = self.scrubber._scrub_dict(record.extra)
        except Exception:
            # Если что-то пошло не так, просто пропускаем запись
            pass

        return True


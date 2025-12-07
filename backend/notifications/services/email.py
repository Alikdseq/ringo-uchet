from __future__ import annotations

import logging

from django.conf import settings
from django.core.mail import EmailMultiAlternatives
from django.template.loader import render_to_string

logger = logging.getLogger(__name__)


class EmailService:
    """Email уведомления через SMTP/SendGrid"""

    def __init__(self):
        self.from_email = getattr(settings, "DEFAULT_FROM_EMAIL", "noreply@ringo.local")

    def send_email(
        self,
        to_email: str,
        subject: str,
        template_name: str,
        context: dict,
        attachments: list[tuple] | None = None,
    ) -> bool:
        """
        Отправка email с HTML шаблоном.

        Args:
            to_email: Email получателя
            subject: Тема письма
            template_name: Имя шаблона (без расширения, ищется в templates/emails/)
            context: Контекст для шаблона
            attachments: Список (filename, content, mimetype)

        Returns:
            bool: Успешность отправки
        """
        try:
            html_content = render_to_string(f"emails/{template_name}.html", context)
            text_content = render_to_string(f"emails/{template_name}.txt", context)

            msg = EmailMultiAlternatives(subject, text_content, self.from_email, [to_email])
            msg.attach_alternative(html_content, "text/html")

            if attachments:
                for filename, content, mimetype in attachments:
                    msg.attach(filename, content, mimetype)

            msg.send()
            logger.info(f"Email sent to {to_email}: {subject}")
            return True
        except Exception as e:
            logger.error(f"Email send failed to {to_email}: {e}", exc_info=True)
            return False

    def send_invoice(self, to_email: str, invoice_url: str, order_number: str) -> bool:
        """Отправка счёта на email"""
        return self.send_email(
            to_email,
            f"Счёт №{order_number}",
            "invoice",
            {"invoice_url": invoice_url, "order_number": order_number},
        )

    def send_order_confirmation(self, to_email: str, order_data: dict) -> bool:
        """Отправка подтверждения заказа"""
        return self.send_email(
            to_email,
            f"Заказ №{order_data.get('number')} подтверждён",
            "order_confirmation",
            order_data,
        )


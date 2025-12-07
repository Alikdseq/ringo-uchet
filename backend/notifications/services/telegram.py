from __future__ import annotations

import logging

from django.conf import settings

logger = logging.getLogger(__name__)


class TelegramService:
    """Telegram уведомления через Bot API"""

    def __init__(self):
        self.bot_token = getattr(settings, "TELEGRAM_BOT_TOKEN", "")
        self.api_url = f"https://api.telegram.org/bot{self.bot_token}" if self.bot_token else None

    def send_message(
        self,
        chat_id: str,
        text: str,
        parse_mode: str = "HTML",
        reply_markup: dict | None = None,
    ) -> bool:
        """
        Отправка сообщения в Telegram.

        Args:
            chat_id: ID чата или канала
            text: Текст сообщения
            parse_mode: HTML/Markdown
            reply_markup: Inline keyboard (JSON)

        Returns:
            bool: Успешность отправки
        """
        if not self.api_url:
            logger.warning("TELEGRAM_BOT_TOKEN not configured, skipping Telegram notification")
            return False

        import requests

        payload = {"chat_id": chat_id, "text": text, "parse_mode": parse_mode}
        if reply_markup:
            payload["reply_markup"] = reply_markup

        try:
            response = requests.post(f"{self.api_url}/sendMessage", json=payload, timeout=10)
            response.raise_for_status()
            logger.info(f"Telegram message sent to {chat_id}")
            return True
        except Exception as e:
            logger.error(f"Telegram send failed to {chat_id}: {e}", exc_info=True)
            return False

    def format_order_notification(self, order_data: dict) -> str:
        """Форматирование уведомления о заказе"""
        return f"""
<b>Новый заказ #{order_data.get('number')}</b>

Клиент: {order_data.get('client_name', 'N/A')}
Адрес: {order_data.get('address', 'N/A')}
Сумма: {order_data.get('total_amount', 0)} ₽
Статус: {order_data.get('status', 'N/A')}
        """.strip()


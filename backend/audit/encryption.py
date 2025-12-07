from __future__ import annotations

import base64
import logging
import os

from cryptography.fernet import Fernet
from django.conf import settings

logger = logging.getLogger(__name__)


class EncryptionService:
    """Сервис для шифрования чувствительных данных"""

    def __init__(self):
        # Получаем ключ из настроек или генерируем новый (для dev)
        key = getattr(settings, "ENCRYPTION_KEY", None)
        if not key:
            # В production должен быть установлен ENCRYPTION_KEY
            logger.warning("ENCRYPTION_KEY not set, using generated key (not secure for production!)")
            key = Fernet.generate_key()
        elif isinstance(key, str):
            key = key.encode()
        self.cipher = Fernet(key)

    def encrypt(self, value: str) -> str:
        """
        Шифрование строки.

        Args:
            value: Строка для шифрования

        Returns:
            str: Зашифрованная строка (base64)
        """
        if not value:
            return ""
        try:
            encrypted = self.cipher.encrypt(value.encode())
            return base64.b64encode(encrypted).decode()
        except Exception as e:
            logger.error(f"Encryption failed: {e}", exc_info=True)
            raise

    def decrypt(self, encrypted_value: str) -> str:
        """
        Расшифровка строки.

        Args:
            encrypted_value: Зашифрованная строка (base64)

        Returns:
            str: Расшифрованная строка
        """
        if not encrypted_value:
            return ""
        try:
            decoded = base64.b64decode(encrypted_value.encode())
            decrypted = self.cipher.decrypt(decoded)
            return decrypted.decode()
        except Exception as e:
            logger.error(f"Decryption failed: {e}", exc_info=True)
            raise


# Singleton instance
_encryption_service = None


def get_encryption_service() -> EncryptionService:
    """Получить singleton instance EncryptionService"""
    global _encryption_service
    if _encryption_service is None:
        _encryption_service = EncryptionService()
    return _encryption_service


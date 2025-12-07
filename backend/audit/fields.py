from __future__ import annotations

from django.db import models

from audit.encryption import get_encryption_service


class EncryptedCharField(models.CharField):
    """CharField с автоматическим шифрованием/расшифровкой"""

    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)

    def from_db_value(self, value, expression, connection):
        """Расшифровка при чтении из БД"""
        if value is None:
            return value
        try:
            encryption_service = get_encryption_service()
            return encryption_service.decrypt(value)
        except Exception:
            # Если расшифровка не удалась, возвращаем как есть (для миграций)
            return value

    def to_python(self, value):
        """Преобразование в Python значение"""
        if isinstance(value, str) or value is None:
            return value
        return str(value)

    def get_prep_value(self, value):
        """Шифрование перед сохранением в БД"""
        if value is None:
            return value
        try:
            encryption_service = get_encryption_service()
            return encryption_service.encrypt(str(value))
        except Exception:
            # Если шифрование не удалось, возвращаем как есть
            return value


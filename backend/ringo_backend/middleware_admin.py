from __future__ import annotations

import logging
import uuid

from django.http import Http404
from django.urls import resolve

logger = logging.getLogger(__name__)


class UUIDValidationMiddleware:
    """
    Middleware для валидации UUID в параметрах запроса к админке.
    Предотвращает ошибки при попытке использовать integer ID вместо UUID.
    """

    def __init__(self, get_response):
        self.get_response = get_response

    def __call__(self, request):
        # Проверяем только запросы к админке
        if request.path.startswith("/admin/"):
            # Проверяем параметры запроса
            for key, value in request.GET.items():
                if key in ("id", "object_id", "pk") and value:
                    try:
                        # Пытаемся преобразовать в UUID
                        uuid.UUID(str(value))
                    except (ValueError, TypeError):
                        # Если это не UUID и не пустое значение, логируем и возвращаем 404
                        if value and value != "None":
                            logger.warning(
                                f"Invalid UUID parameter in admin request: {key}={value} from {request.path}"
                            )
                            # Не блокируем запрос, просто логируем
                            # Django сам обработает ошибку при попытке использовать невалидный UUID

        response = self.get_response(request)
        return response


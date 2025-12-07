from __future__ import annotations

import logging
import time
from typing import Callable

from django.http import HttpRequest, HttpResponse

logger = logging.getLogger("audit")


class AuditLogMiddleware:
    """
    Lightweight middleware that logs basic request metadata for audit purposes.
    """

    def __init__(self, get_response: Callable[[HttpRequest], HttpResponse]):
        self.get_response = get_response

    def __call__(self, request: HttpRequest) -> HttpResponse:
        start = time.monotonic()
        response = self.get_response(request)
        duration_ms = (time.monotonic() - start) * 1000
        user = getattr(request, "user", None)
        logger.info(
            "%s %s %s %0.2fms",
            request.method,
            request.path,
            response.status_code,
            duration_ms,
            extra={
                "request_id": getattr(request, "request_id", None),
                "user_id": getattr(user, "id", None),
                "role": getattr(user, "role", None),
                "ip": request.META.get("REMOTE_ADDR"),
            },
        )
        return response


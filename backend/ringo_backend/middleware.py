from __future__ import annotations

import logging
import time
import uuid
from typing import Callable

from django.http import HttpRequest, HttpResponse

logger = logging.getLogger("audit")


class RequestIDMiddleware:
    """
    Ensures every request/response has an X-Request-ID header for correlation.
    """

    def __init__(self, get_response: Callable[[HttpRequest], HttpResponse]):
        self.get_response = get_response

    def __call__(self, request: HttpRequest) -> HttpResponse:
        request_id = request.headers.get("X-Request-ID", uuid.uuid4().hex)
        request.request_id = request_id
        response = self.get_response(request)
        response["X-Request-ID"] = request_id
        return response


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


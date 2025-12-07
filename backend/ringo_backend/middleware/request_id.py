from __future__ import annotations

import uuid
from typing import Callable

from django.http import HttpRequest, HttpResponse


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


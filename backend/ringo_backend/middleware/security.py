"""
Security middleware для защиты от различных атак.
"""
from __future__ import annotations

import re
import logging
from typing import Callable
from ipaddress import ip_address, ip_network

from django.http import HttpRequest, HttpResponse, HttpResponseForbidden
from django.conf import settings

logger = logging.getLogger("security")


class IPAllowlistMiddleware:
    """
    Middleware для ограничения доступа к admin endpoints по IP адресам.
    """

    def __init__(self, get_response: Callable):
        self.get_response = get_response
        self.allowed_ips = self._parse_allowed_ips()

    def _parse_allowed_ips(self) -> list:
        """Парсит список разрешенных IP адресов из переменных окружения."""
        allowed_ips_list = getattr(settings, "ADMIN_ALLOWED_IPS", [])
        
        # Если список пустой или None - разрешаем всем (для локальной разработки)
        if not allowed_ips_list:
            logger.info("ADMIN_ALLOWED_IPS is empty, allowing all IPs for admin access (development mode)")
            return []

        allowed_ips = []
        for ip_str in allowed_ips_list:
            ip_str = ip_str.strip()
            if not ip_str:
                continue
            try:
                # Поддержка CIDR нотации
                if "/" in ip_str:
                    allowed_ips.append(ip_network(ip_str, strict=False))
                else:
                    allowed_ips.append(ip_address(ip_str))
            except ValueError:
                logger.warning(f"Invalid IP address in ADMIN_ALLOWED_IPS: {ip_str}")

        if allowed_ips:
            logger.info(f"IP allowlist enabled for admin: {len(allowed_ips)} IP(s)/network(s)")
        
        return allowed_ips

    def _is_allowed_ip(self, ip: str) -> bool:
        """Проверяет, разрешен ли IP адрес."""
        if not self.allowed_ips:
            # Если список пуст, разрешаем всем (для разработки)
            return True

        try:
            client_ip = ip_address(ip)
            for allowed in self.allowed_ips:
                if isinstance(allowed, ip_network):
                    if client_ip in allowed:
                        return True
                else:
                    if client_ip == allowed:
                        return True
        except ValueError:
            logger.warning(f"Invalid IP address: {ip}")
            return False

        return False

    def __call__(self, request: HttpRequest) -> HttpResponse:
        # Проверяем только admin endpoints
        if request.path.startswith("/admin/"):
            # Если список разрешенных IP пустой - разрешаем всем (для разработки)
            if not self.allowed_ips:
                return self.get_response(request)
            
            # Получаем реальный IP адрес (учитываем прокси)
            real_ip = (
                request.META.get("HTTP_X_FORWARDED_FOR", "").split(",")[0].strip()
                or request.META.get("HTTP_X_REAL_IP", "")
                or request.META.get("REMOTE_ADDR", "")
            )

            if not real_ip:
                logger.warning("Could not determine client IP address, blocking admin access")
                return HttpResponseForbidden("Access denied: Could not determine IP address")

            if not self._is_allowed_ip(real_ip):
                logger.warning(
                    f"Blocked admin access from unauthorized IP: {real_ip}",
                    extra={
                        "ip": real_ip,
                        "path": request.path,
                        "user_agent": request.META.get("HTTP_USER_AGENT", ""),
                        "allowed_ips": [str(ip) for ip in self.allowed_ips],
                    },
                )
                return HttpResponseForbidden("Access denied")

        return self.get_response(request)


class SQLInjectionProtectionMiddleware:
    """
    Middleware для базовой защиты от SQL injection атак.
    """

    # Паттерны для обнаружения SQL injection попыток
    SQL_INJECTION_PATTERNS = [
        r"(\bUNION\b.*\bSELECT\b)",
        r"(\bSELECT\b.*\bFROM\b)",
        r"(\bINSERT\b.*\bINTO\b)",
        r"(\bDELETE\b.*\bFROM\b)",
        r"(\bDROP\b.*\bTABLE\b)",
        r"(\bUPDATE\b.*\bSET\b)",
        r"(\bEXEC\b|\bEXECUTE\b)",
        r"(\b--\s|\b#\s)",  # SQL комментарии
        r"(\bOR\b\s+\d+\s*=\s*\d+)",
        r"(\bAND\b\s+\d+\s*=\s*\d+)",
        r"('|\"|;|\\)",  # Подозрительные символы
    ]

    def __init__(self, get_response: Callable):
        self.get_response = get_response
        self.patterns = [re.compile(pattern, re.IGNORECASE) for pattern in self.SQL_INJECTION_PATTERNS]

    def __call__(self, request: HttpRequest) -> HttpResponse:
        # Проверяем query параметры и body
        suspicious_strings = []

        # Проверяем GET параметры
        for key, value in request.GET.items():
            if isinstance(value, str):
                for pattern in self.patterns:
                    if pattern.search(value):
                        suspicious_strings.append(f"GET[{key}]={value[:50]}")

        # Проверяем POST данные
        if request.method == "POST":
            for key, value in request.POST.items():
                if isinstance(value, str):
                    for pattern in self.patterns:
                        if pattern.search(value):
                            suspicious_strings.append(f"POST[{key}]={value[:50]}")

        if suspicious_strings:
            logger.warning(
                "Potential SQL injection attempt detected",
                extra={
                    "ip": request.META.get("REMOTE_ADDR", ""),
                    "path": request.path,
                    "suspicious": suspicious_strings,
                    "user_agent": request.META.get("HTTP_USER_AGENT", ""),
                },
            )
            # В production можно вернуть 403, но для начала логируем
            # return HttpResponseForbidden("Invalid request")

        return self.get_response(request)


class XSSProtectionMiddleware:
    """
    Middleware для базовой защиты от XSS атак.
    """

    XSS_PATTERNS = [
        r"<script[^>]*>.*?</script>",
        r"javascript:",
        r"on\w+\s*=",  # onclick=, onerror=, etc.
        r"<iframe[^>]*>",
        r"<object[^>]*>",
        r"<embed[^>]*>",
    ]

    def __init__(self, get_response: Callable):
        self.get_response = get_response
        self.patterns = [re.compile(pattern, re.IGNORECASE) for pattern in self.XSS_PATTERNS]

    def __call__(self, request: HttpRequest) -> HttpResponse:
        # Проверяем query параметры
        for key, value in request.GET.items():
            if isinstance(value, str):
                for pattern in self.patterns:
                    if pattern.search(value):
                        logger.warning(
                            "Potential XSS attempt detected",
                            extra={
                                "ip": request.META.get("REMOTE_ADDR", ""),
                                "path": request.path,
                                "parameter": key,
                                "value": value[:100],
                            },
                        )
                        return HttpResponseForbidden("Invalid request")

        return self.get_response(request)


class SSRFProtectionMiddleware:
    """
    Middleware для защиты от SSRF (Server-Side Request Forgery) атак.
    """

    # Запрещенные IP адреса (внутренние сети)
    FORBIDDEN_IPS = [
        ip_network("127.0.0.0/8"),  # localhost
        ip_network("10.0.0.0/8"),  # private
        ip_network("172.16.0.0/12"),  # private
        ip_network("192.168.0.0/16"),  # private
        ip_network("169.254.0.0/16"),  # link-local
        ip_network("::1/128"),  # IPv6 localhost
        ip_network("fc00::/7"),  # IPv6 private
    ]

    def __init__(self, get_response: Callable):
        self.get_response = get_response

    def _is_forbidden_ip(self, ip_str: str) -> bool:
        """Проверяет, является ли IP адрес запрещенным (внутренним)."""
        try:
            ip = ip_address(ip_str)
            for forbidden_network in self.FORBIDDEN_IPS:
                if ip in forbidden_network:
                    return True
        except ValueError:
            return False
        return False

    def __call__(self, request: HttpRequest) -> HttpResponse:
        # Проверяем параметры, которые могут содержать URL
        url_params = ["url", "link", "redirect", "callback", "webhook"]

        for param in url_params:
            value = request.GET.get(param) or request.POST.get(param)
            if value:
                # Извлекаем hostname из URL
                import urllib.parse

                try:
                    parsed = urllib.parse.urlparse(value)
                    hostname = parsed.hostname
                    if hostname:
                        # Проверяем IP адрес
                        import socket

                        try:
                            ip = socket.gethostbyname(hostname)
                            if self._is_forbidden_ip(ip):
                                logger.warning(
                                    "Potential SSRF attempt detected",
                                    extra={
                                        "ip": request.META.get("REMOTE_ADDR", ""),
                                        "path": request.path,
                                        "parameter": param,
                                        "url": value[:100],
                                        "resolved_ip": ip,
                                    },
                                )
                                return HttpResponseForbidden("Invalid request")
                        except socket.gaierror:
                            pass
                except Exception:
                    pass

        return self.get_response(request)


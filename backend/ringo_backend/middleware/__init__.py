# Middleware модуль
# Импорты для удобства

from .request_id import RequestIDMiddleware
from .audit_log import AuditLogMiddleware

try:
    from .security import (
        IPAllowlistMiddleware,
        SQLInjectionProtectionMiddleware,
        XSSProtectionMiddleware,
        SSRFProtectionMiddleware,
    )
except ImportError as e:
    import logging
    logger = logging.getLogger(__name__)
    logger.warning(f"Could not import security middleware: {e}")

try:
    from .metrics import PrometheusMetricsMiddleware
except ImportError as e:
    import logging
    logger = logging.getLogger(__name__)
    logger.warning(f"Could not import metrics middleware: {e}")

try:
    from .pii_scrubbing import PIIScrubbingMiddleware
except ImportError as e:
    import logging
    logger = logging.getLogger(__name__)
    logger.warning(f"Could not import PII scrubbing middleware: {e}")

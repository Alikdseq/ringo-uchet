from __future__ import annotations

from pathlib import Path

from datetime import timedelta
from decimal import Decimal

from django.core.management.utils import get_random_secret_key

BASE_DIR = Path(__file__).resolve().parent.parent

SECRET_KEY = (
    __import__("os").environ.get("DJANGO_SECRET_KEY") or get_random_secret_key()
)

DEBUG = False

ALLOWED_HOSTS: list[str] = [
    host.strip()
    for host in __import__("os").environ.get("DJANGO_ALLOWED_HOSTS", "").split(",")
    if host.strip()
]

INSTALLED_APPS = [
    "django.contrib.admin",
    "django.contrib.auth",
    "django.contrib.contenttypes",
    "django.contrib.sessions",
    "django.contrib.messages",
    "django.contrib.staticfiles",
    "corsheaders",
    "rest_framework",
    "rest_framework.authtoken",
    "rest_framework_simplejwt.token_blacklist",
    "drf_spectacular",
    "django_filters",
    "django_prometheus",  # Prometheus metrics
    "ringo_backend",  # Основное приложение (для management commands)
    "users",
    "catalog",
    "crm",
    "orders",
    "finance",
    "notifications",
    "audit",
]

MIDDLEWARE = [
    "django_prometheus.middleware.PrometheusBeforeMiddleware",  # Prometheus metrics
    "ringo_backend.middleware.metrics.PrometheusMetricsMiddleware",  # Custom Prometheus metrics
    "ringo_backend.middleware.security.IPAllowlistMiddleware",  # IP allowlist для admin
    "ringo_backend.middleware.security.SQLInjectionProtectionMiddleware",  # SQL injection protection
    "ringo_backend.middleware.security.XSSProtectionMiddleware",  # XSS protection
    "ringo_backend.middleware.security.SSRFProtectionMiddleware",  # SSRF protection
    "django.middleware.security.SecurityMiddleware",
    "django.middleware.gzip.GZipMiddleware",  # Сжатие ответов для ускорения загрузки
    "corsheaders.middleware.CorsMiddleware",
    "django_prometheus.middleware.PrometheusAfterMiddleware",  # Prometheus metrics
    "django.contrib.sessions.middleware.SessionMiddleware",
    "django.middleware.common.CommonMiddleware",
    "django.middleware.csrf.CsrfViewMiddleware",
    "django.contrib.auth.middleware.AuthenticationMiddleware",
    "django.contrib.messages.middleware.MessageMiddleware",
    "django.middleware.clickjacking.XFrameOptionsMiddleware",
    "ringo_backend.middleware.pii_scrubbing.PIIScrubbingMiddleware",  # PII scrubbing
    "ringo_backend.middleware.RequestIDMiddleware",
    "ringo_backend.middleware.AuditLogMiddleware",  # Audit logging
]

ROOT_URLCONF = "ringo_backend.urls"

TEMPLATES = [
    {
        "BACKEND": "django.template.backends.django.DjangoTemplates",
        "DIRS": [BASE_DIR / "templates"],
        "APP_DIRS": True,
        "OPTIONS": {
            "context_processors": [
                "django.template.context_processors.debug",
                "django.template.context_processors.request",
                "django.contrib.auth.context_processors.auth",
                "django.contrib.messages.context_processors.messages",
            ],
        },
    },
]

WSGI_APPLICATION = "ringo_backend.wsgi.application"
ASGI_APPLICATION = "ringo_backend.asgi.application"

# Исправление проблемы с UnicodeDecodeError в psycopg2 на Windows
# libpq (C библиотека PostgreSQL) читает системные переменные Windows напрямую
# через Windows API, что вызывает проблемы когда USERNAME/USERPROFILE содержат кириллицу.
# Используем DATABASE_URL для полного обхода проблемы с системными переменными.
import os
import urllib.parse

# Очищаем переменные окружения PostgreSQL, чтобы libpq не читал системные переменные
_postgres_env_vars = ['PGHOST', 'PGUSER', 'PGPASSWORD', 'PGDATABASE', 'PGPORT', 'PGPASSFILE']
for var in _postgres_env_vars:
    os.environ[var] = ''

# Получаем параметры подключения
db_name = os.environ.get("POSTGRES_DB", "ringo")
db_user = os.environ.get("POSTGRES_USER", "ringo")
db_password = os.environ.get("POSTGRES_PASSWORD", "ringo")
db_host = os.environ.get("POSTGRES_HOST", "db")
db_port = os.environ.get("POSTGRES_PORT", "5432")

# Кодируем параметры для URL (безопасная обработка специальных символов)
db_user_encoded = urllib.parse.quote(str(db_user), safe='')
db_password_encoded = urllib.parse.quote(str(db_password), safe='')
db_host_encoded = urllib.parse.quote(str(db_host), safe='')
db_name_encoded = urllib.parse.quote(str(db_name), safe='')

# Формируем DATABASE_URL - это обходит проблему с системными переменными Windows
database_url = f"postgresql://{db_user_encoded}:{db_password_encoded}@{db_host_encoded}:{db_port}/{db_name_encoded}"

# Устанавливаем DATABASE_URL - Django автоматически использует его если он установлен
os.environ['DATABASE_URL'] = database_url

# Настройки базы данных
# Django будет использовать DATABASE_URL если он установлен, иначе параметры ниже
DATABASES = {
    "default": {
        "ENGINE": "django.db.backends.postgresql",
        "NAME": db_name,
        "USER": db_user,
        "PASSWORD": db_password,
        "HOST": db_host,
        "PORT": db_port,
    }
}

AUTH_USER_MODEL = "users.User"

LANGUAGE_CODE = "ru-ru"
TIME_ZONE = "Europe/Moscow"
USE_I18N = True
USE_TZ = True

STATIC_URL = "/static/"
STATIC_ROOT = BASE_DIR / "staticfiles"

MEDIA_URL = "/media/"
MEDIA_ROOT = BASE_DIR / "media"

DEFAULT_AUTO_FIELD = "django.db.models.BigAutoField"

REST_FRAMEWORK = {
    "DEFAULT_SCHEMA_CLASS": "drf_spectacular.openapi.AutoSchema",
    "DEFAULT_AUTHENTICATION_CLASSES": (
        "rest_framework_simplejwt.authentication.JWTAuthentication",
    ),
    "DEFAULT_PERMISSION_CLASSES": ("rest_framework.permissions.IsAuthenticated",),
    "DEFAULT_FILTER_BACKENDS": (
        "django_filters.rest_framework.DjangoFilterBackend",
        "rest_framework.filters.OrderingFilter",
        "rest_framework.filters.SearchFilter",
    ),
    "DEFAULT_THROTTLE_CLASSES": [
        "rest_framework.throttling.AnonRateThrottle",
        "rest_framework.throttling.UserRateThrottle",
    ],
    "DEFAULT_THROTTLE_RATES": {"anon": "30/min", "user": "120/min"},
    # Пагинация для оптимизации загрузки данных
    "DEFAULT_PAGINATION_CLASS": "rest_framework.pagination.PageNumberPagination",
    "PAGE_SIZE": 50,  # Размер страницы по умолчанию
    "PAGE_SIZE_QUERY_PARAM": "page_size",  # Параметр для изменения размера страницы
    "MAX_PAGE_SIZE": 200,  # Максимальный размер страницы
}

SPECTACULAR_SETTINGS = {
    "TITLE": "Ringo Uchet API",
    "DESCRIPTION": """
    Backend API для системы учёта аренды спецтехники Ringo Uchet.
    
    ## Роли и доступ
    
    - **Admin** - полный доступ ко всем ресурсам, включая отчёты и финансовые данные
    - **Manager** - создание и управление заявками, просмотр техники и клиентов, работа с заказами (не видит прибыль и отчёты)
    - **Operator** - просмотр назначенных заявок, изменение статусов, загрузка фото, просмотр своей зарплаты
    
    ## Аутентификация
    
    API использует JWT токены. Получите access token через `/api/auth/login/` и используйте его в заголовке:
    ```
    Authorization: Bearer <access_token>
    ```
    
    ## Статус-коды
    
    - `200 OK` - успешный запрос
    - `201 Created` - ресурс создан
    - `400 Bad Request` - ошибка валидации
    - `401 Unauthorized` - требуется аутентификация
    - `403 Forbidden` - недостаточно прав
    - `404 Not Found` - ресурс не найден
    - `429 Too Many Requests` - превышен лимит запросов
    - `500 Internal Server Error` - внутренняя ошибка сервера
    """,
    "VERSION": "0.1.0",
    "SERVE_INCLUDE_SCHEMA": False,
    "SCHEMA_PATH_PREFIX": "/api",
    "TAGS": [
        {"name": "Authentication", "description": "Аутентификация и авторизация"},
        {"name": "Catalog", "description": "Каталог техники, услуг и материалов"},
        {"name": "CRM", "description": "Управление клиентами"},
        {"name": "Orders", "description": "Заявки и заказы (требует роль Manager/Operator)"},
        {"name": "Finance", "description": "Финансы, счета, платежи (требует роль Admin)"},
        {"name": "Reports", "description": "Отчёты и аналитика (требует роль Admin)"},
        {"name": "Notifications", "description": "Управление уведомлениями"},
    ],
    "COMPONENT_SPLIT_REQUEST": True,
    "COMPONENT_NO_READ_ONLY_REQUIRED": True,
    "SORT_OPERATIONS": False,
    "SORT_TAGS": True,
    "ENUM_NAME_OVERRIDES": {
        "OrderStatusEnum": "orders.models.OrderStatus",
    },
    "EXTENSIONS_INFO": {
        "x-logo": {
            "url": "https://via.placeholder.com/200x50?text=Ringo+Uchet",
            "altText": "Ringo Uchet Logo",
        },
    },
    "SERVERS": [
        {"url": "http://localhost:8000", "description": "Local development"},
        {"url": "https://api.ringo.local", "description": "Staging"},
        {"url": "https://api.ringo.prod", "description": "Production"},
    ],
    "AUTHENTICATION_WHITELIST": [
        "rest_framework_simplejwt.authentication.JWTAuthentication",
    ],
    "APPEND_COMPONENTS": {
        "securitySchemes": {
            "BearerAuth": {
                "type": "http",
                "scheme": "bearer",
                "bearerFormat": "JWT",
            },
        },
    },
    "SECURITY": [{"BearerAuth": []}],
    "DEFAULT_GENERATOR_CLASS": "drf_spectacular.generators.SchemaGenerator",
    "SCHEMA_PATH_PREFIX_TRIM": True,
    "PREPROCESSING_HOOKS": [],
    "POSTPROCESSING_HOOKS": [],
    "EXTENSIONS": {},
}

CORS_ALLOW_CREDENTIALS = True

# CORS настройки: разрешаем localhost для разработки
_cors_origins_env = __import__("os").environ.get("CORS_ALLOWED_ORIGINS", "")
CORS_ALLOWED_ORIGINS = [
    origin.strip()
    for origin in _cors_origins_env.split(",")
    if origin.strip()
]

# Разрешаем все методы и заголовки для разработки
CORS_ALLOW_ALL_ORIGINS = __import__("os").environ.get("CORS_ALLOW_ALL_ORIGINS", "false").lower() == "true"

# Если CORS_ALLOW_ALL_ORIGINS не задан и CORS_ALLOWED_ORIGINS пуст, 
# используем регулярное выражение для разрешения всех localhost портов
if not CORS_ALLOW_ALL_ORIGINS and not CORS_ALLOWED_ORIGINS:
    # Разрешаем все localhost и 127.0.0.1 порты для разработки
    import re
    CORS_ALLOWED_ORIGIN_REGEXES = [
        re.compile(r"^http://localhost:\d+$"),
        re.compile(r"^http://127\.0\.0\.1:\d+$"),
        re.compile(r"^http://\[::1\]:\d+$"),  # IPv6 localhost
    ]
else:
    CORS_ALLOWED_ORIGIN_REGEXES = []

# Разрешаем все заголовки и методы для разработки
CORS_ALLOW_HEADERS = [
    "accept",
    "accept-encoding",
    "authorization",
    "content-type",
    "dnt",
    "origin",
    "user-agent",
    "x-csrftoken",
    "x-requested-with",
]

CORS_ALLOW_METHODS = [
    "DELETE",
    "GET",
    "OPTIONS",
    "PATCH",
    "POST",
    "PUT",
]

SIMPLE_JWT = {
    "ACCESS_TOKEN_LIFETIME": timedelta(minutes=int(__import__("os").environ.get("JWT_ACCESS_MINUTES", 30))),
    "REFRESH_TOKEN_LIFETIME": timedelta(days=int(__import__("os").environ.get("JWT_REFRESH_DAYS", 7))),
    "ROTATE_REFRESH_TOKENS": True,
    "BLACKLIST_AFTER_ROTATION": True,
    "UPDATE_LAST_LOGIN": True,
    "AUTH_HEADER_TYPES": ("Bearer",),
}

EMAIL_BACKEND = "django.core.mail.backends.smtp.EmailBackend"
EMAIL_HOST = __import__("os").environ.get("EMAIL_HOST", "smtp")
EMAIL_PORT = int(__import__("os").environ.get("EMAIL_PORT", 587))
EMAIL_USE_TLS = __import__("os").environ.get("EMAIL_USE_TLS", "true").lower() == "true"
EMAIL_HOST_USER = __import__("os").environ.get("EMAIL_HOST_USER", "")
EMAIL_HOST_PASSWORD = __import__("os").environ.get("EMAIL_HOST_PASSWORD", "")

AWS_ACCESS_KEY_ID = __import__("os").environ.get("AWS_ACCESS_KEY_ID", "")
AWS_SECRET_ACCESS_KEY = __import__("os").environ.get("AWS_SECRET_ACCESS_KEY", "")
AWS_STORAGE_BUCKET_NAME = __import__("os").environ.get("AWS_BUCKET", "")
AWS_S3_ENDPOINT_URL = __import__("os").environ.get(
    "AWS_S3_ENDPOINT_URL", "http://minio:9000"
)
AWS_S3_REGION_NAME = __import__("os").environ.get("AWS_S3_REGION_NAME", "")

# Celery
CELERY_BROKER_URL = __import__("os").environ.get("CELERY_BROKER_URL", "redis://redis:6379/0")
CELERY_RESULT_BACKEND = __import__("os").environ.get("CELERY_RESULT_BACKEND", "redis://redis:6379/0")
CELERY_ACCEPT_CONTENT = ["json"]
CELERY_TASK_SERIALIZER = "json"
CELERY_RESULT_SERIALIZER = "json"
CELERY_TIMEZONE = TIME_ZONE
CELERY_TASK_TRACK_STARTED = True
CELERY_TASK_TIME_LIMIT = 30 * 60  # 30 minutes
CELERY_TASK_SOFT_TIME_LIMIT = 25 * 60  # 25 minutes

# Celery Worker Configuration
CELERY_WORKER_CONCURRENCY = int(__import__("os").environ.get("CELERY_WORKER_CONCURRENCY", "4"))
CELERY_WORKER_MAX_TASKS_PER_CHILD = int(__import__("os").environ.get("CELERY_WORKER_MAX_TASKS_PER_CHILD", "1000"))
CELERY_WORKER_PREFETCH_MULTIPLIER = int(__import__("os").environ.get("CELERY_WORKER_PREFETCH_MULTIPLIER", "4"))

# Celery Autoscaling Configuration
# Autoscaler включен через флаг --autoscale в команде запуска worker
# CELERY_WORKER_AUTOSCALER удалена, так как вызывала ошибку TypeError
CELERY_WORKER_AUTOSCALER_MIN = int(__import__("os").environ.get("CELERY_WORKER_AUTOSCALER_MIN", "2"))
CELERY_WORKER_AUTOSCALER_MAX = int(__import__("os").environ.get("CELERY_WORKER_AUTOSCALER_MAX", "10"))

# Celery Task Routing
CELERY_TASK_ROUTES = {
    "finance.tasks.*": {"queue": "finance"},
    "notifications.tasks.*": {"queue": "notifications"},
    "orders.tasks.*": {"queue": "orders"},
}

# Celery Task Priorities
CELERY_TASK_DEFAULT_PRIORITY = 5
CELERY_TASK_DEFAULT_QUEUE = "default"

# Celery Task ETA/Countdown
CELERY_TASK_ALWAYS_EAGER = __import__("os").environ.get("CELERY_TASK_ALWAYS_EAGER", "false").lower() == "true"
CELERY_TASK_EAGER_PROPAGATES = True

# Celery Result Backend Settings
CELERY_RESULT_EXPIRES = int(__import__("os").environ.get("CELERY_RESULT_EXPIRES", "3600"))  # 1 hour
CELERY_RESULT_BACKEND_ALWAYS_RETRY = True
CELERY_RESULT_BACKEND_MAX_RETRIES = 10

# Celery Beat Schedule (если нужно, можно вынести в отдельный файл)
CELERY_BEAT_SCHEDULE = {
    # Пример: периодическая задача каждые 5 минут
    # "process-pending-tasks": {
    #     "task": "orders.tasks.process_pending_orders",
    #     "schedule": 300.0,  # 5 minutes
    # },
}

# Notifications
FCM_SERVER_KEY = __import__("os").environ.get("FCM_SERVER_KEY", "")
TELEGRAM_BOT_TOKEN = __import__("os").environ.get("TELEGRAM_BOT_TOKEN", "")
SMS_API_KEY = __import__("os").environ.get("SMS_API_KEY", "")
SMS_API_URL = __import__("os").environ.get("SMS_API_URL", "")

# Encryption
ENCRYPTION_KEY = __import__("os").environ.get("ENCRYPTION_KEY", "")

# Security Settings
# IP allowlist для admin endpoints (через запятую, поддерживает CIDR)
# Если не задан или пустой - разрешаем всем (для локальной разработки)
_admin_allowed_ips_env = __import__("os").environ.get("ADMIN_ALLOWED_IPS", "").strip()
ADMIN_ALLOWED_IPS = [ip.strip() for ip in _admin_allowed_ips_env.split(",") if ip.strip()] if _admin_allowed_ips_env else []

# Django Security Settings
SECURE_SSL_REDIRECT = __import__("os").environ.get("SECURE_SSL_REDIRECT", "false").lower() == "true"
SECURE_HSTS_SECONDS = int(__import__("os").environ.get("SECURE_HSTS_SECONDS", "31536000"))  # 1 year
SECURE_HSTS_INCLUDE_SUBDOMAINS = __import__("os").environ.get("SECURE_HSTS_INCLUDE_SUBDOMAINS", "true").lower() == "true"
SECURE_HSTS_PRELOAD = __import__("os").environ.get("SECURE_HSTS_PRELOAD", "true").lower() == "true"
SECURE_CONTENT_TYPE_NOSNIFF = True
SECURE_BROWSER_XSS_FILTER = True
X_FRAME_OPTIONS = "SAMEORIGIN"
SECURE_REFERRER_POLICY = "strict-origin-when-cross-origin"

# Session Security
SESSION_COOKIE_SECURE = __import__("os").environ.get("SESSION_COOKIE_SECURE", "false").lower() == "true"
SESSION_COOKIE_HTTPONLY = True
SESSION_COOKIE_SAMESITE = "Lax"
CSRF_COOKIE_SECURE = __import__("os").environ.get("CSRF_COOKIE_SECURE", "false").lower() == "true"
CSRF_COOKIE_HTTPONLY = True
CSRF_COOKIE_SAMESITE = "Lax"

# Log Retention (90 дней)
LOG_RETENTION_DAYS = int(__import__("os").environ.get("LOG_RETENTION_DAYS", "90"))

LOGGING = {
    "version": 1,
    "disable_existing_loggers": False,
    "formatters": {
        "console": {
            "format": "%(asctime)s [%(levelname)s] %(name)s: %(message)s",
        },
        "audit": {
            "format": "%(asctime)s [%(levelname)s] %(name)s %(request_id)s user=%(user_id)s role=%(role)s %(message)s",
        },
        "secure": {
            "format": "%(asctime)s [%(levelname)s] %(name)s [IP:%(ip)s] %(message)s",
        },
    },
    "handlers": {
        "console": {
            "class": "logging.StreamHandler",
            "formatter": "console",
        },
        "audit": {
            "class": "logging.StreamHandler",
            "formatter": "audit",
        },
        "security": {
            "class": "logging.StreamHandler",
            "formatter": "secure",
        },
    },
    "root": {
        "handlers": ["console"],
        "level": "INFO",
    },
    "loggers": {
        "audit": {
            "handlers": ["audit"],
            "level": "INFO",
            "propagate": False,
        },
        "security": {
            "handlers": ["security"],
            "level": "WARNING",
            "propagate": False,
        },
    },
}

PRICING_ENGINE = {
    "equipment_daily_threshold_hours": int(
        __import__("os").environ.get("PRICING_EQUIP_THRESHOLD", 8)
    ),
    "late_penalty_percent": Decimal(
        __import__("os").environ.get("PRICING_LATE_PENALTY_PERCENT", "10")
    ),
}

APP_CONFIG = {
    "company_name": __import__("os").environ.get("COMPANY_NAME", "Ringo Uchet"),
    "company_address": __import__("os").environ.get("COMPANY_ADDRESS", "Россия"),
    "company_phone": __import__("os").environ.get("COMPANY_PHONE", "+7 (000) 000-00-00"),
    "company_email": __import__("os").environ.get("COMPANY_EMAIL", "info@example.com"),
    "company_representative": __import__("os").environ.get("COMPANY_REP", "Генеральный директор"),
    "payment_link": __import__("os").environ.get("PAYMENT_LINK", "https://example.com/pay"),
}


"""
Celery Autoscaler для динамического масштабирования workers на основе нагрузки.

Использование:
    celery -A ringo_backend worker --loglevel=info --autoscale=${CELERY_WORKER_AUTOSCALER_MAX},${CELERY_WORKER_AUTOSCALER_MIN}
    
Или через переменные окружения:
    CELERY_WORKER_AUTOSCALER=true
    CELERY_WORKER_AUTOSCALER_MIN=2
    CELERY_WORKER_AUTOSCALER_MAX=10
"""
from __future__ import annotations

import os
import logging

from celery import Celery

logger = logging.getLogger(__name__)


def get_autoscaler_config() -> tuple[int, int] | None:
    """
    Получает конфигурацию autoscaler из переменных окружения.
    
    Returns:
        Tuple (min, max) или None если autoscaler отключен
    """
    if os.environ.get("CELERY_WORKER_AUTOSCALER", "false").lower() != "true":
        return None
    
    min_workers = int(os.environ.get("CELERY_WORKER_AUTOSCALER_MIN", "2"))
    max_workers = int(os.environ.get("CELERY_WORKER_AUTOSCALER_MAX", "10"))
    
    return (min_workers, max_workers)


def get_worker_command_args() -> list[str]:
    """
    Генерирует аргументы команды для celery worker с учетом autoscaling.
    
    Returns:
        Список аргументов для команды celery worker
    """
    args = [
        "--loglevel=info",
        f"--concurrency={os.environ.get('CELERY_WORKER_CONCURRENCY', '4')}",
        f"--max-tasks-per-child={os.environ.get('CELERY_WORKER_MAX_TASKS_PER_CHILD', '1000')}",
    ]
    
    autoscaler_config = get_autoscaler_config()
    if autoscaler_config:
        min_workers, max_workers = autoscaler_config
        args.append(f"--autoscale={max_workers},{min_workers}")
        logger.info(f"Celery autoscaler enabled: {min_workers}-{max_workers} workers")
    else:
        logger.info("Celery autoscaler disabled, using fixed concurrency")
    
    return args


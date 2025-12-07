"""
Celery signals для сбора Prometheus метрик задач.
"""
from __future__ import annotations

import time
from celery.signals import (
    task_prerun,
    task_postrun,
    task_failure,
    task_success,
    task_retry,
)

from ringo_backend.prometheus import (
    celery_tasks_total,
    celery_task_duration_seconds,
)


# Глобальный словарь для хранения времени начала выполнения задач
_task_start_times = {}


@task_prerun.connect
def task_prerun_handler(sender=None, task_id=None, task=None, **kwargs):
    """Записываем время начала выполнения задачи."""
    _task_start_times[task_id] = time.time()


@task_postrun.connect
def task_postrun_handler(sender=None, task_id=None, task=None, **kwargs):
    """Записываем метрики после выполнения задачи."""
    if task_id in _task_start_times:
        duration = time.time() - _task_start_times[task_id]
        task_name = task.name if task else "unknown"
        
        celery_task_duration_seconds.labels(task_name=task_name).observe(duration)
        
        # Удаляем из словаря
        del _task_start_times[task_id]


@task_success.connect
def task_success_handler(sender=None, **kwargs):
    """Записываем успешное выполнение задачи."""
    task_name = sender.name if sender else "unknown"
    celery_tasks_total.labels(task_name=task_name, status="success").inc()


@task_failure.connect
def task_failure_handler(sender=None, task_id=None, exception=None, **kwargs):
    """Записываем ошибку выполнения задачи."""
    task_name = sender.name if sender else "unknown"
    celery_tasks_total.labels(task_name=task_name, status="failure").inc()
    
    # Очищаем время начала, если оно есть
    if task_id in _task_start_times:
        del _task_start_times[task_id]


@task_retry.connect
def task_retry_handler(sender=None, **kwargs):
    """Записываем повторную попытку выполнения задачи."""
    task_name = sender.name if sender else "unknown"
    celery_tasks_total.labels(task_name=task_name, status="retry").inc()


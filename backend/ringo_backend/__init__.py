from __future__ import annotations

# КРИТИЧНО: Применяем исправления ДО импорта Django settings
# Очищаем переменные окружения PostgreSQL, чтобы libpq не читал системные переменные Windows
import os
_postgres_env_vars = ['PGHOST', 'PGUSER', 'PGPASSWORD', 'PGDATABASE', 'PGPORT', 'PGPASSFILE']
for var in _postgres_env_vars:
    if var not in os.environ:
        os.environ[var] = ''

# Применяем monkey patch для psycopg2.connect
def _patch_psycopg2():
    """Патчит psycopg2.connect для правильной обработки кодировки."""
    try:
        import psycopg2
        import urllib.parse
        from psycopg2 import connect as original_connect
        
        def patched_connect(dsn=None, connection_factory=None, cursor_factory=None, **kwargs):
            """Патченная версия psycopg2.connect."""
            # Временно очищаем переменные окружения PostgreSQL
            old_env = {}
            for var in ['PGHOST', 'PGUSER', 'PGPASSWORD', 'PGDATABASE', 'PGPORT', 'PGPASSFILE']:
                if var in os.environ:
                    old_env[var] = os.environ[var]
                    del os.environ[var]
            
            try:
                # Если переданы параметры через kwargs, формируем DSN строку явно
                if kwargs and ('dbname' in kwargs or 'user' in kwargs):
                    dsn_parts = []
                    if 'dbname' in kwargs:
                        dsn_parts.append(f"dbname={urllib.parse.quote(str(kwargs['dbname']), safe='')}")
                    if 'user' in kwargs:
                        dsn_parts.append(f"user={urllib.parse.quote(str(kwargs['user']), safe='')}")
                    if 'password' in kwargs:
                        dsn_parts.append(f"password={urllib.parse.quote(str(kwargs['password']), safe='')}")
                    if 'host' in kwargs:
                        dsn_parts.append(f"host={urllib.parse.quote(str(kwargs['host']), safe='')}")
                    if 'port' in kwargs:
                        dsn_parts.append(f"port={urllib.parse.quote(str(kwargs['port']), safe='')}")
                    
                    dsn_string = ' '.join(dsn_parts)
                    # Удаляем параметры из kwargs, так как они теперь в dsn
                    kwargs_clean = {k: v for k, v in kwargs.items() 
                                   if k not in ['dbname', 'user', 'password', 'host', 'port']}
                    return original_connect(dsn=dsn_string, connection_factory=connection_factory,
                                           cursor_factory=cursor_factory, **kwargs_clean)
                
                # Если передан dsn как строка или ничего, используем оригинальный метод
                return original_connect(dsn=dsn, connection_factory=connection_factory,
                                       cursor_factory=cursor_factory, **kwargs)
            finally:
                # Восстанавливаем переменные окружения
                for var, value in old_env.items():
                    os.environ[var] = value
        
        # Применяем патч
        psycopg2.connect = patched_connect
    except ImportError:
        # psycopg2 еще не установлен
        pass

# Пытаемся применить патч сразу
_patch_psycopg2()

from ringo_backend.celery import app as celery_app

__all__ = ["__version__", "celery_app"]

__version__ = "0.1.0"


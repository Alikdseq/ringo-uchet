"""
Monkey patch для psycopg2 для исправления проблемы UnicodeDecodeError на Windows.

Проблема: libpq читает системные переменные Windows с кириллицей через Windows API
в системной кодировке, что вызывает ошибку при декодировании как UTF-8.

Решение: Перехватываем вызов psycopg2.connect и явно формируем DSN строку
с правильной кодировкой, обходя чтение системных переменных.
"""
import os
import urllib.parse


def patch_psycopg2():
    """
    Применяет патч к psycopg2.connect для исправления проблемы с кодировкой.
    Должно быть вызвано ДО импорта Django или psycopg2.
    """
    try:
        import psycopg2
        from psycopg2 import connect as original_connect
        
        def patched_connect(dsn=None, connection_factory=None, cursor_factory=None, **kwargs):
            """
            Патченная версия psycopg2.connect, которая правильно обрабатывает кодировку.
            """
            # Временно очищаем переменные окружения PostgreSQL
            old_env = {}
            for var in ['PGHOST', 'PGUSER', 'PGPASSWORD', 'PGDATABASE', 'PGPORT', 'PGPASSFILE']:
                if var in os.environ:
                    old_env[var] = os.environ[var]
                    del os.environ[var]
            
            try:
                # Если передан dsn как строка, оставляем как есть
                if dsn and isinstance(dsn, str):
                    return original_connect(dsn=dsn, connection_factory=connection_factory, 
                                           cursor_factory=cursor_factory, **kwargs)
                
                # Если переданы параметры через kwargs, формируем DSN строку явно
                if kwargs:
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
                
                # Если ничего не передано, используем оригинальный метод
                return original_connect(dsn=dsn, connection_factory=connection_factory,
                                       cursor_factory=cursor_factory, **kwargs)
            finally:
                # Восстанавливаем переменные окружения
                for var, value in old_env.items():
                    os.environ[var] = value
        
        # Применяем патч
        psycopg2.connect = patched_connect
        # Также патчим __init__.py если нужно
        if hasattr(psycopg2, '__init__'):
            psycopg2.__init__.connect = patched_connect
            
    except ImportError:
        # psycopg2 еще не установлен, патч будет применен позже
        pass


# Применяем патч сразу при импорте модуля
patch_psycopg2()


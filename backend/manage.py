#!/usr/bin/env python
import os
import sys
import urllib.parse

# КРИТИЧНО: Исправление проблемы с UnicodeDecodeError в psycopg2 на Windows
# Должно быть выполнено ДО любого импорта Django или psycopg2

# 1. Устанавливаем PYTHONUTF8=1 для принудительной UTF-8 обработки
if 'PYTHONUTF8' not in os.environ:
    os.environ['PYTHONUTF8'] = '1'

# 2. Очищаем переменные окружения PostgreSQL, чтобы libpq не читал системные переменные Windows
# libpq читает эти переменные через Windows API в системной кодировке (Windows-1251),
# что вызывает ошибку когда USERNAME/USERPROFILE содержат кириллицу
_postgres_env_vars = ['PGHOST', 'PGUSER', 'PGPASSWORD', 'PGDATABASE', 'PGPORT', 'PGPASSFILE']
for var in _postgres_env_vars:
    # Устанавливаем пустое значение, чтобы libpq не использовал системные переменные
    os.environ[var] = ''

# 3. Monkey patch для psycopg2.connect - применяется сразу после импорта psycopg2
def patch_psycopg2_connect():
    """Патчит psycopg2.connect для правильной обработки кодировки."""
    try:
        import psycopg2
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
        # psycopg2 еще не установлен, патч будет применен позже через __init__.py
        pass

# Регистрируем патч для применения после импорта psycopg2
# Это будет вызвано когда Django импортирует psycopg2
import importlib.util
if importlib.util.find_spec('psycopg2') is not None:
    patch_psycopg2_connect()
else:
    # Если psycopg2 еще не импортирован, патчим его при первом импорте
    import builtins
    original_import = builtins.__import__
    
    def patched_import(name, *args, **kwargs):
        module = original_import(name, *args, **kwargs)
        if name == 'psycopg2' or (isinstance(name, str) and name.startswith('psycopg2')):
            patch_psycopg2_connect()
        return module
    
    builtins.__import__ = patched_import


def main():
    """Run administrative tasks."""
    os.environ.setdefault("DJANGO_SETTINGS_MODULE", "ringo_backend.settings.local")
    from django.core.management import execute_from_command_line

    execute_from_command_line(sys.argv)


if __name__ == "__main__":
    main()


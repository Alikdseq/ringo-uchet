"""
Патч для исправления проблемы UnicodeDecodeError в psycopg2 на Windows.

Проблема: libpq читает системные переменные Windows (USERNAME, USERPROFILE) 
с кириллицей через Windows API в системной кодировке, что вызывает ошибку 
при декодировании как UTF-8.

Решение: Переопределяем метод get_new_connection в Django PostgreSQL backend,
чтобы явно формировать DSN строку с правильной кодировкой UTF-8.
"""
import os
import urllib.parse
from django.db.backends.postgresql.base import DatabaseWrapper as BaseDatabaseWrapper


class DatabaseWrapper(BaseDatabaseWrapper):
    """Кастомный Database wrapper для исправления проблемы с кодировкой."""
    
    def get_new_connection(self, conn_params):
        """
        Переопределяем метод подключения для явного формирования DSN строки.
        """
        # Убеждаемся, что все параметры в UTF-8
        conn_params = conn_params.copy()
        
        # Кодируем все строковые параметры для безопасной передачи в URL
        for key in ['dbname', 'user', 'password', 'host', 'port']:
            if key in conn_params and conn_params[key]:
                value = str(conn_params[key])
                # Если значение уже в байтах, декодируем как UTF-8
                if isinstance(value, bytes):
                    try:
                        value = value.decode('utf-8')
                    except UnicodeDecodeError:
                        # Если не получается декодировать как UTF-8, пробуем Windows-1251
                        try:
                            value = value.decode('windows-1251')
                        except (UnicodeDecodeError, LookupError):
                            # В крайнем случае используем errors='replace'
                            value = value.decode('utf-8', errors='replace')
                conn_params[key] = value
        
        # Формируем DSN строку явно, кодируя все параметры
        dsn_parts = []
        if 'dbname' in conn_params and conn_params['dbname']:
            dsn_parts.append(f"dbname={urllib.parse.quote(str(conn_params['dbname']), safe='')}")
        if 'user' in conn_params and conn_params['user']:
            dsn_parts.append(f"user={urllib.parse.quote(str(conn_params['user']), safe='')}")
        if 'password' in conn_params and conn_params['password']:
            dsn_parts.append(f"password={urllib.parse.quote(str(conn_params['password']), safe='')}")
        if 'host' in conn_params and conn_params['host']:
            dsn_parts.append(f"host={urllib.parse.quote(str(conn_params['host']), safe='')}")
        if 'port' in conn_params and conn_params['port']:
            dsn_parts.append(f"port={urllib.parse.quote(str(conn_params['port']), safe='')}")
        
        # Используем DSN строку вместо параметров
        dsn = ' '.join(dsn_parts)
        
        # Временно очищаем переменные окружения PostgreSQL, чтобы libpq не использовал их
        old_env = {}
        for var in ['PGHOST', 'PGUSER', 'PGPASSWORD', 'PGDATABASE', 'PGPORT', 'PGPASSFILE']:
            if var in os.environ:
                old_env[var] = os.environ[var]
                del os.environ[var]
        
        try:
            # Вызываем оригинальный метод, но передаем dsn строку
            # Модифицируем conn_params для использования dsn
            conn_params_with_dsn = {'dsn': dsn}
            # Добавляем остальные параметры, которые могут быть нужны
            for key in ['connect_timeout', 'sslmode', 'options']:
                if key in conn_params:
                    conn_params_with_dsn[key] = conn_params[key]
            
            # Используем оригинальный метод, но с DSN строкой
            return super().get_new_connection(conn_params_with_dsn)
        finally:
            # Восстанавливаем переменные окружения
            for var, value in old_env.items():
                os.environ[var] = value


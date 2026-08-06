"""
Windows-only Django DB wrapper workaround (Cyrillic paths / libpq).

On Linux/Docker the stock Django PostgreSQL backend is used unchanged.
"""
from __future__ import annotations

import os
import sys

from django.db.backends.postgresql.base import DatabaseWrapper as BaseDatabaseWrapper

_PG_ENV_VARS = ("PGHOST", "PGUSER", "PGPASSWORD", "PGDATABASE", "PGPORT", "PGPASSFILE")


class DatabaseWrapper(BaseDatabaseWrapper):
    def get_new_connection(self, conn_params):
        if sys.platform != "win32":
            return super().get_new_connection(conn_params)

        old_env = {}
        for var in _PG_ENV_VARS:
            if var in os.environ:
                old_env[var] = os.environ.pop(var)
        try:
            return super().get_new_connection(conn_params)
        finally:
            os.environ.update(old_env)

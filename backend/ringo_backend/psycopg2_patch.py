"""
Windows-only monkey patch for psycopg2 (Cyrillic USERNAME via Windows API).

On Linux/Docker this is a no-op. Never URL-encode keyword DSN passwords —
that turns "!!" into "%21%21" and breaks PostgreSQL auth.
"""
from __future__ import annotations

import os
import sys

_PG_ENV_VARS = ("PGHOST", "PGUSER", "PGPASSWORD", "PGDATABASE", "PGPORT", "PGPASSFILE")


def patch_psycopg2() -> None:
    if sys.platform != "win32":
        return
    try:
        import psycopg2
        from psycopg2 import connect as original_connect
    except ImportError:
        return

    def patched_connect(dsn=None, connection_factory=None, cursor_factory=None, **kwargs):
        old_env = {}
        for var in _PG_ENV_VARS:
            if var in os.environ:
                old_env[var] = os.environ.pop(var)
        try:
            return original_connect(
                dsn=dsn,
                connection_factory=connection_factory,
                cursor_factory=cursor_factory,
                **kwargs,
            )
        finally:
            os.environ.update(old_env)

    psycopg2.connect = patched_connect  # type: ignore[assignment]


patch_psycopg2()

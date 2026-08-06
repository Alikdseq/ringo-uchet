from __future__ import annotations

"""
Windows-only workaround: libpq/psycopg2 could mis-read Cyrillic USERNAME
via Windows API. On Linux/Docker these hacks MUST NOT run — they set
PGPASSWORD='' and URL-encode passwords into keyword DSNs, which breaks auth.
"""

import os
import sys

__version__ = "0.1.0"

_PG_ENV_VARS = ("PGHOST", "PGUSER", "PGPASSWORD", "PGDATABASE", "PGPORT", "PGPASSFILE")


def _is_windows() -> bool:
    return sys.platform == "win32"


def _clear_pg_env_for_windows() -> None:
    """Unset PG* vars only on Windows so libpq won't read broken system env."""
    if not _is_windows():
        return
    for var in _PG_ENV_VARS:
        os.environ.pop(var, None)


def _patch_psycopg2_windows_only() -> None:
    if not _is_windows():
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
            # Pass kwargs through unchanged — never URL-encode keyword DSN values
            return original_connect(
                dsn=dsn,
                connection_factory=connection_factory,
                cursor_factory=cursor_factory,
                **kwargs,
            )
        finally:
            os.environ.update(old_env)

    psycopg2.connect = patched_connect  # type: ignore[assignment]


_clear_pg_env_for_windows()
_patch_psycopg2_windows_only()

from ringo_backend.celery import app as celery_app  # noqa: E402

__all__ = ["__version__", "celery_app"]

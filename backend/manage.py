#!/usr/bin/env python
"""Django's command-line utility for administrative tasks."""
from __future__ import annotations

import os
import sys


def _apply_windows_pg_workaround() -> None:
    """Only on Windows: drop PG* env that libpq may mis-decode (Cyrillic paths)."""
    if sys.platform != "win32":
        return
    os.environ.setdefault("PYTHONUTF8", "1")
    for var in ("PGHOST", "PGUSER", "PGPASSWORD", "PGDATABASE", "PGPORT", "PGPASSFILE"):
        os.environ.pop(var, None)


def main() -> None:
    _apply_windows_pg_workaround()
    os.environ.setdefault("DJANGO_SETTINGS_MODULE", "ringo_backend.settings.local")
    from django.core.management import execute_from_command_line

    execute_from_command_line(sys.argv)


if __name__ == "__main__":
    main()

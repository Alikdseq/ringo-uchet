#!/bin/sh
# Entrypoint for django-api in production
set -eu

echo "Waiting for database..."
python - <<'PY'
import os, time, sys
import django
os.environ.setdefault("DJANGO_SETTINGS_MODULE", os.environ.get("DJANGO_SETTINGS_MODULE", "ringo_backend.settings.prod"))
# Lightweight TCP wait without full Django first
import socket
host = os.environ.get("POSTGRES_HOST", "db")
port = int(os.environ.get("POSTGRES_PORT", "5432"))
for i in range(60):
    try:
        with socket.create_connection((host, port), timeout=2):
            print(f"DB {host}:{port} is reachable")
            break
    except OSError:
        time.sleep(1)
else:
    print("Database is not reachable", file=sys.stderr)
    sys.exit(1)
PY

echo "Running migrations..."
python manage.py migrate --noinput

echo "Collecting static files..."
python manage.py collectstatic --noinput

echo "Starting gunicorn..."
exec gunicorn ringo_backend.wsgi:application \
  --bind 0.0.0.0:8000 \
  --workers "${GUNICORN_WORKERS:-2}" \
  --timeout "${GUNICORN_TIMEOUT:-120}" \
  --access-logfile - \
  --error-logfile -

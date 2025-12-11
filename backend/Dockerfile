FROM python:3.11-slim AS base

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=off \
    PIP_DISABLE_PIP_VERSION_CHECK=on \
    PIP_DEFAULT_TIMEOUT=100

WORKDIR /app

# System deps (including WeasyPrint dependencies)
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        build-essential \
        libpq-dev \
        # WeasyPrint dependencies
        libpango-1.0-0 \
        libpangoft2-1.0-0 \
        libharfbuzz0b \
        libpango1.0-dev \
        libcairo2 \
        libcairo2-dev \
        libgobject-2.0-0 \
        libgirepository-1.0-1 \
        libgdk-pixbuf-xlib-2.0-0 \
        libgdk-pixbuf-xlib-2.0-dev \
        gir1.2-pango-1.0 \
        shared-mime-info \
        fontconfig \
        fonts-dejavu-core \
        && \
    rm -rf /var/lib/apt/lists/*

COPY requirements.txt requirements.txt
RUN pip install --upgrade pip && pip install -r requirements.txt


RUN pip install gunicorn

COPY . .

CMD ["gunicorn", "--bind", "0.0.0.0:8000", "ringo_backend.wsgi:application"]

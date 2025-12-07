DOCKER_COMPOSE ?= docker compose

.PHONY: help up down build logs shell migrate makemigrations collectstatic test lint

help:
	@echo "Available targets:"
	@echo "  make up              # Start all containers"
	@echo "  make down            # Stop all containers"
	@echo "  make build           # Build images"
	@echo "  make logs            # Tail backend logs"
	@echo "  make shell           # Django shell inside container"
	@echo "  make migrate         # Apply migrations"
	@echo "  make makemigrations  # Create migrations"
	@echo "  make test            # Run backend tests"
	@echo "  make lint            # Run linters"

up:
	$(DOCKER_COMPOSE) up -d

down:
	$(DOCKER_COMPOSE) down

build:
	$(DOCKER_COMPOSE) build

logs:
	$(DOCKER_COMPOSE) logs -f django-api

shell:
	$(DOCKER_COMPOSE) exec django-api python manage.py shell

migrate:
	$(DOCKER_COMPOSE) exec django-api python manage.py migrate

makemigrations:
	$(DOCKER_COMPOSE) exec django-api python manage.py makemigrations

collectstatic:
	$(DOCKER_COMPOSE) exec django-api python manage.py collectstatic --noinput

test:
	$(DOCKER_COMPOSE) exec django-api python manage.py test

lint:
	$(DOCKER_COMPOSE) exec django-api flake8 .


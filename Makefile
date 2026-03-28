VERSION    := $(shell cat VERSION)
IMAGE_NAME := student-api

.PHONY: help install run test lint db-init db-migrate db-upgrade db-downgrade clean \
        docker-build docker-run docker-stop docker-push docker-clean \
        compose-db compose-migrate compose-build compose-up \
        compose-down compose-logs compose-ps compose-clean

help:
	@echo "── Local dev ────────────────────────────────────────────────────────"
	@echo "  install                   Install Python dependencies"
	@echo "  run                       Start the Flask development server"
	@echo "  test                      Run unit tests with pytest"
	@echo "  lint                      Run flake8 code linting"
	@echo "  db-init                   Initialise Flask-Migrate (run once)"
	@echo "  db-migrate message=<msg>  Generate a new migration"
	@echo "  db-upgrade                Apply all pending migrations"
	@echo "  db-downgrade              Roll back the last migration"
	@echo "  clean                     Remove __pycache__ and test cache dirs"
	@echo ""
	@echo "── Docker (standalone) ─────────────────────────────────────────────"
	@echo "  docker-build              Build image  $(IMAGE_NAME):$(VERSION)"
	@echo "  docker-run                Run standalone container (uses .env)"
	@echo "  docker-stop               Stop the standalone container"
	@echo "  docker-push registry=<r>  Push image to registry"
	@echo "  docker-clean              Remove local image"
	@echo ""
	@echo "── Docker Compose (one-click dev setup) ────────────────────────────"
	@echo "  compose-db                Start only the PostgreSQL container"
	@echo "  compose-migrate           Run DB migrations inside a one-off container"
	@echo "  compose-build             Build the API Docker image"
	@echo "  compose-up                Full startup: DB → migrations → API  ★"
	@echo "  compose-down              Stop and remove all compose containers"
	@echo "  compose-logs              Tail logs from all compose services"
	@echo "  compose-ps                Show status of compose services"
	@echo "  compose-clean             Remove containers, volumes, and image"

install:
	pip install -r requirements.txt

run:
	python run.py

test:
	pytest tests/ -v

lint:
	flake8 app/ tests/ run.py

db-init:
	flask db init

db-migrate:
	flask db migrate -m "$(message)"

db-upgrade:
	flask db upgrade

db-downgrade:
	flask db downgrade

clean:
	python -c "import shutil, pathlib; [shutil.rmtree(str(p)) for p in pathlib.Path('.').rglob('__pycache__') if p.is_dir()]; shutil.rmtree('.pytest_cache', ignore_errors=True)"

# ── Docker targets ─────────────────────────────────────────────────────────
docker-build:
	docker build -t $(IMAGE_NAME):$(VERSION) .

docker-run:
	docker run --rm \
		-p 5000:5000 \
		--env-file .env \
		--name student-api \
		$(IMAGE_NAME):$(VERSION)

docker-stop:
	docker stop student-api || true

docker-push:
	docker tag $(IMAGE_NAME):$(VERSION) $(registry)/$(IMAGE_NAME):$(VERSION)
	docker push $(registry)/$(IMAGE_NAME):$(VERSION)

docker-clean:
	docker rmi $(IMAGE_NAME):$(VERSION) || true

# ── Docker Compose targets ──────────────────────────────────────────────────
compose-db:
	@echo "Starting PostgreSQL container..."
	docker compose up -d db
	@echo "Waiting for PostgreSQL to be healthy..."
	@until docker compose exec db pg_isready -U "$${DB_USER:-student}" -d "$${DB_NAME:-students_db}" > /dev/null 2>&1; do \
		echo "  DB not ready yet, retrying in 2s..."; sleep 2; \
	done
	@echo "PostgreSQL is ready."

compose-migrate: compose-db
	@echo "Running DB migrations..."
	docker compose run --rm \
		-e FLASK_APP=run.py \
		api flask db upgrade
	@echo "Migrations applied."

compose-build:
	@echo "Building API image $(IMAGE_NAME):$(VERSION)..."
	docker compose build api

compose-up: compose-build
	@echo "Starting all services (DB → migrations handled by entrypoint → API)..."
	docker compose up -d
	@echo ""
	@echo "API is running at http://localhost:5000/api/v1/healthcheck"
	@echo "Run 'make compose-logs' to follow logs."

compose-down:
	docker compose down

compose-logs:
	docker compose logs -f

compose-ps:
	docker compose ps

compose-clean:
	docker compose down -v --rmi local


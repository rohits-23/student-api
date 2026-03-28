# Student CRUD REST API

A RESTful API for managing student records, built with **Python** and **Flask**.

## Features

- Full CRUD operations — create, read, update, delete students
- API versioning (`/api/v1/...`)
- Database migrations via Flask-Migrate (Alembic)
- Environment-based configuration (no secrets hardcoded in code)
- Structured JSON logging with configurable log levels
- `/healthcheck` endpoint
- Unit tests with pytest + pytest-flask
- Postman collection included

## Tech Stack

| Component  | Technology            |
|------------|-----------------------|
| Framework  | Flask 3.0             |
| ORM        | Flask-SQLAlchemy      |
| Migrations | Flask-Migrate (Alembic)|
| Database   | PostgreSQL / SQLite   |
| Testing    | pytest, pytest-flask  |
| Config     | python-dotenv         |

## Project Structure

```
student-api/
├── app/
│   ├── __init__.py          # Application factory
│   ├── config.py            # Configuration classes (dev / test / prod)
│   ├── extensions.py        # Flask extension instances (db, migrate)
│   ├── models/
│   │   └── student.py       # Student SQLAlchemy model
│   └── api/
│       └── v1/
│           ├── __init__.py  # Blueprint definition
│           ├── health.py    # GET /api/v1/healthcheck
│           └── students.py  # CRUD endpoints for /api/v1/students
├── tests/
│   ├── conftest.py          # Shared pytest fixtures
│   ├── test_health.py
│   └── test_students.py
├── migrations/
│   └── sql/
│       └── 001_create_students_table.sql  # Reference SQL script
├── postman/
│   └── student_api.postman_collection.json
├── .env.example
├── Makefile
├── requirements.txt
└── run.py
```

## Prerequisites

Before starting, make sure the following tools are installed:

| Tool | Minimum Version | Required For |
|------|----------------|--------------|
| [Python](https://www.python.org/downloads/) | 3.9+ | Local dev & tests |
| [Docker Desktop](https://www.docker.com/products/docker-desktop/) | 4.x+ | `compose-*` targets |
| [GNU Make](https://www.gnu.org/software/make/) | 3.8+ | `make` targets (Linux/macOS) |
| [Git](https://git-scm.com/) | 2.x+ | Cloning the repo |

### Automated tool installation

```bash
# Linux / macOS
bash scripts/install-tools.sh

# Windows — run in an ELEVATED PowerShell
.\scripts\install-tools.ps1
```

> **Windows note:** `make` is not available by default. Either install it via [Chocolatey](https://chocolatey.org/) (`choco install make`) or use `.\make.ps1 <target>` instead of `make <target>` throughout this document.


## Local Setup

### 1. Clone the repository

```bash
git clone <your-repo-url>
cd student-api
```

### 2. Create and activate a virtual environment

```bash
# macOS / Linux
python -m venv venv
source venv/bin/activate

# Windows — PowerShell
python -m venv venv
.\venv\Scripts\Activate.ps1
```

### 3. Install dependencies

```bash
make install
# or: pip install -r requirements.txt
```

### 4. Configure environment variables

```bash
cp .env.example .env
# Open .env and set DATABASE_URL and SECRET_KEY
```

### 5. Run database migrations

```bash
# Initialise the migration repository (first time only)
make db-init

# Auto-generate the initial migration
make db-migrate message="create students table"

# Apply migrations to the database
make db-upgrade
```

> **SQLite note:** for local development no additional setup is needed — SQLite is used automatically when `DATABASE_URL` is left as `sqlite:///students_dev.db`.

### 6. Start the development server

```bash
make run
# Server starts at http://localhost:5000
```

---

## One-Click Local Development with Docker Compose

This is the **recommended way** to run the API locally. A single command starts PostgreSQL and the API together.

### Prerequisites

- Docker Desktop installed and running (see [Prerequisites](#prerequisites) above)
- `.env` file configured (step 1 below)

### Step-by-step

#### 1. Configure environment variables

```bash
cp .env.example .env
# Open .env — the defaults work out of the box for local development.
# Change DB_PASSWORD and SECRET_KEY if desired.
```

#### 2. Start the PostgreSQL container

```bash
make compose-db          # Linux / macOS
.\make.ps1 compose-db    # Windows PowerShell
```

Waits until the `pg_isready` health check passes before returning.

#### 3. Build the API Docker image

```bash
make compose-build          # Linux / macOS
.\make.ps1 compose-build    # Windows PowerShell
```

#### 4. Run DB migrations

```bash
make compose-migrate          # Linux / macOS
.\make.ps1 compose-migrate    # Windows PowerShell
```

> **Note:** Steps 2–4 are also run automatically by `compose-up` (step 5). You only need them individually when you want granular control.

#### 5. Start everything in one command ★

```bash
make compose-up          # Linux / macOS
.\make.ps1 compose-up    # Windows PowerShell
```

This target:
1. Builds the API image
2. Starts both the `db` and `api` containers via `docker compose up -d`
3. docker-compose waits for PostgreSQL to pass its health check before starting the API
4. The API entrypoint (`entrypoint.sh`) runs `flask db upgrade` automatically
5. Gunicorn starts and the API is available at **http://localhost:5000**

Verify it's running:
```
GET http://localhost:5000/api/v1/healthcheck
```

#### 6. Follow logs

```bash
make compose-logs          # Linux / macOS
.\make.ps1 compose-logs    # Windows PowerShell
```

#### 7. Stop everything

```bash
make compose-down          # Linux / macOS
.\make.ps1 compose-down    # Windows PowerShell
```

#### Teardown (remove containers + volumes + image)

```bash
make compose-clean          # Linux / macOS
.\make.ps1 compose-clean    # Windows PowerShell
```

---

### Docker Compose architecture

```
┌─────────────────────────────────────────────────────────────┐
│  docker-compose.yml                                         │
│                                                             │
│   ┌──────────────────┐        ┌──────────────────────────┐ │
│   │  db              │  ───►  │  api                     │ │
│   │  postgres:16     │        │  student-api:1.0.0       │ │
│   │  port 5432       │        │  port 5000               │ │
│   │  health-checked  │        │  depends_on: db healthy  │ │
│   └──────────────────┘        └──────────────────────────┘ │
│                                                             │
│   Volume: postgres_data   Network: student-net              │
└─────────────────────────────────────────────────────────────┘
```

- `db` exposes PostgreSQL on `localhost:5432` (configurable via `DB_PORT` in `.env`)
- `api` connects to `db` using the internal Docker network hostname `db`
- `DATABASE_URL` is constructed from `DB_USER`, `DB_PASSWORD`, `DB_NAME` — no need to edit it manually for compose
- PostgreSQL data persists in a named Docker volume (`postgres_data`) across container restarts

---

## Docker

### Prerequisites

- [Docker Desktop](https://www.docker.com/products/docker-desktop/) installed and running

### Image versioning

The image is tagged using **semantic versioning** sourced from the [`VERSION`](VERSION) file (currently `1.0.0`). Never use the `latest` tag in production.

### Build the image

```bash
# Linux / macOS / Git Bash
make docker-build

# Windows PowerShell
.\make.ps1 docker-build
```

This builds a **multi-stage** image:

| Stage | Base | Purpose |
|-------|------|---------|
| `builder` | `python:3.12-slim` | Install all dependencies into `/venv` |
| `runtime` | `python:3.12-slim` | Copy only `/venv` + app source; run as non-root |

### Run the container

Environment variables are **never baked into the image**. Pass them at runtime via `--env-file`:

```bash
# 1. Make sure .env exists (copy from .env.example and set DATABASE_URL, SECRET_KEY)
cp .env.example .env

# 2. Run
make docker-run          # Linux / macOS
.\make.ps1 docker-run    # Windows PowerShell
```

The container:
- Runs `flask db upgrade` automatically on startup
- Starts **Gunicorn** with 2 workers and 2 threads
- Listens on port `5000`

Access the API at `http://localhost:5000/api/v1/healthcheck`.

### Override environment variables at runtime

```bash
docker run --rm -p 5000:5000 \
  -e DATABASE_URL="postgresql://user:pass@host:5432/students" \
  -e SECRET_KEY="your-secret" \
  -e LOG_LEVEL="DEBUG" \
  -e GUNICORN_WORKERS=4 \
  student-api:1.0.0
```

### Stop the container

```bash
make docker-stop          # Linux / macOS
.\make.ps1 docker-stop    # Windows PowerShell
```

### Push to a registry

```bash
make docker-push registry=myregistry.io          # Linux / macOS
.\make.ps1 docker-push -registry myregistry.io   # Windows PowerShell
```

### Remove the local image

```bash
make docker-clean          # Linux / macOS
.\make.ps1 docker-clean    # Windows PowerShell
```

### Database note for Docker

SQLite stores its file inside the container and is **lost when the container stops**. For persistent storage either:

- **Mount a volume**: `docker run -v $(pwd)/data:/app/data -e DATABASE_URL=sqlite:////app/data/students.db ...`
- **Use PostgreSQL**: set `DATABASE_URL=postgresql://user:pass@host:5432/students` and install `psycopg2-binary` (`pip install psycopg2-binary`).

---



Base URL: `http://localhost:5000/api/v1`

| Method | Endpoint              | Description            |
|--------|-----------------------|------------------------|
| GET    | `/healthcheck`        | Service health check   |
| GET    | `/students`           | List all students      |
| POST   | `/students`           | Create a new student   |
| GET    | `/students/<id>`      | Get student by ID      |
| PUT    | `/students/<id>`      | Update student by ID   |
| DELETE | `/students/<id>`      | Delete student by ID   |

### Student object

```json
{
  "id": 1,
  "name": "Alice Smith",
  "email": "alice@example.com",
  "age": 21,
  "grade": "A",
  "created_at": "2024-01-15T10:30:00",
  "updated_at": "2024-01-15T10:30:00"
}
```

### Create / Update fields

| Field   | Type    | Required | Description          |
|---------|---------|----------|----------------------|
| `name`  | string  | yes (POST) | Student full name  |
| `email` | string  | yes (POST) | Unique email address |
| `age`   | integer | no       | Student age          |
| `grade` | string  | no       | Academic grade       |

### HTTP Status Codes

| Code | Meaning                                     |
|------|---------------------------------------------|
| 200  | OK                                          |
| 201  | Created                                     |
| 400  | Bad Request — missing or malformed body     |
| 404  | Not Found                                   |
| 405  | Method Not Allowed                          |
| 409  | Conflict — duplicate email                  |
| 500  | Internal Server Error                       |

---

## Running Tests

```bash
make test
# or: pytest tests/ -v
```

Tests use an in-memory SQLite database and are fully isolated (each test starts with a clean state).

---

## Environment Variables

| Variable           | Default                   | Description                                      |
|--------------------|---------------------------|--------------------------------------------------|
| `FLASK_APP`        | `run.py`                  | Entry point for Flask CLI commands               |
| `FLASK_ENV`        | `development`             | `development` / `testing` / `production`         |
| `FLASK_HOST`       | `0.0.0.0`                 | Host address to bind to                          |
| `FLASK_PORT`       | `5000`                    | Port to listen on                                |
| `FLASK_DEBUG`      | `false`                   | Enable Flask debug mode                          |
| `SECRET_KEY`       | —                         | **Required in production** — long random string  |
| `DATABASE_URL`     | `sqlite:///students_dev.db` | Primary database connection string             |
| `TEST_DATABASE_URL`| `sqlite:///:memory:`      | Database used by pytest                          |
| `LOG_LEVEL`        | `INFO`                    | `DEBUG` / `INFO` / `WARNING` / `ERROR`           |

---

## Postman Collection

1. Open Postman → **Import** → select `postman/student_api.postman_collection.json`.
2. Set the `base_url` collection variable to `http://localhost:5000` if it is not already set.
3. Run requests in order: *Create Student* → *Get All Students* → *Get by ID* → *Update* → *Delete*.

---

---

## CI Pipeline (GitHub Actions)

The CI pipeline runs on a **self-hosted GitHub Actions runner** installed on your local machine. It is defined in [.github/workflows/ci.yml](.github/workflows/ci.yml).

### Pipeline stages

```
push / PR / workflow_dispatch
        │
        ▼
┌──────────────┐
│  1. Build    │  Install Python dependencies (make install)
└──────┬───────┘
       │
   ┌───┴──── parallel ────┐
   ▼                      ▼
┌──────────┐       ┌──────────────┐
│ 2. Test  │       │  3. Lint     │
│  pytest  │       │  flake8      │
└────┬─────┘       └──────┬───────┘
     └──────── ✓ ─────────┘
                    │
                    ▼  (push to main/master or manual trigger only)
          ┌──────────────────────────┐
          │ 4. Docker Login          │
          │ 5. Docker Build & Push   │
          │    DockerHub             │
          └──────────────────────────┘
```

### Trigger rules

| Event | Condition | Runs |
|-------|-----------|------|
| `push` | to `main` or `master`, code paths changed | All stages |
| `pull_request` | to `main` or `master`, code paths changed | Build + Test + Lint |
| `workflow_dispatch` | manual via GitHub UI | All stages (Docker push optional) |

**Path filters** — the pipeline is skipped for changes to `README.md`, `postman/`, `scripts/`, `migrations/sql/`, etc. It only runs when these paths change: `app/**`, `tests/**`, `run.py`, `requirements.txt`, `Dockerfile`, `docker-compose.yml`, `.github/workflows/**`, `.flake8`.

---

### Setup: GitHub repository & DockerHub

#### 1. Create a GitHub repository

```bash
git init
git add .
git commit -m "initial commit"
git remote add origin https://github.com/<your-username>/<repo-name>.git
git push -u origin main
```

#### 2. Create a DockerHub access token

1. Log in to [hub.docker.com](https://hub.docker.com)
2. **Account Settings** → **Security** → **New Access Token**
3. Name it `github-actions-student-api`, choose **Read & Write**
4. Copy the token — you will only see it once

#### 3. Add GitHub repository secrets

In your GitHub repo go to **Settings** → **Secrets and variables** → **Actions** → **New repository secret**:

| Secret name | Value |
|-------------|-------|
| `DOCKERHUB_USERNAME` | Your DockerHub username |
| `DOCKERHUB_TOKEN` | The access token from step 2 |

---

### Setup: Self-hosted GitHub Actions runner

#### Step 1 — Prerequisites on the runner machine

| Tool | Install |
|------|---------|
| Git + Git Bash | https://git-scm.com/download/win |
| Docker Desktop | https://www.docker.com/products/docker-desktop/ |
| GNU Make | `choco install make` (Chocolatey, run as Admin) |
| Python 3.12 | Auto-installed by `actions/setup-python` in the workflow |

#### Step 2 — Register the runner

1. In your GitHub repo go to **Settings** → **Actions** → **Runners** → **New self-hosted runner**
2. Select **Windows** / **x64**
3. Follow the displayed commands — they look like:

```powershell
# In an elevated PowerShell window:
mkdir C:\actions-runner ; cd C:\actions-runner

# Download the runner
Invoke-WebRequest -Uri https://github.com/actions/runner/releases/download/v2.x.x/actions-runner-win-x64-2.x.x.zip -OutFile actions-runner-win-x64.zip

# Extract
Add-Type -AssemblyName System.IO.Compression.FileSystem
[System.IO.Compression.ZipFile]::ExtractToDirectory("$PWD\actions-runner-win-x64.zip", "$PWD")

# Configure (paste YOUR token from the GitHub UI)
.\config.cmd --url https://github.com/<your-username>/<repo-name> --token <YOUR_TOKEN>

# Install and start as a Windows service
.\svc.cmd install
.\svc.cmd start
```

4. The runner will appear as **Idle** in the GitHub UI — it is ready.

> **Tip:** The runner service starts automatically on boot. To manage it: `.\svc.cmd stop | start | status`.

#### Step 3 — Verify

Push a change to any file in `app/` or `tests/` and watch the **Actions** tab in GitHub for the pipeline to trigger.

#### Manual trigger

1. Go to your repo → **Actions** tab
2. Select **CI** in the left sidebar
3. Click **Run workflow**
4. Toggle "Push Docker image to DockerHub" as needed
5. Click the green **Run workflow** button

---

### Linting locally

```bash
make lint          # Linux / macOS
.\make.ps1 lint    # Windows PowerShell
```

Linting is configured in [.flake8](.flake8): max line length 100, migrations excluded, intentional re-exports in `__init__.py` files allowed.

---

## Makefile Targets

### Local dev

| Target | Description |
|--------|-------------|
| `make install` | Install Python dependencies |
| `make run` | Start the Flask development server |
| `make test` | Run unit tests with pytest |
| `make lint` | Run flake8 code linting |
| `make db-init` | Initialise Flask-Migrate (once only) |
| `make db-migrate message="..."` | Auto-generate a new migration |
| `make db-upgrade` | Apply all pending migrations |
| `make db-downgrade` | Roll back the last applied migration |
| `make clean` | Remove `__pycache__` and test caches |

### Docker Compose

| Target | Description |
|--------|-------------|
| `make compose-db` | Start the PostgreSQL container and wait until healthy |
| `make compose-migrate` | Run `flask db upgrade` inside a one-off container |
| `make compose-build` | Build the API Docker image |
| `make compose-up` | **One command** — build → start DB → start API ★ |
| `make compose-down` | Stop and remove all containers |
| `make compose-logs` | Tail logs from all services |
| `make compose-ps` | Show running container status |
| `make compose-clean` | Remove containers, volumes, and image |

### Docker (standalone)

| Target | Description |
|--------|-------------|
| `make docker-build` | Build image `student-api:<VERSION>` |
| `make docker-run` | Run standalone container using `.env` |
| `make docker-stop` | Stop the standalone container |
| `make docker-push registry=<r>` | Tag and push image to a registry |
| `make docker-clean` | Remove the local Docker image |
#   s t u d e n t - a p i  
 
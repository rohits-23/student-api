# make.ps1 — drop-in Makefile replacement for Windows PowerShell
# Usage: .\make.ps1 <target> [options]
#
# Examples:
#   .\make.ps1 install
#   .\make.ps1 run
#   .\make.ps1 test
#   .\make.ps1 db-init
#   .\make.ps1 db-migrate -message "create students table"
#   .\make.ps1 db-upgrade
#   .\make.ps1 db-downgrade
#   .\make.ps1 docker-build
#   .\make.ps1 docker-run
#   .\make.ps1 docker-stop
#   .\make.ps1 docker-push -registry myregistry.io
#   .\make.ps1 docker-clean
#   .\make.ps1 compose-db
#   .\make.ps1 compose-migrate
#   .\make.ps1 compose-build
#   .\make.ps1 compose-up
#   .\make.ps1 compose-down
#   .\make.ps1 compose-logs
#   .\make.ps1 compose-ps
#   .\make.ps1 compose-clean
#   .\make.ps1 clean

param(
    [Parameter(Position = 0)]
    [string]$Target = "help",

    [string]$message  = "auto-migration",
    [string]$registry = ""
)

# Load .env values so DB_USER, DB_NAME, VERSION are available
if (Test-Path ".env") {
    Get-Content ".env" | Where-Object { $_ -match '^\s*[^#]' -and $_ -match '=' } | ForEach-Object {
        $parts = $_ -split '=', 2
        $key   = $parts[0].Trim()
        $value = $parts[1].Trim().Trim('"')
        if (-not [System.Environment]::GetEnvironmentVariable($key)) {
            [System.Environment]::SetEnvironmentVariable($key, $value, "Process")
        }
    }
}

$VERSION    = (Get-Content VERSION -Raw).Trim()
$IMAGE_NAME = if ($env:IMAGE_NAME) { $env:IMAGE_NAME } else { "student-api" }
$DB_USER    = if ($env:DB_USER)    { $env:DB_USER }    else { "student" }
$DB_NAME    = if ($env:DB_NAME)    { $env:DB_NAME }    else { "students_db" }

switch ($Target) {
    "help" {
        Write-Host ""
        Write-Host "── Local dev ────────────────────────────────────────────────────────"
        Write-Host "  install                              Install Python dependencies"
        Write-Host "  run                                  Start the Flask development server"
        Write-Host "  test                                 Run unit tests with pytest"
        Write-Host "  lint                                 Run flake8 code linting"
        Write-Host "  db-init                              Initialise Flask-Migrate (run once)"
        Write-Host "  db-migrate -message '<msg>'          Generate a new migration"
        Write-Host "  db-upgrade                           Apply all pending migrations"
        Write-Host "  db-downgrade                         Roll back the last migration"
        Write-Host "  clean                                Remove __pycache__ and test cache dirs"
        Write-Host ""
        Write-Host "── Docker (standalone) ─────────────────────────────────────────────"
        Write-Host "  docker-build                         Build image  $IMAGE_NAME`:$VERSION"
        Write-Host "  docker-run                           Run standalone container (uses .env)"
        Write-Host "  docker-stop                          Stop the standalone container"
        Write-Host "  docker-push -registry <host>         Tag and push image to a registry"
        Write-Host "  docker-clean                         Remove the local Docker image"
        Write-Host ""
        Write-Host "── Docker Compose (one-click dev setup) ────────────────────────────"
        Write-Host "  compose-db                           Start only the PostgreSQL container"
        Write-Host "  compose-migrate                      Run DB migrations in a one-off container"
        Write-Host "  compose-build                        Build the API Docker image"
        Write-Host "  compose-up                           Full startup: DB -> migrations -> API  *"
        Write-Host "  compose-down                         Stop and remove all compose containers"
        Write-Host "  compose-logs                         Tail logs from all compose services"
        Write-Host "  compose-ps                           Show status of compose services"
        Write-Host "  compose-clean                        Remove containers + volumes + image"
        Write-Host ""
    }
    "install" {
        pip install -r requirements.txt
    }
    "run" {
        python run.py
    }
    "test" {
        pytest tests/ -v
    }
    "lint" {
        flake8 app/ tests/ run.py
    }
    "db-init" {
        flask db init
    }
    "db-migrate" {
        flask db migrate -m $message
    }
    "db-upgrade" {
        flask db upgrade
    }
    "db-downgrade" {
        flask db downgrade
    }
    "clean" {
        Get-ChildItem -Recurse -Filter "__pycache__" -Directory | Remove-Item -Recurse -Force
        if (Test-Path ".pytest_cache") { Remove-Item ".pytest_cache" -Recurse -Force }
        Write-Host "Cleaned."
    }
    "docker-build" {
        Write-Host "Building $IMAGE_NAME`:$VERSION ..."
        docker build -t "${IMAGE_NAME}:${VERSION}" .
    }
    "docker-run" {
        if (-not (Test-Path ".env")) {
            Write-Error ".env file not found. Copy .env.example to .env and configure it first."
            exit 1
        }
        Write-Host "Running $IMAGE_NAME`:$VERSION on port 5000 ..."
        docker run --rm -p 5000:5000 --env-file .env --name student-api "${IMAGE_NAME}:${VERSION}"
    }
    "docker-stop" {
        docker stop student-api
    }
    "docker-push" {
        if (-not $registry) {
            Write-Error "Provide a registry: .\make.ps1 docker-push -registry myregistry.io"
            exit 1
        }
        $remoteTag = "$registry/${IMAGE_NAME}:${VERSION}"
        docker tag "${IMAGE_NAME}:${VERSION}" $remoteTag
        docker push $remoteTag
    }
    "docker-clean" {
        docker rmi "${IMAGE_NAME}:${VERSION}"
    }
    # ── Docker Compose targets ────────────────────────────────────────────────
    "compose-db" {
        Write-Host "Starting PostgreSQL container..."
        docker compose up -d db
        Write-Host "Waiting for PostgreSQL to be healthy..."
        $retries = 0
        do {
            Start-Sleep -Seconds 2
            $retries++
            $ready = docker compose exec db pg_isready -U $DB_USER -d $DB_NAME 2>$null
            if ($retries -ge 30) { Write-Error "DB never became ready."; exit 1 }
        } until ($LASTEXITCODE -eq 0)
        Write-Host "PostgreSQL is ready."
    }
    "compose-migrate" {
        .\make.ps1 compose-db
        Write-Host "Running DB migrations..."
        docker compose run --rm -e FLASK_APP=run.py api flask db upgrade
        Write-Host "Migrations applied."
    }
    "compose-build" {
        Write-Host "Building API image ${IMAGE_NAME}:${VERSION}..."
        docker compose build api
    }
    "compose-up" {
        .\make.ps1 compose-build
        Write-Host "Starting all services (DB + API)..."
        docker compose up -d
        Write-Host ""
        Write-Host "API is running at http://localhost:5000/api/v1/healthcheck"
        Write-Host "Run '.\make.ps1 compose-logs' to follow logs."
    }
    "compose-down" {
        docker compose down
    }
    "compose-logs" {
        docker compose logs -f
    }
    "compose-ps" {
        docker compose ps
    }
    "compose-clean" {
        docker compose down -v --rmi local
    }
    default {
        Write-Error "Unknown target: '$Target'. Run '.\make.ps1 help' to see available targets."
        exit 1
    }
}

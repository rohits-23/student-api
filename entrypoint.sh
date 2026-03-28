#!/bin/sh
# entrypoint.sh — wait for DB (if PostgreSQL), run migrations, start Gunicorn
set -e

# ── Wait for PostgreSQL to be reachable ───────────────────────────────────────
if echo "${DATABASE_URL:-}" | grep -q "postgresql"; then
    echo "[entrypoint] PostgreSQL detected — checking connectivity..."
    MAX_RETRIES=30
    COUNT=0
    until /venv/bin/python - <<'EOF'
import os, sys
try:
    from sqlalchemy import create_engine, text
    engine = create_engine(os.environ["DATABASE_URL"])
    with engine.connect() as conn:
        conn.execute(text("SELECT 1"))
    sys.exit(0)
except Exception:
    sys.exit(1)
EOF
    do
        COUNT=$((COUNT + 1))
        if [ "$COUNT" -ge "$MAX_RETRIES" ]; then
            echo "[entrypoint] ERROR: Database unreachable after ${MAX_RETRIES} attempts. Exiting."
            exit 1
        fi
        echo "[entrypoint] Database not ready yet (attempt ${COUNT}/${MAX_RETRIES}), retrying in 2s..."
        sleep 2
    done
    echo "[entrypoint] Database is ready."
fi

# ── Apply pending migrations ──────────────────────────────────────────────────
echo "[entrypoint] Applying database migrations..."
/venv/bin/flask db upgrade
echo "[entrypoint] Migrations applied."

# ── Start Gunicorn ────────────────────────────────────────────────────────────
echo "[entrypoint] Starting Gunicorn on ${FLASK_HOST:-0.0.0.0}:${FLASK_PORT:-5000}..."
exec /venv/bin/gunicorn \
    --bind "${FLASK_HOST:-0.0.0.0}:${FLASK_PORT:-5000}" \
    --workers "${GUNICORN_WORKERS:-2}" \
    --threads "${GUNICORN_THREADS:-2}" \
    --access-logfile - \
    --error-logfile - \
    run:app

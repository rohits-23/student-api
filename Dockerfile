# ── Stage 1: builder ──────────────────────────────────────────────────────────
# Install all Python dependencies into an isolated venv.
# Nothing from this stage reaches the final image except /venv.
FROM python:3.12-slim AS builder

WORKDIR /build

COPY requirements.txt .

RUN python -m venv /venv \
    && /venv/bin/pip install --upgrade pip --no-cache-dir --quiet \
    && /venv/bin/pip install -r requirements.txt --no-cache-dir --quiet \
    && /venv/bin/pip install gunicorn==21.2.0 --no-cache-dir --quiet


# ── Stage 2: runtime ──────────────────────────────────────────────────────────
# Lean production image — no build tools, no pip, no test packages.
FROM python:3.12-slim AS runtime

LABEL description="Student CRUD REST API" \
      version="1.0.0"

# Non-root user for security
RUN addgroup --system appgroup \
    && adduser --system --ingroup appgroup --no-create-home appuser

WORKDIR /app

# Copy only the pre-built venv from the builder stage
COPY --from=builder /venv /venv

# Copy application source and migration files
COPY app/        ./app/
COPY migrations/ ./migrations/
COPY run.py      .
COPY entrypoint.sh .

RUN chmod +x entrypoint.sh \
    && chown -R appuser:appgroup /app

USER appuser

# ── Runtime defaults (all overridable via `docker run -e` or `--env-file`) ───
ENV FLASK_APP=run.py \
    FLASK_ENV=production \
    FLASK_HOST=0.0.0.0 \
    FLASK_PORT=5000 \
    LOG_LEVEL=INFO \
    GUNICORN_WORKERS=2 \
    GUNICORN_THREADS=2

EXPOSE 5000

ENTRYPOINT ["./entrypoint.sh"]

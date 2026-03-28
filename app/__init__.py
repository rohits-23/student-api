import logging
import os

from flask import Flask, jsonify

from .config import config_by_name
from .extensions import db, migrate


def create_app(config_name: str | None = None) -> Flask:
    """Application factory — creates and configures the Flask app."""
    app = Flask(__name__)

    if config_name is None:
        config_name = os.getenv("FLASK_ENV", "development")

    app.config.from_object(config_by_name.get(config_name, config_by_name["development"]))

    # ── Logging ──────────────────────────────────────────────────────────────
    log_level = getattr(logging, app.config.get("LOG_LEVEL", "INFO"), logging.INFO)
    logging.basicConfig(
        level=log_level,
        format="%(asctime)s [%(levelname)s] %(name)s: %(message)s",
        datefmt="%Y-%m-%dT%H:%M:%S",
    )

    # ── Extensions ───────────────────────────────────────────────────────────
    db.init_app(app)
    migrate.init_app(app, db)

    # ── Blueprints ───────────────────────────────────────────────────────────
    from .api.v1 import api_v1_bp  # noqa: F401

    app.register_blueprint(api_v1_bp, url_prefix="/api/v1")

    # ── Error handlers (always return JSON) ──────────────────────────────────
    @app.errorhandler(404)
    def not_found(e):
        return jsonify({"error": "Resource not found"}), 404

    @app.errorhandler(405)
    def method_not_allowed(e):
        return jsonify({"error": "Method not allowed"}), 405

    @app.errorhandler(500)
    def internal_error(e):
        return jsonify({"error": "Internal server error"}), 500

    return app

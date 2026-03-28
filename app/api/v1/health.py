import logging

from flask import jsonify

from . import api_v1_bp

logger = logging.getLogger(__name__)


@api_v1_bp.route("/healthcheck", methods=["GET"])
def healthcheck():
    logger.info("Health check requested")
    return jsonify({"status": "healthy", "message": "Service is running"}), 200

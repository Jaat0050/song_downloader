from flask import Blueprint, jsonify

health_bp = Blueprint("health_route", __name__, url_prefix="/api")

@health_bp.route("/health", methods=["GET"])
def health_check():
    return jsonify({
        "status": "healthy",
        "service": "Song Downloader Backend"
    }), 200

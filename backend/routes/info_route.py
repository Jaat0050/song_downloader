import logging
from flask import Blueprint, request, jsonify
from services.info_service import InfoService
from utils.response import make_error

logger = logging.getLogger(__name__)
info_bp = Blueprint("info_route", __name__, url_prefix="/api/audio")

@info_bp.route("/info", methods=["POST"])
def get_audio_info():
    data = request.get_json(silent=True) or {}
    url = data.get("url", "").strip()

    if not url:
        return make_error("INVALID_URL", "Please provide a valid YouTube URL.", 400)

    if not InfoService.validate_url(url):
        return make_error("UNSUPPORTED_URL", "Only supported YouTube URLs are allowed.", 400)

    try:
        info = InfoService.get_song_info(url)
        return jsonify({
            "success": True,
            "data": info
        }), 200
    except ValueError as e:
        return make_error("INVALID_URL", str(e), 400)
    except Exception as e:
        logger.exception("Error extracting metadata for URL: %s", url)
        return make_error("EXTRACTION_FAILED", "Failed to extract audio metadata for this URL.", 500)

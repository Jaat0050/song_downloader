import logging
from flask import Blueprint, request, jsonify
from services.info_service import InfoService
from services.download_service import download_service
from utils.response import make_error

logger = logging.getLogger(__name__)
download_bp = Blueprint("download_route", __name__, url_prefix="/api/audio")

@download_bp.route("/download", methods=["POST"])
def start_audio_download():
    data = request.get_json(silent=True) or {}
    url = data.get("url", "").strip()

    if not url or not InfoService.validate_url(url):
        return make_error("INVALID_URL", "Please provide a valid YouTube URL.", 400)

    try:
        job_id = download_service.create_job(url)
        return jsonify({
            "success": True,
            "job_id": job_id
        }), 200
    except Exception as e:
        logger.exception("Error initiating download for URL: %s", url)
        return make_error("DOWNLOAD_START_FAILED", "Failed to start audio download job.", 500)

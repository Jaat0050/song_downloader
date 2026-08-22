from flask import Blueprint, jsonify
from services.download_service import download_service
from utils.response import make_error

progress_bp = Blueprint("progress_route", __name__, url_prefix="/api/audio")

@progress_bp.route("/progress/<job_id>", methods=["GET"])
def get_job_progress(job_id):
    job = download_service.get_job(job_id)
    if not job:
        return make_error("JOB_NOT_FOUND", "The requested download job was not found.", 404)

    return jsonify({
        "success": True,
        "data": {
            "job_id": job["job_id"],
            "status": job["status"],
            "progress": job["progress"],
            "speed": job["speed"],
            "eta": job["eta"],
            "filename": job["filename"],
            "error": job["error"]
        }
    }), 200

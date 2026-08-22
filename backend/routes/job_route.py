from flask import Blueprint, jsonify
from services.download_service import download_service
from utils.response import make_error

job_bp = Blueprint("job_route", __name__, url_prefix="/api/audio")

@job_bp.route("/job/<job_id>", methods=["DELETE"])
def delete_job(job_id):
    job = download_service.get_job(job_id)
    if not job:
        return make_error("JOB_NOT_FOUND", "The requested download job was not found.", 404)

    if job["status"] in ["queued", "downloading", "processing"]:
        return make_error("ACTIVE_JOB", "Cannot delete an active download job.", 409)

    success = download_service.delete_job(job_id)
    if not success:
        return make_error("DELETE_FAILED", "Failed to delete download job.", 500)

    return jsonify({
        "success": True
    }), 200

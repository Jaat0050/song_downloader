import os
from flask import Blueprint, send_file
from services.download_service import download_service
from utils.response import make_error

file_bp = Blueprint("file_route", __name__, url_prefix="/api/audio")

@file_bp.route("/file/<job_id>", methods=["GET"])
def get_job_file(job_id):
    job = download_service.get_job(job_id)
    if not job:
        return make_error("JOB_NOT_FOUND", "The requested download job was not found.", 404)

    if job["status"] != "completed":
        return make_error("JOB_NOT_READY", f"Job is currently in '{job['status']}' state.", 400)

    filepath = job.get("filepath")
    if not filepath or not os.path.exists(filepath):
        return make_error("FILE_NOT_FOUND", "Downloaded audio file is missing or removed.", 404)

    return send_file(
        filepath,
        as_attachment=True,
        download_name=job.get("filename") or os.path.basename(filepath)
    )

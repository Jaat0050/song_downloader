import os
import logging
from flask import Flask, request, jsonify, send_file
from flask_cors import CORS

from config import Config
from services.ytdlp_service import YtDlpService, is_valid_url
from services.download_service import DownloadService

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = Flask(__name__)
CORS(app)

download_service = DownloadService(
    download_dir=Config.DOWNLOAD_DIR,
    max_workers=Config.MAX_CONCURRENT_DOWNLOADS
)

def make_error(code: str, message: str, status_code: int = 400):
    return jsonify({
        "success": False,
        "error": {
            "code": code,
            "message": message
        }
    }), status_code

@app.route("/api/audio/info", methods=["POST"])
def get_audio_info():
    data = request.get_json(silent=True) or {}
    url = data.get("url", "").strip()

    if not url:
        return make_error("INVALID_URL", "Please provide a valid YouTube URL.", 400)

    if not is_valid_url(url):
        return make_error("UNSUPPORTED_URL", "Only supported YouTube URLs are allowed.", 400)

    try:
        info = YtDlpService.get_info(url)
        return jsonify({
            "success": True,
            "data": info
        }), 200
    except ValueError as e:
        return make_error("INVALID_URL", str(e), 400)
    except Exception as e:
        logger.exception("Error extracting metadata for URL: %s", url)
        return make_error("EXTRACTION_FAILED", "Failed to extract audio metadata for this URL.", 500)

@app.route("/api/audio/download", methods=["POST"])
def start_audio_download():
    data = request.get_json(silent=True) or {}
    url = data.get("url", "").strip()

    if not url or not is_valid_url(url):
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

@app.route("/api/audio/progress/<job_id>", methods=["GET"])
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

@app.route("/api/audio/file/<job_id>", methods=["GET"])
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

@app.route("/api/audio/job/<job_id>", methods=["DELETE"])
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

if __name__ == "__main__":
    app.run(host=Config.HOST, port=Config.PORT, debug=False)

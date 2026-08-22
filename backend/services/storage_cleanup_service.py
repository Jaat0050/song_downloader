import os
import time
import logging
from typing import Dict, Any
from config import Config

logger = logging.getLogger(__name__)

class StorageCleanupService:
    @staticmethod
    def cleanup_stale_jobs(jobs: Dict[str, Dict[str, Any]], retention_hours: int = Config.DOWNLOAD_RETENTION_HOURS):
        now = time.time()
        retention_seconds = retention_hours * 3600
        to_delete = []
        for job_id, job in list(jobs.items()):
            if job.get("status") in ["completed", "failed"]:
                if now - job.get("updated_at", now) > retention_seconds:
                    to_delete.append(job_id)
        for job_id in to_delete:
            job = jobs.get(job_id)
            if job and job.get("filepath") and os.path.exists(job["filepath"]):
                try:
                    os.remove(job["filepath"])
                except Exception as e:
                    logger.warning("Could not remove file for stale job %s: %s", job_id, e)
            if job_id in jobs:
                del jobs[job_id]

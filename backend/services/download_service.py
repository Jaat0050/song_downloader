import os
import re
import time
import uuid
import logging
from concurrent.futures import ThreadPoolExecutor
from typing import Dict, Any, Optional
from services.ytdlp_service import YtDlpService
from config import Config

logger = logging.getLogger(__name__)

class DownloadService:
    def __init__(self, download_dir: str = Config.DOWNLOAD_DIR, max_workers: int = Config.MAX_CONCURRENT_DOWNLOADS):
        self.download_dir = download_dir
        os.makedirs(self.download_dir, exist_ok=True)
        self.executor = ThreadPoolExecutor(max_workers=max_workers)
        self.jobs: Dict[str, Dict[str, Any]] = {}

    def _cleanup_stale_jobs(self, retention_hours: int = Config.DOWNLOAD_RETENTION_HOURS):
        now = time.time()
        retention_seconds = retention_hours * 3600
        to_delete = []
        for job_id, job in list(self.jobs.items()):
            if job['status'] in ['completed', 'failed']:
                if now - job.get('updated_at', now) > retention_seconds:
                    to_delete.append(job_id)
        for job_id in to_delete:
            self.delete_job(job_id)

    def create_job(self, url: str) -> str:
        self._cleanup_stale_jobs()
        job_id = str(uuid.uuid4())
        job_data = {
            'job_id': job_id,
            'url': url,
            'status': 'queued',
            'progress': 0.0,
            'speed': '0B/s',
            'eta': 0,
            'filename': '',
            'filepath': None,
            'error': None,
            'created_at': time.time(),
            'updated_at': time.time()
        }
        self.jobs[job_id] = job_data
        self.executor.submit(self._execute_download, job_id, url)
        return job_id

    def _progress_hook(self, job_id: str, d: Dict[str, Any]):
        if job_id not in self.jobs:
            return

        job = self.jobs[job_id]
        job['updated_at'] = time.time()
        status = d.get('status')

        if status == 'downloading':
            job['status'] = 'downloading'
            downloaded = d.get('downloaded_bytes', 0)
            total = d.get('total_bytes') or d.get('total_bytes_estimate') or 0
            if total > 0:
                job['progress'] = round((downloaded / total) * 100, 2)

            speed_bytes = d.get('speed')
            if speed_bytes:
                if speed_bytes > 1024 * 1024:
                    job['speed'] = f"{speed_bytes / (1024 * 1024):.1f}MiB/s"
                elif speed_bytes > 1024:
                    job['speed'] = f"{speed_bytes / 1024:.1f}KiB/s"
                else:
                    job['speed'] = f"{speed_bytes}B/s"

            job['eta'] = d.get('eta') or 0
            if d.get('filename'):
                job['filename'] = os.path.basename(d['filename'])
        elif status == 'finished':
            job['status'] = 'processing'
            job['progress'] = 100.0
            if d.get('filename'):
                job['filename'] = os.path.basename(d['filename'])

    def _execute_download(self, job_id: str, url: str):
        job = self.jobs.get(job_id)
        if not job:
            return

        output_template = os.path.join(self.download_dir, f"%(title)s_%(id)s.%(ext)s")

        def hook(d):
            self._progress_hook(job_id, d)

        try:
            job['status'] = 'downloading'
            res = YtDlpService.download(url, output_template, progress_hook=hook)
            job['status'] = 'completed'
            job['progress'] = 100.0
            job['filepath'] = res['filepath']
            job['filename'] = os.path.basename(res['filepath'])
            job['title'] = res.get('title')
            job['artist'] = res.get('artist')
            job['updated_at'] = time.time()
        except Exception as e:
            logger.exception("Download job %s failed", job_id)
            job['status'] = 'failed'
            job['error'] = re.sub(r'\x1b\[[0-9;]*m', '', str(e))
            job['updated_at'] = time.time()

    def get_job(self, job_id: str) -> Optional[Dict[str, Any]]:
        return self.jobs.get(job_id)

    def delete_job(self, job_id: str) -> bool:
        job = self.jobs.get(job_id)
        if not job:
            return False

        if job['status'] in ['queued', 'downloading', 'processing']:
            # Do not allow deletion of active downloads
            return False

        if job.get('filepath') and os.path.exists(job['filepath']):
            try:
                os.remove(job['filepath'])
            except Exception as e:
                logger.warning("Could not remove file for job %s: %s", job_id, e)

        del self.jobs[job_id]
        return True

download_service = DownloadService()


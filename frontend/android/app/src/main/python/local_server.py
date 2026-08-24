import os
import re
import shutil
import sys
import threading
import time
import uuid
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path
from typing import Any, Dict

from flask import Flask, jsonify, request, send_file
from werkzeug.serving import make_server
import yt_dlp

_server = None
_server_thread = None
_server_url = None
_server_files_dir = ''
_server_started_at = None
_jobs: Dict[str, Dict[str, Any]] = {}
_jobs_lock = threading.RLock()
_executor = ThreadPoolExecutor(max_workers=2)
_cleanup_started = False

MIN_FREE_SPACE_BYTES = 100 * 1024 * 1024
STALE_TEMP_SECONDS = 60 * 60
JOB_RETENTION_SECONDS = 6 * 60 * 60
NO_PROGRESS_SECONDS = 120
MAX_ACTIVE_JOBS = 4


def _safe_name(value: str) -> str:
    value = re.sub(r'[\\/:*?"<>|]+', '_', value or 'audio')
    value = re.sub(r'\s+', ' ', value).strip()
    return value[:150] or 'audio'


def _is_youtube_url(url: str) -> bool:
    value = (url or '').strip()
    return bool(
        re.match(r'^https?://(www\.|m\.)?youtube\.com/', value, re.I)
        or re.match(r'^https?://youtu\.be/', value, re.I)
        or re.match(r'^https?://(www\.)?youtube-nocookie\.com/', value, re.I)
    )


def _base_options() -> Dict[str, Any]:
    options: Dict[str, Any] = {
        'quiet': True,
        'no_warnings': False,
        'noplaylist': True,
        'no_color': True,
        'restrictfilenames': True,
        'socket_timeout': 30,
    }
    cookie_path = os.path.join(_server_files_dir, 'youtube_cookies.txt')
    if os.path.isfile(cookie_path):
        options['cookiefile'] = cookie_path
    return options


def _extract_info(url: str) -> Dict[str, Any]:
    options = _base_options()
    options['skip_download'] = True
    options['ignore_no_formats_error'] = True
    with yt_dlp.YoutubeDL(options) as ydl:
        return ydl.extract_info(url, download=False)


def _transcode_to_mp3(source_path: str, output_path: str) -> None:
    from com.example.song_downloder import AudioTranscoder
    if not AudioTranscoder.transcodeToMp3(source_path, output_path):
        raise RuntimeError('FFmpeg failed to convert the downloaded audio to MP3.')
    if not os.path.isfile(output_path) or os.path.getsize(output_path) == 0:
        raise RuntimeError('FFmpeg reported success but the MP3 file was not created.')


def _friendly_error(exc: Exception) -> str:
    message = str(exc).strip()
    lowered = message.lower()
    if 'cancelled by user' in lowered:
        return 'Download cancelled.'
    if isinstance(exc, TimeoutError) or 'timed out' in lowered or 'no progress' in lowered:
        return 'Download timed out because no progress was detected. Please retry.'
    if 'requested format is not available' in lowered:
        return 'No compatible audio format is available for this YouTube video.'
    if 'sign in to confirm' in lowered or 'not a bot' in lowered:
        return 'YouTube temporarily restricted this request. Please try again later.'
    if 'ffmpeg failed' in lowered or 'mp3 file was not created' in lowered:
        return 'Audio conversion to MP3 failed on this device.'
    return message or 'The download failed. Please try again.'


def _set_job(job_id: str, **values: Any) -> None:
    with _jobs_lock:
        job = _jobs.get(job_id)
        if job:
            job.update(values)
            job['updated_at'] = time.time()


def _cleanup_stale_files(download_dir: str) -> int:
    removed = 0
    now = time.time()
    root = Path(download_dir)
    if not root.exists():
        return 0
    for item in root.iterdir():
        if not item.is_file() or item.suffix.lower() not in {'.part', '.webm', '.m4a', '.opus'}:
            continue
        try:
            if now - item.stat().st_mtime > STALE_TEMP_SECONDS:
                item.unlink()
                removed += 1
        except OSError:
            pass
    return removed


def _cleanup_old_jobs(download_dir: str) -> None:
    now = time.time()
    with _jobs_lock:
        candidates = [
            job_id for job_id, job in _jobs.items()
            if job.get('status') in {'completed', 'failed', 'cancelled'}
            and now - job.get('updated_at', now) > JOB_RETENTION_SECONDS
        ]
    for job_id in candidates:
        _delete_job_internal(job_id, download_dir)


def _start_cleanup_thread(download_dir: str) -> None:
    global _cleanup_started
    if _cleanup_started:
        return
    _cleanup_started = True

    def cleanup_loop() -> None:
        while _server is not None:
            try:
                _cleanup_stale_files(download_dir)
                _cleanup_old_jobs(download_dir)
            except Exception:
                pass
            time.sleep(15 * 60)

    threading.Thread(target=cleanup_loop, name='DownloadCleanup', daemon=True).start()


def _download_job(job_id: str, url: str, download_dir: str) -> None:
    last_progress_at = time.monotonic()
    source_path = None
    mp3_path = None

    def progress_hook(data: Dict[str, Any]) -> None:
        nonlocal last_progress_at
        status = data.get('status')
        now = time.monotonic()
        with _jobs_lock:
            job = _jobs.get(job_id)
            if not job:
                raise RuntimeError('Download job was removed.')
            if job.get('cancel_requested'):
                raise RuntimeError('Download cancelled by user.')

        if status == 'downloading':
            if now - last_progress_at > NO_PROGRESS_SECONDS:
                raise TimeoutError('Download made no progress for 2 minutes. Please retry.')
            last_progress_at = now

        if status == 'downloading':
            total = data.get('total_bytes') or data.get('total_bytes_estimate') or 0
            downloaded = data.get('downloaded_bytes') or 0
            progress = (downloaded / total * 100.0) if total else 0.0
            _set_job(
                job_id,
                status='downloading',
                progress=min(progress, 94.0),
                speed=data.get('_speed_str') or '',
                eta=data.get('eta'),
                last_progress_at=time.time(),
            )
        elif status == 'finished':
            _set_job(job_id, status='processing', progress=95.0)

    try:
        _set_job(job_id, status='extracting', started_at=time.time(), last_progress_at=time.time())
        options = _base_options()
        options.update({
            'format': 'bestaudio/best',
            'outtmpl': os.path.join(download_dir, '%(title)s.%(ext)s'),
            'progress_hooks': [progress_hook],
        })

        with yt_dlp.YoutubeDL(options) as ydl:
            info = ydl.extract_info(url, download=True)
            source_path = ydl.prepare_filename(info)

        with _jobs_lock:
            job = _jobs.get(job_id)
            if job and job.get('cancel_requested'):
                raise RuntimeError('Download cancelled by user.')

        if not os.path.isfile(source_path):
            stem = Path(source_path).stem
            candidates = [p for p in Path(download_dir).glob(f'{stem}.*') if p.suffix.lower() != '.part']
            if candidates:
                source_path = str(candidates[0])

        if not source_path or not os.path.isfile(source_path):
            raise RuntimeError('yt-dlp reported success but the source audio file was not found.')

        _set_job(job_id, status='processing', progress=95.0)
        title = _safe_name(str(info.get('title') or Path(source_path).stem))
        mp3_path = os.path.join(download_dir, f'{title}.mp3')
        _transcode_to_mp3(source_path, mp3_path)

        with _jobs_lock:
            job = _jobs.get(job_id)
            if job and job.get('cancel_requested'):
                raise RuntimeError('Download cancelled by user.')

        try:
            if os.path.abspath(source_path) != os.path.abspath(mp3_path):
                os.remove(source_path)
        except OSError:
            pass

        _set_job(
            job_id,
            status='completed',
            progress=100.0,
            filename=os.path.basename(mp3_path),
            filepath=mp3_path,
            format='mp3',
            title=info.get('title'),
            artist=info.get('artist') or info.get('uploader') or info.get('channel'),
            error=None,
            completed_at=time.time(),
            cancel_requested=False,
        )
    except Exception as exc:
        cancelled = 'cancelled by user' in str(exc).lower()
        for path in (source_path, mp3_path):
            if path and os.path.exists(path):
                try:
                    os.remove(path)
                except OSError:
                    pass
        _set_job(
            job_id,
            status='cancelled' if cancelled else 'failed',
            error='Download cancelled.' if cancelled else _friendly_error(exc),
            completed_at=time.time(),
            cancel_requested=False,
        )


def _directory_size(path: str) -> int:
    total = 0
    root = Path(path)
    if not root.exists():
        return 0
    for item in root.rglob('*'):
        try:
            if item.is_file():
                total += item.stat().st_size
        except OSError:
            pass
    return total


def _job_summary() -> Dict[str, int]:
    summary = {
        'total': 0,
        'queued': 0,
        'extracting': 0,
        'downloading': 0,
        'processing': 0,
        'completed': 0,
        'failed': 0,
        'cancelled': 0,
    }
    with _jobs_lock:
        summary['total'] = len(_jobs)
        for job in _jobs.values():
            status = job.get('status')
            if status in summary:
                summary[status] += 1
    return summary


def _delete_job_internal(job_id: str, download_dir: str) -> bool:
    with _jobs_lock:
        job = _jobs.get(job_id)
        if not job:
            return False
        if job.get('status') in {'queued', 'extracting', 'downloading', 'processing'}:
            return False
        filepath = job.get('filepath')
        _jobs.pop(job_id, None)
    if filepath and os.path.isfile(filepath):
        try:
            os.remove(filepath)
        except OSError:
            pass
    _cleanup_stale_files(download_dir)
    return True


def create_app(files_dir: str) -> Flask:
    global _server_files_dir
    _server_files_dir = files_dir
    download_dir = os.path.join(files_dir, 'SongDownloader', 'downloads')
    os.makedirs(download_dir, exist_ok=True)
    _cleanup_stale_files(download_dir)
    _start_cleanup_thread(download_dir)

    app = Flask(__name__)

    @app.get('/api/health')
    def health():
        usage = shutil.disk_usage(files_dir)
        return jsonify({
            'success': True,
            'status': 'ok',
            'server': 'embedded-python',
            'host': '127.0.0.1',
            'port': _server.server_port if _server is not None else None,
            'uptime_seconds': int(time.time() - _server_started_at) if _server_started_at else 0,
            'started_at': _server_started_at,
            'python_version': sys.version.split()[0],
            'yt_dlp': yt_dlp.version.__version__,
            'audio_format': 'mp3',
            'ffmpeg': 'android-native',
            'download_storage_bytes': _directory_size(download_dir),
            'disk_free_bytes': usage.free,
            'disk_total_bytes': usage.total,
            'storage_ready': usage.free >= MIN_FREE_SPACE_BYTES,
            'jobs': _job_summary(),
            'worker_pool': {'max_workers': 2, 'status': 'ready'},
        })

    @app.post('/api/audio/info')
    def audio_info():
        payload = request.get_json(silent=True) or {}
        url = str(payload.get('url') or '').strip()
        if not _is_youtube_url(url):
            return jsonify({'success': False, 'error': {'code': 'INVALID_URL', 'message': 'Please provide a valid YouTube URL.'}}), 400
        try:
            info = _extract_info(url)
            thumbs = info.get('thumbnails') or []
            thumbnail = info.get('thumbnail') or ''
            for item in reversed(thumbs):
                if item.get('url'):
                    thumbnail = item['url']
                    break
            return jsonify({'success': True, 'data': {
                'id': info.get('id', ''),
                'title': info.get('title', 'Unknown Title'),
                'artist': info.get('artist') or info.get('uploader') or info.get('channel') or 'Unknown Artist',
                'uploader': info.get('uploader', ''),
                'duration': info.get('duration', 0),
                'thumbnail': thumbnail,
                'webpage_url': info.get('webpage_url', url),
                'format': 'mp3',
            }})
        except Exception as exc:
            return jsonify({'success': False, 'error': {'code': 'EXTRACTION_FAILED', 'message': _friendly_error(exc)}}), 500

    @app.post('/api/audio/download')
    def audio_download():
        payload = request.get_json(silent=True) or {}
        url = str(payload.get('url') or '').strip()
        if not _is_youtube_url(url):
            return jsonify({'success': False, 'error': {'code': 'INVALID_URL', 'message': 'Please provide a valid YouTube URL.'}}), 400
        usage = shutil.disk_usage(files_dir)
        if usage.free < MIN_FREE_SPACE_BYTES:
            return jsonify({'success': False, 'error': {'code': 'INSUFFICIENT_STORAGE', 'message': 'Not enough free device storage. Please free some space and try again.'}}), 507

        with _jobs_lock:
            active = sum(1 for job in _jobs.values() if job.get('status') in {'queued', 'extracting', 'downloading', 'processing'})
            duplicate = next((job for job in _jobs.values() if job.get('url') == url and job.get('status') in {'queued', 'extracting', 'downloading', 'processing'}), None)
            if duplicate:
                return jsonify({'success': True, 'job_id': duplicate['job_id'], 'duplicate': True, 'format': 'mp3'})
            if active >= MAX_ACTIVE_JOBS:
                return jsonify({'success': False, 'error': {'code': 'TOO_MANY_JOBS', 'message': 'Too many downloads are active. Please wait for one to finish.'}}), 429

            job_id = str(uuid.uuid4())
            _jobs[job_id] = {
                'job_id': job_id,
                'url': url,
                'status': 'queued',
                'progress': 0.0,
                'speed': '',
                'eta': None,
                'filename': None,
                'filepath': None,
                'format': 'mp3',
                'error': None,
                'created_at': time.time(),
                'updated_at': time.time(),
                'started_at': None,
                'last_progress_at': None,
                'completed_at': None,
                'cancel_requested': False,
            }
        _executor.submit(_download_job, job_id, url, download_dir)
        return jsonify({'success': True, 'job_id': job_id, 'duplicate': False, 'format': 'mp3'})

    @app.get('/api/audio/jobs')
    def list_jobs():
        with _jobs_lock:
            jobs = [dict(job) for job in _jobs.values()]
        jobs.sort(key=lambda job: job.get('created_at', 0), reverse=True)
        return jsonify({'success': True, 'data': jobs})

    @app.get('/api/audio/progress/<job_id>')
    def progress(job_id: str):
        with _jobs_lock:
            job = _jobs.get(job_id)
            if not job:
                return jsonify({'success': False, 'error': {'code': 'JOB_NOT_FOUND', 'message': 'Download job not found.'}}), 404
            return jsonify({'success': True, 'data': dict(job)})

    @app.post('/api/audio/cancel/<job_id>')
    def cancel_job(job_id: str):
        with _jobs_lock:
            job = _jobs.get(job_id)
            if not job:
                return jsonify({'success': False, 'error': {'code': 'JOB_NOT_FOUND', 'message': 'Download job not found.'}}), 404
            if job.get('status') in {'completed', 'failed', 'cancelled'}:
                return jsonify({'success': True, 'data': dict(job)})
            job['cancel_requested'] = True
            job['updated_at'] = time.time()
            if job.get('status') == 'queued':
                job['status'] = 'cancelled'
                job['error'] = 'Download cancelled.'
                job['completed_at'] = time.time()
        return jsonify({'success': True, 'data': dict(job)})

    @app.post('/api/audio/retry/<job_id>')
    def retry_job(job_id: str):
        with _jobs_lock:
            job = _jobs.get(job_id)
            if not job:
                return jsonify({'success': False, 'error': {'code': 'JOB_NOT_FOUND', 'message': 'Download job not found.'}}), 404
            if job.get('status') not in {'failed', 'cancelled'}:
                return jsonify({'success': False, 'error': {'code': 'JOB_NOT_RETRYABLE', 'message': 'Only failed or cancelled downloads can be retried.'}}), 409
            url = job['url']
            job.update({
                'status': 'queued', 'progress': 0.0, 'speed': '', 'eta': None,
                'filename': None, 'filepath': None, 'error': None,
                'started_at': None, 'last_progress_at': None,
                'completed_at': None, 'cancel_requested': False,
                'updated_at': time.time(), 'retry_count': job.get('retry_count', 0) + 1,
            })
        _executor.submit(_download_job, job_id, url, download_dir)
        return jsonify({'success': True, 'data': dict(job)})

    @app.get('/api/audio/file/<job_id>')
    def audio_file(job_id: str):
        with _jobs_lock:
            job = _jobs.get(job_id)
            if not job:
                return jsonify({'success': False, 'error': {'code': 'JOB_NOT_FOUND', 'message': 'Download job not found.'}}), 404
            if job.get('status') != 'completed' or not job.get('filepath'):
                return jsonify({'success': False, 'error': {'code': 'FILE_NOT_READY', 'message': 'The audio file is not ready yet.'}}), 409
            filepath = job['filepath']
        if not os.path.isfile(filepath):
            return jsonify({'success': False, 'error': {'code': 'FILE_MISSING', 'message': 'The completed audio file is no longer available.'}}), 404
        return send_file(filepath, as_attachment=True, download_name=os.path.basename(filepath), mimetype='audio/mpeg')

    @app.delete('/api/audio/job/<job_id>')
    def delete_job(job_id: str):
        if _delete_job_internal(job_id, download_dir):
            return jsonify({'success': True})
        with _jobs_lock:
            job = _jobs.get(job_id)
        if not job:
            return jsonify({'success': False, 'error': {'code': 'JOB_NOT_FOUND', 'message': 'Download job not found.'}}), 404
        return jsonify({'success': False, 'error': {'code': 'JOB_ACTIVE', 'message': 'Active downloads cannot be deleted. Cancel the download first.'}}), 409

    return app


def start_server(files_dir: str) -> str:
    global _server, _server_thread, _server_url, _server_started_at, _cleanup_started
    if _server is not None:
        return _server_url
    _cleanup_started = False
    app = create_app(files_dir)
    _server = make_server('127.0.0.1', 0, app, threaded=True)
    _server_url = f'http://127.0.0.1:{_server.server_port}'
    _server_started_at = time.time()
    _server_thread = threading.Thread(target=_server.serve_forever, name='FlaskLocalServer', daemon=True)
    _server_thread.start()
    return _server_url


def stop_server() -> None:
    global _server, _server_thread, _server_url, _server_started_at, _cleanup_started
    if _server is not None:
        try:
            _server.shutdown()
        finally:
            _server = None
            _server_thread = None
            _server_url = None
            _server_started_at = None
            _cleanup_started = False

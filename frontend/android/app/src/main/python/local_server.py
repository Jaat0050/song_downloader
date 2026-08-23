import os
import re
import threading
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
_jobs: Dict[str, Dict[str, Any]] = {}
_jobs_lock = threading.Lock()
_executor = ThreadPoolExecutor(max_workers=2)


def _safe_name(value: str) -> str:
    value = re.sub(r'[\\/:*?"<>|]+', '_', value or 'audio')
    value = re.sub(r'\s+', ' ', value).strip()
    return value[:150] or 'audio'


def _is_youtube_url(url: str) -> bool:
    value = (url or '').strip()
    return bool(re.match(r'^https?://(www\.|m\.)?youtube\.com/', value, re.I) or
                re.match(r'^https?://youtu\.be/', value, re.I) or
                re.match(r'^https?://(www\.)?youtube-nocookie\.com/', value, re.I))


def _base_options() -> Dict[str, Any]:
    options: Dict[str, Any] = {
        'quiet': True,
        'no_warnings': False,
        'noplaylist': True,
        'no_color': True,
        'restrictfilenames': True,
        'socket_timeout': 30,
    }
    # A user may place a Netscape cookies.txt file in the app files directory.
    # Never log its contents.
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


def _download_job(job_id: str, url: str, download_dir: str) -> None:
    def progress_hook(data: Dict[str, Any]) -> None:
        status = data.get('status')
        with _jobs_lock:
            job = _jobs.get(job_id)
            if not job:
                return
            if status == 'downloading':
                total = data.get('total_bytes') or data.get('total_bytes_estimate') or 0
                downloaded = data.get('downloaded_bytes') or 0
                job['progress'] = (downloaded / total * 100.0) if total else 0.0
                job['speed'] = data.get('_speed_str') or ''
                job['eta'] = data.get('eta')
                job['status'] = 'downloading'
            elif status == 'finished':
                job['progress'] = 100.0
                job['status'] = 'processing'

    try:
        options = _base_options()
        options.update({
            # Preserve the best available source audio. No artificial MP3 upscaling.
            'format': 'bestaudio/best',
            'outtmpl': os.path.join(download_dir, '%(title)s.%(ext)s'),
            'progress_hooks': [progress_hook],
        })

        with yt_dlp.YoutubeDL(options) as ydl:
            info = ydl.extract_info(url, download=True)
            source_path = ydl.prepare_filename(info)

        if not os.path.isfile(source_path):
            # Some extractors may normalize the extension after download.
            stem = Path(source_path).stem
            candidates = list(Path(download_dir).glob(f'{stem}.*'))
            if candidates:
                source_path = str(candidates[0])

        if not os.path.isfile(source_path):
            raise RuntimeError('yt-dlp reported success but the audio file was not found.')

        with _jobs_lock:
            job = _jobs.get(job_id)
            if job:
                job.update({
                    'status': 'completed',
                    'progress': 100.0,
                    'filename': os.path.basename(source_path),
                    'filepath': source_path,
                    'error': None,
                })
    except Exception as exc:
        with _jobs_lock:
            job = _jobs.get(job_id)
            if job:
                job.update({
                    'status': 'failed',
                    'error': str(exc),
                })


def create_app(files_dir: str) -> Flask:
    global _server_files_dir
    _server_files_dir = files_dir
    download_dir = os.path.join(files_dir, 'SongDownloader', 'downloads')
    os.makedirs(download_dir, exist_ok=True)

    app = Flask(__name__)

    @app.get('/api/health')
    def health():
        return jsonify({
            'success': True,
            'status': 'ok',
            'server': 'embedded-python',
            'yt_dlp': yt_dlp.version.__version__,
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
            }})
        except Exception as exc:
            return jsonify({'success': False, 'error': {'code': 'EXTRACTION_FAILED', 'message': str(exc)}}), 500

    @app.post('/api/audio/download')
    def audio_download():
        payload = request.get_json(silent=True) or {}
        url = str(payload.get('url') or '').strip()
        if not _is_youtube_url(url):
            return jsonify({'success': False, 'error': {'code': 'INVALID_URL', 'message': 'Please provide a valid YouTube URL.'}}), 400
        job_id = str(uuid.uuid4())
        with _jobs_lock:
            _jobs[job_id] = {
                'job_id': job_id,
                'status': 'queued',
                'progress': 0.0,
                'speed': '',
                'eta': None,
                'filename': None,
                'filepath': None,
                'error': None,
            }
        _executor.submit(_download_job, job_id, url, download_dir)
        return jsonify({'success': True, 'job_id': job_id})

    @app.get('/api/audio/progress/<job_id>')
    def progress(job_id: str):
        with _jobs_lock:
            job = _jobs.get(job_id)
            if not job:
                return jsonify({'success': False, 'error': {'code': 'JOB_NOT_FOUND', 'message': 'Download job not found.'}}), 404
            return jsonify({'success': True, 'data': dict(job)})

    @app.get('/api/audio/file/<job_id>')
    def audio_file(job_id: str):
        with _jobs_lock:
            job = _jobs.get(job_id)
            if not job:
                return jsonify({'success': False, 'error': {'code': 'JOB_NOT_FOUND', 'message': 'Download job not found.'}}), 404
            if job['status'] != 'completed' or not job.get('filepath'):
                return jsonify({'success': False, 'error': {'code': 'FILE_NOT_READY', 'message': 'The audio file is not ready yet.'}}), 409
            filepath = job['filepath']
        return send_file(filepath, as_attachment=True, download_name=os.path.basename(filepath))

    @app.delete('/api/audio/job/<job_id>')
    def delete_job(job_id: str):
        with _jobs_lock:
            job = _jobs.pop(job_id, None)
        if job and job.get('filepath'):
            try:
                os.remove(job['filepath'])
            except OSError:
                pass
        return jsonify({'success': True})

    return app


def start_server(files_dir: str) -> str:
    global _server, _server_thread, _server_url
    if _server is not None:
        return _server_url

    app = create_app(files_dir)
    _server = make_server('127.0.0.1', 0, app, threaded=True)
    port = _server.server_port
    _server_url = f'http://127.0.0.1:{port}'
    _server_thread = threading.Thread(target=_server.serve_forever, name='FlaskLocalServer', daemon=True)
    _server_thread.start()
    return _server_url


def stop_server() -> None:
    global _server, _server_thread, _server_url
    if _server is not None:
        try:
            _server.shutdown()
        finally:
            _server = None
            _server_thread = None
            _server_url = None

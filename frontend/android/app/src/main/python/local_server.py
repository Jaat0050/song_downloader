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
_server_files_dir = ''
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
    """Run the bundled Android FFmpeg through Chaquopy's Java bridge."""
    from com.example.song_downloder import AudioTranscoder

    ok = AudioTranscoder.transcodeToMp3(source_path, output_path)
    if not ok:
        raise RuntimeError('FFmpeg failed to convert the downloaded audio to MP3.')

    if not os.path.isfile(output_path) or os.path.getsize(output_path) == 0:
        raise RuntimeError('FFmpeg reported success but the MP3 file was not created.')


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
                job['progress'] = 95.0
                job['status'] = 'processing'

    source_path = None
    mp3_path = None
    try:
        options = _base_options()
        options.update({
            # Download the best available audio source. FFmpeg below performs
            # the actual conversion to MP3; it does not pretend to improve the
            # source quality beyond what YouTube provides.
            'format': 'bestaudio/best',
            'outtmpl': os.path.join(download_dir, '%(title)s.%(ext)s'),
            'progress_hooks': [progress_hook],
        })

        with yt_dlp.YoutubeDL(options) as ydl:
            info = ydl.extract_info(url, download=True)
            source_path = ydl.prepare_filename(info)

        if not os.path.isfile(source_path):
            stem = Path(source_path).stem
            candidates = list(Path(download_dir).glob(f'{stem}.*'))
            candidates = [p for p in candidates if p.suffix.lower() != '.part']
            if candidates:
                source_path = str(candidates[0])

        if not source_path or not os.path.isfile(source_path):
            raise RuntimeError('yt-dlp reported success but the source audio file was not found.')

        title = _safe_name(str(info.get('title') or Path(source_path).stem))
        mp3_path = os.path.join(download_dir, f'{title}.mp3')

        # Never return the original WebM/Opus file to Flutter. The Android
        # native FFmpeg runtime converts it to a real MP3 file first.
        _transcode_to_mp3(source_path, mp3_path)

        if os.path.abspath(source_path) != os.path.abspath(mp3_path):
            try:
                os.remove(source_path)
            except OSError:
                pass

        with _jobs_lock:
            job = _jobs.get(job_id)
            if job:
                job.update({
                    'status': 'completed',
                    'progress': 100.0,
                    'filename': os.path.basename(mp3_path),
                    'filepath': mp3_path,
                    'format': 'mp3',
                    'error': None,
                })
    except Exception as exc:
        if mp3_path and os.path.exists(mp3_path):
            try:
                os.remove(mp3_path)
            except OSError:
                pass
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
            'audio_format': 'mp3',
            'ffmpeg': 'android-native',
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
                'format': 'mp3',
                'error': None,
            }
        _executor.submit(_download_job, job_id, url, download_dir)
        return jsonify({'success': True, 'job_id': job_id, 'format': 'mp3'})

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
        return send_file(filepath, as_attachment=True, download_name=os.path.basename(filepath), mimetype='audio/mpeg')

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

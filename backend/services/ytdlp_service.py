import re
import logging
from typing import Dict, Any, Optional
import yt_dlp

logger = logging.getLogger(__name__)

SUPPORTED_DOMAINS = [
    r'^(https?://)?(www\.|m\.)?youtube\.com/',
    r'^(https?://)?youtu\.be/',
    r'^(https?://)?(www\.)?youtube-nocookie\.com/'
]

def is_valid_url(url: str) -> bool:
    if not url or not isinstance(url, str):
        return False
    url_stripped = url.strip()
    return any(re.search(pattern, url_stripped, re.IGNORECASE) for pattern in SUPPORTED_DOMAINS)

class YtDlpService:
    @staticmethod
    def get_info(url: str) -> Dict[str, Any]:
        if not is_valid_url(url):
            raise ValueError("Invalid or unsupported media URL.")

        ydl_opts = {
            'quiet': True,
            'no_warnings': True,
            'extract_flat': False,
            'skip_download': True,
            'format': 'bestaudio/best',
        }

        with yt_dlp.YoutubeDL(ydl_opts) as ydl:
            info = ydl.extract_info(url, download=False)
            if not info:
                raise RuntimeError("Could not extract metadata for the requested URL.")

            # Process audio formats
            raw_formats = info.get('formats', [])
            audio_formats = []
            for f in raw_formats:
                vcodec = f.get('vcodec')
                acodec = f.get('acodec')
                if acodec and acodec != 'none' and (not vcodec or vcodec == 'none'):
                    audio_formats.append({
                        'format_id': f.get('format_id'),
                        'ext': f.get('ext'),
                        'codec': acodec,
                        'bitrate': f.get('abr') or f.get('tbr'),
                        'sample_rate': f.get('asr'),
                        'size': f.get('filesize') or f.get('filesize_approx')
                    })

            thumbnail = info.get('thumbnail') or ''
            thumbnails = info.get('thumbnails')
            if thumbnails and isinstance(thumbnails, list) and len(thumbnails) > 0:
                thumbnail = thumbnails[-1].get('url') or thumbnail

            return {
                'id': info.get('id', ''),
                'title': info.get('title', 'Unknown Title'),
                'artist': info.get('artist') or info.get('uploader') or info.get('channel') or 'Unknown Artist',
                'uploader': info.get('uploader', ''),
                'duration': info.get('duration', 0),
                'thumbnail': thumbnail,
                'webpage_url': info.get('webpage_url', url),
                'audio_formats': audio_formats
            }

    @staticmethod
    def download(url: str, output_template: str, progress_hook: Optional[Any] = None) -> Dict[str, Any]:
        if not is_valid_url(url):
            raise ValueError("Invalid or unsupported media URL.")

        hooks = [progress_hook] if progress_hook else []

        ydl_opts = {
            'format': 'bestaudio/best',
            'outtmpl': output_template,
            'quiet': True,
            'no_warnings': True,
            'noplaylist': True,
            'restrictfilenames': True,
            'progress_hooks': hooks,
        }

        with yt_dlp.YoutubeDL(ydl_opts) as ydl:
            info = ydl.extract_info(url, download=True)
            filename = ydl.prepare_filename(info)
            return {
                'id': info.get('id', ''),
                'title': info.get('title', ''),
                'artist': info.get('artist') or info.get('uploader') or 'Unknown Artist',
                'filepath': filename
            }

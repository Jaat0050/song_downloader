import os
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
            'noplaylist': True,
            'no_color': True,
            'format': 'bestaudio/best',
            'extractor_args': {
                'youtube': {
                    'player_client': ['mweb', 'ios', 'android', 'web'],
                }
            },
        }

        with yt_dlp.YoutubeDL(ydl_opts) as ydl:
            info = ydl.extract_info(url, download=False)
            if not info:
                raise RuntimeError("Could not extract metadata for the requested URL.")

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
            }

    @staticmethod
    def download(url: str, output_template: str, progress_hook: Optional[Any] = None) -> Dict[str, Any]:
        if not is_valid_url(url):
            raise ValueError("Invalid or unsupported media URL.")

        hooks = [progress_hook] if progress_hook else []

        ydl_opts = {
            'format': 'bestaudio/best',
            'outtmpl': output_template,
            'postprocessors': [{
                'key': 'FFmpegExtractAudio',
                'preferredcodec': 'mp3',
                'preferredquality': '320',
            }],
            'quiet': True,
            'no_warnings': True,
            'noplaylist': True,
            'no_color': True,
            'restrictfilenames': True,
            'progress_hooks': hooks,
            'extractor_args': {
                'youtube': {
                    'player_client': ['mweb', 'ios', 'android', 'web'],
                }
            },
        }

        ffmpeg_bin = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "bin"))
        if os.path.exists(os.path.join(ffmpeg_bin, "ffmpeg")):
            ydl_opts['ffmpeg_location'] = ffmpeg_bin

        with yt_dlp.YoutubeDL(ydl_opts) as ydl:
            info = ydl.extract_info(url, download=True)
            filename = ydl.prepare_filename(info)
            base, _ = os.path.splitext(filename)
            mp3_filepath = f"{base}.mp3"
            final_filepath = mp3_filepath if os.path.exists(mp3_filepath) else filename
            return {
                'id': info.get('id', ''),
                'title': info.get('title', ''),
                'artist': info.get('artist') or info.get('uploader') or 'Unknown Artist',
                'filepath': final_filepath
            }

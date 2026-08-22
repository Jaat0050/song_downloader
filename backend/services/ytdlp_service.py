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

def clean_url(url: str) -> str:
    if not url or not isinstance(url, str):
        return ""
    url_stripped = url.strip()
    if not url_stripped.startswith("http://") and not url_stripped.startswith("https://"):
        url_stripped = "https://" + url_stripped
    return url_stripped

def is_valid_url(url: str) -> bool:
    cleaned = clean_url(url)
    return bool(cleaned) and any(re.search(pattern, cleaned, re.IGNORECASE) for pattern in SUPPORTED_DOMAINS)

DEFAULT_USER_AGENT = 'Mozilla/5.0 (iPhone; CPU iPhone OS 17_3 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.2 Mobile/15E148 Safari/604.1'

def _get_cookie_file() -> Optional[str]:
    local_cookies = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "cookies.txt"))
    if os.path.exists(local_cookies):
        return local_cookies

    env_cookies = os.getenv("YOUTUBE_COOKIES")
    if env_cookies and env_cookies.strip():
        tmp_path = "/tmp/youtube_cookies.txt"
        try:
            with open(tmp_path, "w", encoding="utf-8") as f:
                f.write(env_cookies.strip() + "\n")
            return tmp_path
        except Exception as e:
            logger.warning("Failed to write env YOUTUBE_COOKIES to tmp file: %s", e)

    return None

class YtDlpService:
    @staticmethod
    def get_info(url: str) -> Dict[str, Any]:
        url = clean_url(url)
        if not is_valid_url(url):
            raise ValueError("Invalid or unsupported media URL.")

        ydl_opts = {
            'quiet': True,
            'no_warnings': True,
            'extract_flat': False,
            'skip_download': True,
            'noplaylist': True,
            'no_color': True,
            'user_agent': DEFAULT_USER_AGENT,
            'extractor_args': {
                'youtube': {
                    'player_client': ['ios', 'android'],
                }
            },
        }

        cookie_file = _get_cookie_file()
        if cookie_file:
            ydl_opts['cookiefile'] = cookie_file

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
        url = clean_url(url)
        if not is_valid_url(url):
            raise ValueError("Invalid or unsupported media URL.")

        hooks = [progress_hook] if progress_hook else []

        ydl_opts = {
            'format': 'ba/b/best',
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
            'user_agent': DEFAULT_USER_AGENT,
            'extractor_args': {
                'youtube': {
                    'player_client': ['ios', 'android'],
                }
            },
        }

        cookie_file = _get_cookie_file()
        if cookie_file:
            ydl_opts['cookiefile'] = cookie_file

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

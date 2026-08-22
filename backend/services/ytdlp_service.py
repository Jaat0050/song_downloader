import logging
import os
import re
from typing import Any, Dict, Optional

import yt_dlp

from config import Config

logger = logging.getLogger(__name__)

SUPPORTED_DOMAINS = [
    r'^(https?://)?(www\.|m\.)?youtube\.com/',
    r'^(https?://)?youtu\.be/',
    r'^(https?://)?(www\.)?youtube-nocookie\.com/',
]

DEFAULT_USER_AGENT = (
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) '
    'AppleWebKit/537.36 (KHTML, like Gecko) '
    'Chrome/136.0.0.0 Safari/537.36'
)


def clean_url(url: str) -> str:
    if not url or not isinstance(url, str):
        return ''
    url_stripped = url.strip()
    if not url_stripped.startswith(('http://', 'https://')):
        url_stripped = 'https://' + url_stripped
    return url_stripped


def is_valid_url(url: str) -> bool:
    cleaned = clean_url(url)
    return bool(cleaned) and any(
        re.search(pattern, cleaned, re.IGNORECASE) for pattern in SUPPORTED_DOMAINS
    )


def _get_cookie_file() -> Optional[str]:
    local_cookies = os.path.abspath(
        os.path.join(os.path.dirname(__file__), '..', 'cookies.txt')
    )
    if os.path.exists(local_cookies):
        return local_cookies

    env_cookies = os.getenv('YOUTUBE_COOKIES')
    if env_cookies and env_cookies.strip():
        tmp_path = '/tmp/youtube_cookies.txt'
        try:
            with open(tmp_path, 'w', encoding='utf-8') as f:
                f.write(env_cookies.strip() + '\n')
            return tmp_path
        except Exception as e:
            logger.warning('Failed to write YOUTUBE_COOKIES to temporary file: %s', e)

    return None


def _get_yt_dlp_options(*, download: bool, output_template: Optional[str] = None,
                        progress_hook: Optional[Any] = None) -> Dict[str, Any]:
    """Build one consistent yt-dlp configuration for both metadata and downloads.

    The old implementation forced iOS/Android YouTube clients. That can result in
    an incomplete format list on current YouTube. We deliberately let the current
    yt-dlp extractor choose its supported/default clients instead.
    """
    options: Dict[str, Any] = {
        'quiet': not Config.YTDLP_VERBOSE,
        'no_warnings': not Config.YTDLP_VERBOSE,
        'verbose': Config.YTDLP_VERBOSE,
        'noplaylist': True,
        'no_color': True,
        'user_agent': DEFAULT_USER_AGENT,
        # Keep metadata extraction useful even when a particular client temporarily
        # exposes no downloadable formats. The download endpoint still requires a
        # real format and will report a clear failure if none is available.
        'ignore_no_formats_error': not download,
    }

    if download:
        options.update({
            'format': 'bestaudio/best',
            'outtmpl': output_template,
            'restrictfilenames': True,
            'progress_hooks': [progress_hook] if progress_hook else [],
            'postprocessors': [{
                'key': 'FFmpegExtractAudio',
                'preferredcodec': 'mp3',
                'preferredquality': '320',
            }],
        })

        ffmpeg_bin = os.path.abspath(
            os.path.join(os.path.dirname(__file__), '..', 'bin')
        )
        ffmpeg_path = os.path.join(ffmpeg_bin, 'ffmpeg')
        if os.path.isfile(ffmpeg_path) and os.access(ffmpeg_path, os.X_OK):
            options['ffmpeg_location'] = ffmpeg_bin

    # Current yt-dlp requires a supported JS runtime for full YouTube extraction.
    # Explicitly point yt-dlp at our Render-installed Deno binary so this does not
    # depend on Render's PATH.
    deno_path = Config.DENO_PATH
    if deno_path and os.path.isfile(deno_path) and os.access(deno_path, os.X_OK):
        options['js_runtimes'] = {
            'deno': {'path': deno_path},
        }
    else:
        logger.warning('Deno runtime not found at %s', deno_path or '<unset>')

    cookie_file = _get_cookie_file()
    if cookie_file:
        options['cookiefile'] = cookie_file

    return options


class YtDlpService:
    @staticmethod
    def get_info(url: str) -> Dict[str, Any]:
        url = clean_url(url)
        if not is_valid_url(url):
            raise ValueError('Invalid or unsupported media URL.')

        ydl_opts = _get_yt_dlp_options(download=False)
        logger.info(
            'Extracting YouTube metadata with yt-dlp=%s, deno=%s, url=%s',
            yt_dlp.version.__version__,
            Config.DENO_PATH or 'not configured',
            url,
        )

        with yt_dlp.YoutubeDL(ydl_opts) as ydl:
            info = ydl.extract_info(url, download=False)
            if not info:
                raise RuntimeError('Could not extract metadata for the requested URL.')

            thumbnail = info.get('thumbnail') or ''
            thumbnails = info.get('thumbnails')
            if isinstance(thumbnails, list) and thumbnails:
                # Prefer the last/highest-quality thumbnail exposed by yt-dlp.
                for item in reversed(thumbnails):
                    if item.get('url'):
                        thumbnail = item['url']
                        break

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
    def download(
        url: str,
        output_template: str,
        progress_hook: Optional[Any] = None,
    ) -> Dict[str, Any]:
        url = clean_url(url)
        if not is_valid_url(url):
            raise ValueError('Invalid or unsupported media URL.')

        ydl_opts = _get_yt_dlp_options(
            download=True,
            output_template=output_template,
            progress_hook=progress_hook,
        )

        logger.info(
            'Starting YouTube audio download with yt-dlp=%s, deno=%s, url=%s',
            yt_dlp.version.__version__,
            Config.DENO_PATH or 'not configured',
            url,
        )

        with yt_dlp.YoutubeDL(ydl_opts) as ydl:
            info = ydl.extract_info(url, download=True)
            filename = ydl.prepare_filename(info)
            base, _ = os.path.splitext(filename)
            mp3_filepath = f'{base}.mp3'
            final_filepath = mp3_filepath if os.path.exists(mp3_filepath) else filename

            return {
                'id': info.get('id', ''),
                'title': info.get('title', ''),
                'artist': info.get('artist') or info.get('uploader') or 'Unknown Artist',
                'filepath': final_filepath,
            }

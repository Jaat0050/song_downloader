import base64
import logging
import os
import re
from typing import Any, Dict, Optional, Tuple

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


def _validate_netscape_cookie_content(content: str) -> Tuple[bool, int, str]:
    """Validate a cookies.txt value without ever logging cookie values."""
    if not content or not content.strip():
        return False, 0, 'empty'

    lines = [line.strip() for line in content.splitlines() if line.strip()]
    cookie_lines = [
        line for line in lines
        if not line.startswith('#') and len(line.split('\t')) >= 7
    ]

    if not cookie_lines:
        return False, 0, 'not_netscape_format'

    youtube_lines = [
        line for line in cookie_lines
        if '.youtube.com' in line.lower() or 'youtube.com' in line.lower()
    ]
    return True, len(youtube_lines), 'ok'


def _write_cookie_file(content: str, path: str) -> Optional[str]:
    try:
        with open(path, 'w', encoding='utf-8', newline='\n') as f:
            f.write(content.rstrip('\n') + '\n')
        return path
    except Exception as e:
        logger.warning('Failed to write YouTube cookies: %s', e)
        return None


def _get_cookie_file() -> Optional[str]:
    # Local file is useful for local development. Never commit this file.
    local_cookies = os.path.abspath(
        os.path.join(os.path.dirname(__file__), '..', 'cookies.txt')
    )
    if os.path.exists(local_cookies):
        try:
            with open(local_cookies, 'r', encoding='utf-8') as f:
                content = f.read()
            valid, youtube_count, reason = _validate_netscape_cookie_content(content)
            if valid:
                logger.info(
                    'YouTube cookies loaded from local cookies.txt (%d YouTube cookie entries).',
                    youtube_count,
                )
                return local_cookies
            logger.warning('Local cookies.txt is not valid Netscape cookies (%s).', reason)
        except Exception as e:
            logger.warning('Could not read local cookies.txt: %s', e)

    # Preferred Render configuration: store the Netscape cookies.txt content in
    # YOUTUBE_COOKIES. Do not log this value or expose it through an API.
    env_cookies = os.getenv('YOUTUBE_COOKIES', '')
    if env_cookies.strip():
        valid, youtube_count, reason = _validate_netscape_cookie_content(env_cookies)
        if not valid:
            logger.error(
                'YOUTUBE_COOKIES is present but is not a valid Netscape cookies.txt '
                'value (%s). Export cookies in Netscape format.',
                reason,
            )
        else:
            tmp_path = '/tmp/youtube_cookies.txt'
            path = _write_cookie_file(env_cookies, tmp_path)
            if path:
                logger.info(
                    'YouTube cookies loaded from YOUTUBE_COOKIES (%d YouTube cookie entries).',
                    youtube_count,
                )
                return path

    # Optional safer transport for environments where multiline environment
    # variables are inconvenient. The secret itself must be base64 of the same
    # Netscape cookies.txt file.
    env_b64 = os.getenv('YOUTUBE_COOKIES_BASE64', '')
    if env_b64.strip():
        try:
            decoded = base64.b64decode(env_b64, validate=True).decode('utf-8')
            valid, youtube_count, reason = _validate_netscape_cookie_content(decoded)
            if not valid:
                logger.error(
                    'YOUTUBE_COOKIES_BASE64 is present but invalid (%s).', reason
                )
            else:
                tmp_path = '/tmp/youtube_cookies.txt'
                path = _write_cookie_file(decoded, tmp_path)
                if path:
                    logger.info(
                        'YouTube cookies loaded from YOUTUBE_COOKIES_BASE64 '
                        '(%d YouTube cookie entries).',
                        youtube_count,
                    )
                    return path
        except Exception as e:
            logger.error('Could not decode YOUTUBE_COOKIES_BASE64: %s', e)

    logger.info('No valid YouTube cookies configured.')
    return None


def _get_yt_dlp_options(*, download: bool, output_template: Optional[str] = None,
                        progress_hook: Optional[Any] = None) -> Dict[str, Any]:
    """Build one consistent yt-dlp configuration for metadata and downloads."""
    options: Dict[str, Any] = {
        'quiet': not Config.YTDLP_VERBOSE,
        'no_warnings': not Config.YTDLP_VERBOSE,
        'verbose': Config.YTDLP_VERBOSE,
        'noplaylist': True,
        'no_color': True,
        'user_agent': DEFAULT_USER_AGENT,
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
        logger.info(
            'yt-dlp %s cookies authentication enabled for %s.',
            'download' if download else 'metadata',
            'YouTube',
        )

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

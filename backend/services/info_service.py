import logging
from typing import Dict, Any
from services.ytdlp_service import YtDlpService, is_valid_url

logger = logging.getLogger(__name__)

class InfoService:
    @staticmethod
    def validate_url(url: str) -> bool:
        return is_valid_url(url)

    @staticmethod
    def get_song_info(url: str) -> Dict[str, Any]:
        return YtDlpService.get_info(url)

import os


class Config:
    DOWNLOAD_DIR = os.getenv(
        "DOWNLOAD_DIR",
        os.path.abspath(os.path.join(os.path.dirname(__file__), "downloads")),
    )
    MAX_CONCURRENT_DOWNLOADS = int(os.getenv("MAX_CONCURRENT_DOWNLOADS", "2"))
    PORT = int(os.getenv("PORT", "5000"))
    DOWNLOAD_RETENTION_HOURS = int(os.getenv("DOWNLOAD_RETENTION_HOURS", "24"))
    HOST = os.getenv("HOST", "0.0.0.0")

    # Render build.sh installs Deno here. Keep this configurable for local runs.
    DENO_PATH = os.getenv("DENO_PATH", os.path.abspath(os.path.join(os.path.dirname(__file__), "bin", "deno")))

    # Set YTDLP_VERBOSE=true temporarily when diagnosing extractor issues.
    YTDLP_VERBOSE = os.getenv("YTDLP_VERBOSE", "false").lower() in {
        "1", "true", "yes", "on"
    }

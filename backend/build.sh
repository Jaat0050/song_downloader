#!/usr/bin/env bash
set -o errexit

pip install --upgrade pip
pip install -r requirements.txt

# Install static FFmpeg binary for Render cloud host
FFMPEG_DIR="$PWD/bin"
mkdir -p "$FFMPEG_DIR"

if [ ! -f "$FFMPEG_DIR/ffmpeg" ]; then
  echo "Downloading static FFmpeg binary..."
  curl -sL "https://github.com/eugeneware/ffmpeg-static/releases/download/b6.0/ffmpeg-linux-x64" -o "$FFMPEG_DIR/ffmpeg"
  chmod +x "$FFMPEG_DIR/ffmpeg"
fi

#!/usr/bin/env bash
set -o errexit
set -o pipefail

pip install --upgrade pip
pip install -r requirements.txt

# Render does not provide the JavaScript runtime required by current yt-dlp
# YouTube extraction, so install a local Deno binary inside the backend build.
BIN_DIR="$PWD/bin"
mkdir -p "$BIN_DIR"

# Install static FFmpeg binary for Render cloud host.
if [ ! -f "$BIN_DIR/ffmpeg" ]; then
  echo "Downloading static FFmpeg binary..."
  curl -fsSL "https://github.com/eugeneware/ffmpeg-static/releases/download/b6.0/ffmpeg-linux-x64" -o "$BIN_DIR/ffmpeg"
  chmod +x "$BIN_DIR/ffmpeg"
fi

# Install Deno locally so yt-dlp can use it explicitly through --js-runtimes.
if [ ! -x "$BIN_DIR/deno" ]; then
  echo "Installing Deno JavaScript runtime..."
  DENO_HOME="$PWD/.deno"
  rm -rf "$DENO_HOME"
  mkdir -p "$DENO_HOME"
  curl -fsSL https://deno.land/install.sh | env DENO_INSTALL="$DENO_HOME" sh
  cp "$DENO_HOME/bin/deno" "$BIN_DIR/deno"
  chmod +x "$BIN_DIR/deno"
  rm -rf "$DENO_HOME"
fi

echo "Runtime versions:"
python --version
python -c "import yt_dlp; print('yt-dlp', yt_dlp.version.__version__)"
"$BIN_DIR/ffmpeg" -version | head -n 1
"$BIN_DIR/deno" --version | head -n 1

# Fail the build early if a required runtime is missing.
test -x "$BIN_DIR/ffmpeg"
test -x "$BIN_DIR/deno"

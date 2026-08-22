# Song Downloader

Personal high-quality audio downloader featuring a modern Flutter mobile client and a Python Flask backend architecture.

---

## Architecture Overview

```text
Flutter Android App
        │
        │ HTTPS / HTTP REST API
        ▼
Python Flask Backend
        │
        ├── yt-dlp (Python API)
        ├── Deno (JavaScript Runtime for yt-dlp extraction)
        └── FFmpeg (Audio processing/conversion)
        │
        ▼
Audio Stream Download & Processing
        │
        ▼
Flutter Client Downloads Resulting Audio File
```

The Flutter mobile application communicates strictly via REST API with the Flask backend server. All extraction, processing, and media downloading occur on the backend server.

---

## REST API Specification

### 1. `POST /api/audio/info`
Extracts song metadata without downloading the media stream.

**Request Body:**
```json
{
  "url": "https://www.youtube.com/watch?v=EXAMPLE"
}
```

**Response:**
```json
{
  "success": true,
  "data": {
    "id": "EXAMPLE",
    "title": "Song Title",
    "artist": "Artist Name",
    "uploader": "Channel Name",
    "duration": 210,
    "thumbnail": "https://...",
    "webpage_url": "https://www.youtube.com/watch?v=EXAMPLE",
    "audio_formats": [...]
  }
}
```

---

### 2. `POST /api/audio/download`
Creates a background audio download job and returns immediately with a `job_id`.

**Request Body:**
```json
{
  "url": "https://www.youtube.com/watch?v=EXAMPLE"
}
```

**Response:**
```json
{
  "success": true,
  "job_id": "c9a4b2f1-..."
}
```

---

### 3. `GET /api/audio/progress/<job_id>`
Returns real-time job progress and download status.

**Response:**
```json
{
  "success": true,
  "data": {
    "job_id": "c9a4b2f1-...",
    "status": "downloading",
    "progress": 64.5,
    "speed": "2.4MiB/s",
    "eta": 12,
    "filename": "Song_Title.m4a",
    "error": null
  }
}
```

Possible `status` values: `queued`, `downloading`, `processing`, `completed`, `failed`.

---

### 4. `GET /api/audio/file/<job_id>`
Downloads the resulting audio file once the job reaches `completed` status.

---

### 5. `DELETE /api/audio/job/<job_id>`
Deletes a finished or failed download job and cleans up temporary backend files.

---

## Backend Setup & Requirements

### Prerequisites
- Python 3.11 or 3.12
- [FFmpeg](https://ffmpeg.org/) installed and available in system PATH
- [Deno](https://deno.land/) installed and available in system PATH (required JS runtime for current `yt-dlp` YouTube extraction)

### 1. Install FFmpeg & Deno
- **macOS (Homebrew):**
  ```bash
  brew install ffmpeg deno
  ```
- **Linux (Debian/Ubuntu):**
  ```bash
  sudo apt update && sudo apt install ffmpeg
  curl -fsSL https://deno.land/install.sh | sh
  ```
- **Verify installation:**
  ```bash
  ffmpeg -version
  deno --version
  ```

---

### 2. Run Flask Server Locally
```bash
cd backend

# Create & activate virtual environment
python3 -m venv .venv
source .venv/bin/activate

# Install dependencies
pip install -r requirements.txt

# Start local server
python app.py
```

For production or multi-threaded background processing:
```bash
gunicorn -w 2 -b 0.0.0.0:5000 app:app
```

---

## Mobile Application Setup (Flutter)

### 1. Android Emulator Configuration
By default, the Flutter app points to `http://10.0.2.2:5000`, which routes to localhost on the host computer from the Android emulator.

### 2. Physical Android Device Configuration
For a physical phone connected over Wi-Fi:
1. Open the **Song Downloader** app on your device.
2. Go to the **Settings** tab.
3. Update the **Backend Base URL** to your development computer's LAN IP (e.g. `http://192.168.1.50:5000`).

---

## Testing

### Backend Unit Tests
```bash
cd backend
.venv/bin/python3 -m unittest discover -s tests
```

### Flutter Tests & Analysis
```bash
flutter analyze
flutter test
```

---

## Maintenance & Updating yt-dlp

YouTube extractors evolve continuously. To keep `yt-dlp` up to date on your backend:
```bash
source backend/.venv/bin/activate
pip install -U yt-dlp
```

---

## License & Usage

This project is for authorized personal use only. Users are responsible for ensuring compliance with applicable terms of service and laws.

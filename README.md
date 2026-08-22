# 🎵 Song Downloader

A full-stack, high-performance audio downloader application featuring a **Flutter** mobile application frontend and a **Python Flask** backend powered by `yt-dlp` and `FFmpeg`.

---

## ✨ Features

- 🎧 **320 kbps High-Quality MP3 Downloads**: Automatically extracts and converts YouTube audio into `.mp3` format.
- 📱 **Public Device Storage**: Downloads save directly to your phone's public folder at `/storage/emulated/0/Download/Song Downloader/` for easy access in any music player.
- 🚀 **Fast Metadata Extraction**: Fast parsing for YouTube links, including Mix and Radio URLs (`&start_radio=1`).
- 🤖 **Bot Check Bypass**: Built-in mobile client fallback arguments (`mweb`, `ios`, `android`) to bypass YouTube bot detection.
- 📊 **Real-time Download Tracking**: Monitor download speed, ETA, and progress percentages in real time.
- 🎶 **In-App Music Player**: Built-in player to listen, pause, seek, share, or delete downloaded songs inside the app.
- ☁️ **Cloud Deployment Ready**: Pre-configured with `render.yaml` for 1-click backend deployment to **Render.com**.

---

## 📁 Repository Structure

```text
song_downloader/
├── backend/                         # Python Flask Backend API
│   ├── app.py                       # Main Flask app initialization & entrypoint
│   ├── build.sh                     # Render build script (installs static FFmpeg)
│   ├── render.yaml                  # Backend Render blueprint configuration
│   ├── requirements.txt             # Python dependencies (Flask, yt-dlp, gunicorn)
│   ├── routes/                      # API Route Controllers (1 endpoint per file)
│   │   ├── info_route.py            # POST /api/audio/info
│   │   ├── download_route.py        # POST /api/audio/download
│   │   ├── progress_route.py        # GET  /api/audio/progress/<job_id>
│   │   ├── file_route.py            # GET  /api/audio/file/<job_id>
│   │   ├── job_route.py             # DELETE /api/audio/job/<job_id>
│   │   └── health_route.py          # GET  /api/health
│   ├── services/                    # Business Logic Services
│   │   ├── info_service.py          # Metadata extraction service
│   │   ├── download_service.py      # Background thread-pool job queue manager
│   │   ├── storage_cleanup_service.py # Automated stale download cleanup
│   │   └── ytdlp_service.py         # Low-level yt-dlp & FFmpeg processing
│   ├── utils/                       # Response helpers
│   └── tests/                       # Unit test suite
│
├── frontend/                        # Flutter Mobile App
│   ├── lib/                         # App UI screens, state, models & services
│   ├── android/                     # Android project configuration & storage permissions
│   ├── web/                         # Web build configuration
│   └── pubspec.yaml                 # Flutter dependencies
│
├── render.yaml                      # Root Render Monorepo Blueprint
└── README.md                        # Documentation
```

---

## 🚀 Quick Start

### 1. Running the Backend Locally

```bash
# Navigate to the backend directory
cd backend

# Create and activate a Python virtual environment
python3 -m venv .venv
source .venv/bin/activate

# Install dependencies
pip install -r requirements.txt

# Run the backend server
python app.py
```

The backend will start serving at `http://127.0.0.1:5000` (and on your local network IP `http://192.168.x.x:5000`).

#### Run Backend Unit Tests

```bash
source backend/.venv/bin/activate
python -m unittest discover -s backend/tests
```

---

### 2. Running the Flutter App

```bash
# Navigate to the frontend directory
cd frontend

# Install Flutter packages
flutter pub get

# Run on a connected Android device or emulator
flutter run
```

---

## 🌐 API Reference

| Method | Endpoint | Description |
| :--- | :--- | :--- |
| `GET` | `/api/health` | Server health check status |
| `POST` | `/api/audio/info` | Fetch YouTube video metadata (title, thumbnail, duration, artist) |
| `POST` | `/api/audio/download` | Queue a background download job |
| `GET` | `/api/audio/progress/<job_id>` | Stream job progress (`status`, `progress%`, `speed`, `eta`) |
| `GET` | `/api/audio/file/<job_id>` | Stream completed 320kbps MP3 audio file |
| `DELETE` | `/api/audio/job/<job_id>` | Delete temporary server files after download |

---

## ☁️ Cloud Deployment (Render.com)

1. Push your repository to **GitHub**.
2. Log in to **[Render.com](https://dashboard.render.com)**.
3. Click **New +** $\rightarrow$ **Web Service** and connect your GitHub repository.
4. Render will auto-detect `render.yaml` with:
   - **Root Directory**: `backend`
   - **Build Command**: `./build.sh`
   - **Start Command**: `gunicorn app:app --bind 0.0.0.0:$PORT --workers 2 --threads 4 --timeout 120`
5. Click **Create Web Service**.
6. Copy your live backend URL (e.g. `https://song-downloader-backend.onrender.com`) and paste it into the **Settings** tab of the Song Downloader mobile app!

---

## 🛠️ Technology Stack

- **Mobile App**: Flutter (Dart), Just Audio, Path Provider, Dio, Shared Preferences.
- **Backend API**: Python 3.11, Flask, Flask-CORS, Gunicorn WSGI.
- **Audio Extraction**: `yt-dlp` & `FFmpeg`.

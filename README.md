# 🎵 Song Downloader

A personal-use Android audio downloader built with **Flutter**, an **embedded Python 3.11 + Flask server**, `yt-dlp`, and Android-native FFmpeg.

The backend runs locally inside each Android app installation. No Render server, VPS, or external backend is required.

## ✨ Features

- 🎧 **MP3 Downloads**: Downloads the best available audio source and converts it to MP3 at 320 kbps.
- 📱 **Per-device local server**: Every app installation starts its own Flask server on `127.0.0.1` using a dynamic free port.
- 🐍 **Embedded Python**: Python 3.11 and the Flask/yt-dlp runtime are packaged with the Android app through Chaquopy.
- ⚡ **Android-native FFmpeg**: MP3 conversion is handled by the bundled Android FFmpeg runtime.
- 🚀 **Metadata Extraction**: Fetches YouTube title, artist/uploader, thumbnail, duration, and URL information.
- 📊 **Real-time Download Tracking**: Reports download progress, speed, ETA, and processing state.
- 🎶 **In-App Music Player**: Play, pause, seek, share, and delete downloaded songs from the app.
- 🔒 **Local API Only**: The embedded Flask server listens on localhost and is not exposed publicly.

## 📁 Repository Structure

```text
song_downloader/
├── frontend/
│   ├── lib/
│   │   ├── models/                 # Application models
│   │   ├── screens/                # Flutter UI screens
│   │   └── services/               # API, storage, and local-server services
│   ├── android/
│   │   └── app/
│   │       └── src/main/
│   │           ├── kotlin/         # Android integration + FFmpeg bridge
│   │           └── python/         # Embedded Flask server
│   └── pubspec.yaml
│
├── .gitignore
└── README.md
```

The old standalone Render/Python backend has been removed because it is no longer used by the application.

## 🚀 Quick Start

### Requirements

- Flutter SDK
- Android SDK / Android Studio
- Android NDK
- Python 3.11 on the development machine for Chaquopy builds
- An ARM64 Android device or emulator for the current configuration

### Run the app

```bash
cd frontend
flutter pub get
flutter run
```

For a clean Android build:

```bash
cd frontend
flutter clean
cd android
./gradlew clean
cd ..
flutter pub get
flutter run
```

### Python used by Chaquopy on the current development machine

The current Gradle configuration uses:

```text
/opt/homebrew/bin/python3.11
```

Update this path in `frontend/android/app/build.gradle.kts` if Python 3.11 is installed elsewhere.

## 🔧 Local Server Architecture

When the Android app starts:

```text
Flutter
   ↓
Android/Kotlin
   ↓
Chaquopy Python 3.11
   ↓
Flask
   ↓
127.0.0.1:<dynamic-port>
```

Flutter receives the dynamically assigned localhost URL and uses it for all API calls.

Each device therefore has an independent local server and download directory.

## 🎵 Download Pipeline

```text
YouTube URL
    ↓
yt-dlp
    ↓
Best available audio source
    ↓
Android-native FFmpeg
    ↓
MP3 320 kbps
    ↓
Local app storage
    ↓
Flutter music player
```

The MP3 bitrate does not increase the quality of the original YouTube source; it only controls the output MP3 encoding bitrate.

## 🌐 Local API

| Method | Endpoint | Description |
| :--- | :--- | :--- |
| `GET` | `/api/health` | Local server health check |
| `POST` | `/api/audio/info` | Fetch YouTube metadata |
| `POST` | `/api/audio/download` | Start a background download job |
| `GET` | `/api/audio/progress/<job_id>` | Get download/processing progress |
| `GET` | `/api/audio/file/<job_id>` | Return the completed MP3 file |
| `DELETE` | `/api/audio/job/<job_id>` | Remove a completed local job/file |

The server binds to `127.0.0.1` only.

## 🛠️ Technology Stack

- **Mobile App**: Flutter / Dart
- **Android integration**: Kotlin
- **Embedded Python**: Chaquopy + Python 3.11
- **Local API**: Flask
- **Audio extraction**: yt-dlp
- **Audio conversion**: Android-native FFmpeg
- **Networking**: Dio
- **Storage**: Path Provider
- **Playback**: Audio player

## ⚠️ Personal Use

This project is intended for personal use. Make sure you have the necessary rights or permissions for any media you download and comply with the terms applicable to the source service and the content.

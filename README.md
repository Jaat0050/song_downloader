# Song Downloader

A personal-use Flutter + Android application for downloading the best available **audio-only stream** from a YouTube URL that you are authorized to save.

## Stack

- Flutter UI
- Android Kotlin platform channel
- `yt-dlp-android` 2.0.2 for media extraction/download
- YouTube oEmbed for lightweight title/artist/thumbnail metadata

## How it works

```text
Paste YouTube URL
      ↓
YouTube oEmbed → title / artist / thumbnail
      ↓
Flutter MethodChannel
      ↓
Android Kotlin
      ↓
yt-dlp → bestaudio
      ↓
Original audio format (.m4a / .webm / .opus, depending on source)
      ↓
Android app-specific Music/SongDownloader directory
```

The app deliberately preserves the best available source audio instead of pretending that converting a lower-quality source to 320 kbps improves quality.

## Run

```bash
flutter pub get
flutter run
```

Android 7.0+ (API 24+) is required by the bundled `yt-dlp-android` library.

## Important

This is intended for personal use and authorized downloads. Respect the rights of content owners and the terms of the services you access. The app does not provide a general license to download copyrighted material.

## Notes

The `yt-dlp-android` AAR bundles a Python runtime and yt-dlp, so the APK/AAB is substantially larger than a typical Flutter app. Its bundled yt-dlp version is updated by changing the dependency version in `android/app/build.gradle.kts`.

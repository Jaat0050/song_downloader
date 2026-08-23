
plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    id("com.chaquo.python")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.song_downloder"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = "27.0.12077973"
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "com.example.song_downloder"
        minSdk = maxOf(flutter.minSdkVersion, 24)
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        ndk {
            abiFilters += listOf("arm64-v8a")
        }
    }

    buildTypes {
        release { signingConfig = signingConfigs.getByName("debug") }
    }

    dependencies {
        // Android-native FFmpeg library used by AudioTranscoder.kt. This keeps
        // FFmpeg out of the Python runtime and makes MP3 conversion available
        // directly on the device.
        implementation("dev.ffmpegkit-maintained:ffmpeg-kit-audio:8.1.7")
    }
}

chaquopy {
    defaultConfig {
        version = "3.11"
        buildPython("/opt/homebrew/bin/python3.11")
        pip {
            install("Flask==3.1.0")
            install("yt-dlp[default]==2026.08.19")
        }
    }
}

flutter {
    source = "../.."
}

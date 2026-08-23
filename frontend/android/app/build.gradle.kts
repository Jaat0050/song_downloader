
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

        // Chaquopy requires explicit ABI selection. The app targets modern
        // ARM64 Android devices and keeps the embedded Python runtime small.
        ndk {
            abiFilters += listOf("arm64-v8a")
        }
    }

    buildTypes {
        release { signingConfig = signingConfigs.getByName("debug") }
    }
}

chaquopy {
    defaultConfig {
        version = "3.11"
        // Chaquopy must build Python 3.11 packages with a Python 3.11 host
        // interpreter. Do not use the macOS `python3` alias, which may point
        // to Python 3.14 on the developer machine.
        buildPython("python3.11")
        pip {
            install("Flask==3.1.0")
            install("yt-dlp[default]==2026.08.19")
        }
    }
}

flutter {
    source = "../.."
}

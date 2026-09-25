import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Release signing (PLAT-04, D-14). android/key.properties is gitignored and never
// committed. The release workflow writes it from GitHub secrets; the owner may
// create one locally (docs/RELEASE-SIGNING.md). When it is missing, release builds
// fall back to the debug key so `flutter run --release` and PR builds still work.
// Never throw here: this script is evaluated for every variant.
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    FileInputStream(keystorePropertiesFile).use { keystoreProperties.load(it) }
}

android {
    namespace = "bg.izk.radio"
    // Explicit SDK levels (PLAT-01). They equal the Flutter 3.47.5 template values;
    // writing them out stops a Flutter upgrade from moving them silently.
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "bg.izk.radio"
        // 24 is the floor for Flutter 3.47 and audio_session 0.2.x.
        minSdk = 24
        // Google Play requires API 36 since 2026-08-31.
        targetSdk = 36
        // Uses the version code from pubspec.yaml, or --build-number (the release
        // workflow passes the run number). When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (keystorePropertiesFile.exists()) {
            create("release") {
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
                storeFile = keystoreProperties.getProperty("storeFile")?.let { file(it) }
                storePassword = keystoreProperties.getProperty("storePassword")
            }
        }
    }

    buildTypes {
        release {
            // Upload key when android/key.properties exists, otherwise the debug key.
            // release.yml refuses to run without the signing secrets and rejects any
            // artifact signed with the debug certificate.
            // Resource shrinking stays on (Flutter default); res/raw/keep.xml keeps
            // audio_service's notification drawables.
            signingConfig = if (keystorePropertiesFile.exists()) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}

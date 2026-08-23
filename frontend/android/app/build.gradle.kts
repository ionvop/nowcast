import java.util.Base64

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Reads a `--dart-define=KEY=VALUE` value passed to `flutter run`/`flutter build`.
// Flutter forwards these to Gradle as the `dart-defines` property: a
// comma-separated list of base64-encoded `KEY=VALUE` strings.
fun dartDefine(key: String): String {
    val defines = (project.findProperty("dart-defines") as? String) ?: return ""
    return defines
        .split(",")
        .mapNotNull { encoded ->
            runCatching { String(Base64.getDecoder().decode(encoded)) }.getOrNull()
        }
        .firstOrNull { it.startsWith("$key=") }
        ?.substring(key.length + 1)
        ?: ""
}

android {
    namespace = "com.ionvop.nowcast"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.ionvop.nowcast"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        // Client Google Maps API key, injected from --dart-define=GOOGLE_MAPS_CLIENT_KEY.
        manifestPlaceholders["mapsApiKey"] = dartDefine("GOOGLE_MAPS_CLIENT_KEY")
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
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

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
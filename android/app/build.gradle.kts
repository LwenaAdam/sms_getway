import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.lwenatech.sms_gateway"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    defaultConfig {
        applicationId = "com.lwenatech.sms_gateway"
        minSdk = flutter.minSdkVersion  // Android 5.0 (Lollipop) - Required for most SMS features
        targetSdk = 34  // Android 14 - Latest stable
        versionCode = 1
        versionName = "1.0.0"
    }

    val keystoreProperties = Properties()
    val keystorePropertiesFile = rootProject.file("key.properties")
    if (keystorePropertiesFile.exists()) {
        FileInputStream(keystorePropertiesFile).use { input ->
            keystoreProperties.load(input)
        }
        signingConfigs {
            create("release") {
                val storeFilePath = keystoreProperties["storeFile"] as String? ?: ""
                val resolvedFile = file(storeFilePath)
                storeFile = if (resolvedFile.exists()) resolvedFile else rootProject.file(storeFilePath)
                storePassword = keystoreProperties["storePassword"] as String?
                keyAlias = keystoreProperties["keyAlias"] as String?
                keyPassword = keystoreProperties["keyPassword"] as String?
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (keystorePropertiesFile.exists()) {
                signingConfigs.getByName("release")
            } else {
                // Fallback to debug signing for local builds when no release key is configured.
                signingConfigs.getByName("debug")
            }
            // Use Kotlin DSL property names
            isMinifyEnabled = false
            isShrinkResources = false
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    // WorkManager for background task scheduling
    implementation("androidx.work:work-runtime:2.9.0")
}

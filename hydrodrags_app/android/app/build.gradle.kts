import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// key.properties and keystore live in android/ (parent of app/)
val keystorePropertiesFile = project.file("../key.properties")
val keystoreProperties = Properties()
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(keystorePropertiesFile.inputStream())
}

android {
    namespace = "com.koesterventures.hydrodrags"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "com.koesterventures.hydrodrags"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (keystorePropertiesFile.exists()) {
            val storeFileProp = keystoreProperties.getProperty("storeFile") ?: error("key.properties: storeFile is missing")
            create("release") {
                keyAlias = keystoreProperties.getProperty("keyAlias") ?: error("key.properties: keyAlias is missing")
                keyPassword = keystoreProperties.getProperty("keyPassword") ?: error("key.properties: keyPassword is missing")
                storePassword = keystoreProperties.getProperty("storePassword") ?: error("key.properties: storePassword is missing")
                storeFile = project.file("../$storeFileProp")
            }
        }
    }
    buildTypes {
        release {
            signingConfig = if (keystorePropertiesFile.exists()) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
        }
    }
}

flutter {
    source = "../.."
}

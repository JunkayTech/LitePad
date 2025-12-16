plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace "com.example.litepad"
    compileSdkVersion 34   // 👈 set a real number

    ndkVersion "27.0.12077973"

    defaultConfig {
        applicationId "com.example.litepad"
        minSdkVersion 21        // 👈 set minimum supported SDK
        targetSdkVersion 34     // 👈 set target SDK
        versionCode 1           // 👈 set your version code
        versionName "1.0"       // 👈 set your version name
    }

    compileOptions {
        sourceCompatibility JavaVersion.VERSION_11
        targetCompatibility JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = "11"
    }

    buildTypes {
        release {
            signingConfig signingConfigs.debug
            minifyEnabled false
            shrinkResources false
        }
        debug {
            // Keep defaults
        }
    }

    packagingOptions {
        resources {
            excludes += [
                "META-INF/LICENSE*",
                "META-INF/NOTICE*",
                "META-INF/DEPENDENCIES"
            ]
        }
    }
}

flutter {
    source "../.."
}

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.example"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.example.example"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    flavorDimensions += "environment"
    
    productFlavors {
        create("dev") {
            dimension = "environment"
            applicationId = "com.example.example.dev"
            versionNameSuffix = "-dev"
            resValue("string", "app_name", "Example Dev")
            manifestPlaceholders["appName"] = "Example Dev"
            manifestPlaceholders["activityName"] = "com.example.example.MainActivity"
            // Flavor-specific icon resources are in src/dev/res/
            // Android automatically merges src/dev/res with src/main/res
        }
        
        create("prod") {
            dimension = "environment"
            applicationId = "com.example.example"
            resValue("string", "app_name", "Example")
            manifestPlaceholders["appName"] = "Example"
            manifestPlaceholders["activityName"] = "com.example.example.MainActivity"
            // Flavor-specific icon resources are in src/prod/res/
            // Android automatically merges src/prod/res with src/main/res
        }
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}

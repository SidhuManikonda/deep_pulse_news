import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

val keyPropertiesFile = rootProject.file("key.properties")
val keyProperties = Properties()
if (keyPropertiesFile.exists()) {
    keyProperties.load(keyPropertiesFile.inputStream())
} else {
    // Debug builds are fine without it — they use the local debug keystore. A
    // release build is not: without the upload key there is nothing correct to
    // sign with, so fail here with an explanation rather than emit a bundle the
    // Play Store will reject after the upload.
    gradle.taskGraph.whenReady {
        val wantsRelease = allTasks.any { task ->
            task.name.contains("Release") && task.project.name == "app"
        }
        if (wantsRelease) {
            throw GradleException(
                "android/key.properties is missing, so this release build has no " +
                    "upload key to sign with.\n" +
                    "Create android/key.properties with keyAlias, keyPassword, " +
                    "storeFile and storePassword pointing at the release keystore " +
                    "(the one whose SHA-1 is registered with Play), then build " +
                    "again.\n" +
                    "Debug builds do not need it."
            )
        }
    }
}

android {
    namespace = "media.deeppulse.news"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
        // Required by flutter_local_notifications (uses java.time backport)
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    signingConfigs {
        // key.properties is not checked in, so only wire up release signing when
        // it is actually present — otherwise configuration fails for debug builds too.
        if (keyPropertiesFile.exists()) {
            create("release") {
                keyAlias = keyProperties["keyAlias"] as String
                keyPassword = keyProperties["keyPassword"] as String
                storeFile = file(keyProperties["storeFile"] as String)
                storePassword = keyProperties["storePassword"] as String
            }
        }
    }

    defaultConfig {
        applicationId = "media.deeppulse.news"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        // Required by flutter_local_notifications when using desugaring
        multiDexEnabled = true
    }

    buildTypes {
        release {
            // Only the real upload key, never a fallback. Signing a release with
            // the debug key produces a bundle the Play Store rejects ("signed
            // with the wrong key"), and it fails at upload rather than at build
            // — see the guard below, which stops that build up front instead.
            signingConfig =
                if (keyPropertiesFile.exists()) {
                    signingConfigs.getByName("release")
                } else {
                    null
                }
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    // Core library desugaring — required by flutter_local_notifications
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}

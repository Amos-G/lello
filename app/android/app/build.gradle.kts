plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val releaseKeystore = rootProject.file("../../release/partysync-release.p12")
val releaseKeystorePassword = System.getenv("PARTYSYNC_KEYSTORE_PASSWORD")
val hasReleaseKey = releaseKeystore.exists() && !releaseKeystorePassword.isNullOrBlank()
if (!hasReleaseKey && gradle.startParameter.taskNames.any { it.contains("Release", ignoreCase = true) }) {
    throw GradleException(
        "Firma release non configurata: keystore o PARTYSYNC_KEYSTORE_PASSWORD mancanti."
    )
}

android {
    namespace = "it.partysync.partysync"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "it.partysync.partysync"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasReleaseKey) {
            create("release") {
                keyAlias = "partysync"
                keyPassword = releaseKeystorePassword
                storeFile = releaseKeystore
                storePassword = releaseKeystorePassword
                storeType = "PKCS12"
            }
        }
    }

    buildTypes {
        release {
            if (hasReleaseKey) {
                signingConfig = signingConfigs.getByName("release")
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

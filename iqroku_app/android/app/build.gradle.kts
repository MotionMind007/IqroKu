plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

val releaseStoreFile = providers.gradleProperty("IQROKU_RELEASE_STORE_FILE")
    .orElse(providers.environmentVariable("IQROKU_RELEASE_STORE_FILE"))
val releaseStorePassword = providers.gradleProperty("IQROKU_RELEASE_STORE_PASSWORD")
    .orElse(providers.environmentVariable("IQROKU_RELEASE_STORE_PASSWORD"))
val releaseKeyAlias = providers.gradleProperty("IQROKU_RELEASE_KEY_ALIAS")
    .orElse(providers.environmentVariable("IQROKU_RELEASE_KEY_ALIAS"))
val releaseKeyPassword = providers.gradleProperty("IQROKU_RELEASE_KEY_PASSWORD")
    .orElse(providers.environmentVariable("IQROKU_RELEASE_KEY_PASSWORD"))

fun releaseSigningConfigured(): Boolean =
    releaseStoreFile.isPresent &&
        releaseStorePassword.isPresent &&
        releaseKeyAlias.isPresent &&
        releaseKeyPassword.isPresent

gradle.taskGraph.whenReady {
    if (!releaseSigningConfigured() && allTasks.any { it.name.contains("Release") }) {
        throw GradleException(
            "Release signing is not configured. Set IQROKU_RELEASE_STORE_FILE, " +
                "IQROKU_RELEASE_STORE_PASSWORD, IQROKU_RELEASE_KEY_ALIAS, and " +
                "IQROKU_RELEASE_KEY_PASSWORD."
        )
    }
}

android {
    namespace = "com.motionmind.iqroku"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.motionmind.iqroku"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            if (releaseSigningConfigured()) {
                storeFile = file(releaseStoreFile.get())
                storePassword = releaseStorePassword.get()
                keyAlias = releaseKeyAlias.get()
                keyPassword = releaseKeyPassword.get()
            }
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
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

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    // Firebase — must be AFTER all other plugins
    id("com.google.gms.google-services")
    id("com.google.firebase.crashlytics")
}

import java.util.Properties
import java.io.FileInputStream

// SEC-1: Load release signing config from key.properties (if it exists)
val keystorePropertiesFile = rootProject.file("app/key.properties")
val keystoreProperties = Properties()
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "com.splitsmart.splitsmart"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        // Required by flutter_local_notifications
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // Play-facing app identity. NOTE: differs from `namespace` above on
        // purpose — namespace is the internal code package (kept stable to
        // avoid moving Kotlin sources); applicationId is the unique Play /
        // Firebase identifier. The original com.splitsmart.splitsmart was
        // already taken on Google Play by another developer.
        applicationId = "com.mighiana.splitsmart"
        // flutter_local_notifications and Firebase require minSdk 21+;
        // flutter_secure_storage (DB encryption key) requires 23+.
        minSdk = maxOf(flutter.minSdkVersion, 23)
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    // ── Dev / Prod environments ──────────────────────────────────────────────
    // Each flavor maps to its OWN Firebase project via a flavor-specific
    // google-services.json under src/<flavor>/. The `dev` flavor uses a
    // separate package id (…​.dev) so it can be installed alongside prod and
    // points at a sandbox Firebase project — testing never touches real data.
    //
    // IMPORTANT: builds now REQUIRE a flavor. Use:
    //   flutter run    --flavor prod -d <device>
    //   flutter build  apk --release --flavor prod
    // Dev needs android/app/src/dev/google-services.json from the dev project.
    flavorDimensions += "env"
    productFlavors {
        create("prod") {
            dimension = "env"
            // production applicationId = com.mighiana.splitsmart (from defaultConfig)
            manifestPlaceholders["appName"] = "SplitSmart"
        }
        create("dev") {
            dimension = "env"
            applicationIdSuffix = ".dev"
            versionNameSuffix = "-dev"
            // Distinct launcher label so the sandbox app is obvious on-device.
            manifestPlaceholders["appName"] = "SplitSmart Dev"
        }
    }

    signingConfigs {
        if (keystorePropertiesFile.exists()) {
            create("release") {
                keyAlias = keystoreProperties["keyAlias"]?.toString() ?: ""
                keyPassword = keystoreProperties["keyPassword"]?.toString() ?: ""
                storeFile = file(keystoreProperties["storeFile"]?.toString() ?: "")
                storePassword = keystoreProperties["storePassword"]?.toString() ?: ""
            }
        }
    }

    buildTypes {
        release {
            // SEC: never silently ship a release signed with the debug key.
            // For local testing only you may opt in explicitly with
            //   flutter build apk --release -PallowDebugSigningForRelease=true
            // Any real release MUST provide android/app/key.properties.
            val allowDebugSigning =
                (project.findProperty("allowDebugSigningForRelease") as String?)
                    ?.toBoolean() == true
            if (keystorePropertiesFile.exists()) {
                signingConfig = signingConfigs.getByName("release")
            } else if (allowDebugSigning) {
                signingConfig = signingConfigs.getByName("debug")
            } else {
                // No keystore and no explicit opt-in: leave the release unsigned
                // and fail HARD only if a release artifact is actually assembled,
                // so normal debug `flutter run` is unaffected.
                gradle.taskGraph.whenReady {
                    val assemblingRelease = allTasks.any { t ->
                        t.name.contains("Release") &&
                            (t.name.startsWith("assemble") ||
                                t.name.startsWith("bundle") ||
                                t.name.startsWith("package"))
                    }
                    if (assemblingRelease) {
                        throw GradleException(
                            "Release build requires android/app/key.properties (release keystore). " +
                            "Refusing to sign a release with the debug key. " +
                            "For local testing only, pass -PallowDebugSigningForRelease=true."
                        )
                    }
                }
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
    // Firebase Bill of Materials (BOM) for version management
    implementation(platform("com.google.firebase:firebase-bom:33.9.0"))
    implementation("com.google.firebase:firebase-analytics")
    implementation("com.google.firebase:firebase-crashlytics")

    // Core library desugaring — required by flutter_local_notifications
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}


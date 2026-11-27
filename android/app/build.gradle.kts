import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "com.txurtxil.lpb10"
    buildFeatures {
        buildConfig = true
    }
    // 37: requisito del AAR del modulo espejo (LMonitor).
    compileSdk = maxOf(flutter.compileSdkVersion, 37)
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.txurtxil.lpb10"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = maxOf(flutter.minSdkVersion, 23)
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            if (keystorePropertiesFile.exists()) {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }
    flavorDimensions += "distrib"
    productFlavors {
        create("full") {
            dimension = "distrib"
            // Modulo espejo (LMonitor/AAR): la libreria exige minSdk 29.
            // SOLO en el flavor full; play se queda en el minSdk por defecto.
            minSdk = 29
        }
        create("play") { dimension = "distrib" }
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = if (keystorePropertiesFile.exists())
                signingConfigs.getByName("release")
            else signingConfigs.getByName("debug")
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
    // ---- Modulo espejo LMonitor (SOLO flavor full; jamas en play) ----
    "fullImplementation"(files("../../mirror/lmonitor.aar"))
    "fullImplementation"("androidx.car.app:app:1.7.0")
    "fullImplementation"("androidx.car.app:app-projected:1.7.0")
    "fullImplementation"("androidx.core:core-ktx:1.19.0")
    "fullImplementation"("androidx.preference:preference-ktx:1.2.1")
    "fullImplementation"("androidx.lifecycle:lifecycle-runtime-ktx:2.9.1")
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
    implementation("androidx.car.app:app:1.7.0")
    // El plugin "workmanager" ya trae androidx.work de forma transitiva,
    // pero como dependencia "implementation" suya, que Gradle NO expone al
    // codigo de este modulo. CarDriveService.kt necesita importar WorkManager
    // directamente para encadenar el sondeo cada 90s durante la conduccion,
    // asi que hace falta declararla aqui tambien.
    implementation("androidx.work:work-runtime-ktx:2.9.1")
}

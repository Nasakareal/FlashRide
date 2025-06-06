plugins {
    id("com.android.application")
    id("kotlin-android")
    // El plugin de Flutter SIEMPRE va después de los anteriores:
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    // El namespace debe coincidir con tu package en AndroidManifest.xml
    namespace = "com.example.flashride_app"
    compileSdk = flutter.compileSdkVersion

    defaultConfig {
        applicationId = "com.example.flashride_app"
        // Asegúrate de no bajar de 23 para compatibilidad con google_api_headers
        minSdk = 23
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // Firma con debug temporalmente para flutter run --release
            signingConfig = signingConfigs.getByName("debug")
        }
    }

    // Asegura que todos los plugins usen este NDK
    ndkVersion = "27.0.12077973"

    compileOptions {
        // Compatibilidad con Java 11
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
        // Habilita desugaring de librerías de Java 8+
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }
}

dependencies {
    // Debe ser >=2.1.4 para flutter_local_notifications y otros
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}

flutter {
    source = "../.."
}

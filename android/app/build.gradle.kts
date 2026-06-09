import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    // END: FlutterFire Configuration
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    // 1. ALTERADO AQUI: O namespace precisa acompanhar o novo nome
    namespace = "com.sankofa.okan"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // 2. ALTERADO AQUI: O ID oficial que a Play Store exige
        applicationId = "com.sankofa.okan"
        
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            keyAlias = keystoreProperties.getProperty("keyAlias")
            keyPassword = keystoreProperties.getProperty("keyPassword")
            val keystoreFilePath = keystoreProperties.getProperty("storeFile")
            if (keystoreFilePath != null) {
                storeFile = file(keystoreFilePath)
            }
            storePassword = keystoreProperties.getProperty("storePassword")
        }
    }

    buildTypes {
        release {
            // 1. Assinatura (usa = e getByName)
            signingConfig = signingConfigs.getByName("release")
            
            // 2. Minificação (usa is... = false)
            isMinifyEnabled = false
            isShrinkResources = false
            
            // 3. Proguard (usa parenteses e aspas duplas)
            proguardFiles(
                getDefaultProguardFile("proguard-android.txt"),
                "proguard-rules.pro"
            )
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    implementation("androidx.browser:browser:1.8.0")
    implementation("androidx.core:core:1.13.1")
    implementation("androidx.core:core-ktx:1.13.1")
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.5") // <--- ALTERADO AQUI PARA 2.1.5
}
configurations.all {
    resolutionStrategy {
        force("androidx.browser:browser:1.8.0")
        force("androidx.core:core-ktx:1.13.1")
        force("androidx.core:core:1.13.1")
    }
}
import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Load keystore properties
val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties()
val hasKeystore = keystorePropertiesFile.exists()
if (hasKeystore) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

fun envOrProperty(name: String, prop: String?): String? {
    return System.getenv(name) ?: prop
}

android {
    namespace = "app.mastui"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    val keyAliasProp = keystoreProperties.getProperty("keyAlias")
    val storeFileProp = keystoreProperties.getProperty("storeFile")
    val keyPasswordProp = envOrProperty("MASTUI_KEY_PASSWORD", keystoreProperties.getProperty("keyPassword"))
    val storePasswordProp = envOrProperty("MASTUI_STORE_PASSWORD", keystoreProperties.getProperty("storePassword"))

    val canSignRelease = hasKeystore &&
        !keyAliasProp.isNullOrBlank() &&
        !storeFileProp.isNullOrBlank() &&
        !keyPasswordProp.isNullOrBlank() &&
        !storePasswordProp.isNullOrBlank()

    signingConfigs {
        if (canSignRelease) {
            create("release") {
                keyAlias = keyAliasProp
                keyPassword = keyPasswordProp
                storeFile = storeFileProp?.let { path ->
                    if (file(path).exists()) file(path) else rootProject.file(path)
                }
                storePassword = storePasswordProp
            }
        }
    }

    defaultConfig {
        applicationId = "app.mastui"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.findByName("release") ?: signingConfigs.getByName("debug")
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

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
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

fun envOrProperty(name: String, prop: String?): String {
    return System.getenv(name) ?: prop ?: throw GradleException(
        "Missing keystore password. Set $name environment variable or add it to key.properties"
    )
}

android {
    namespace = "app.mastui"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    signingConfigs {
        create("release") {
            keyAlias = keystoreProperties["keyAlias"] as String
            keyPassword = envOrProperty("MASTUI_KEY_PASSWORD", keystoreProperties["keyPassword"] as? String)
            storeFile = file(keystoreProperties["storeFile"] as String)
            storePassword = envOrProperty("MASTUI_STORE_PASSWORD", keystoreProperties["storePassword"] as? String)
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

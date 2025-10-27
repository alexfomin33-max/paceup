plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android") // <-- было kotlin-android (Groovy id)
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.paceip"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = "17"
    }

    defaultConfig {
        applicationId = "com.example.paceip"
        minSdk = 26 // Health Connect требует minSdk 26+
        targetSdk = 34
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // Подпись для дебага — замени на свою release-конфигурацию, когда будет готова
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

dependencies {
    // Kotlin DSL: функции, а не строки
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
    implementation("androidx.health.connect:connect-client:1.1.0")
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-android:1.8.1")
}

/*
  В Kotlin DSL обычно 'buildscript' и classpath выносят в settings.gradle(.kts)/root build.gradle(.kts).
  Если у тебя это уже настроено Flutter-плагином, нижний блок можно удалить.
  Оставляю как было, но он не обязателен в модульном build.gradle.kts.
*/
buildscript {
    repositories {
        google()
        mavenCentral()
    }
    dependencies {
        classpath("com.android.tools.build:gradle:8.3.2")
        classpath("org.jetbrains.kotlin:kotlin-gradle-plugin:1.9.23")
    }
}

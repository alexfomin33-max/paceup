plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android") // <-- было kotlin-android (Groovy id)
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services") // Firebase
}

android {
    namespace = "com.example.paceup"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = "29.0.14206865"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = "17"
    }

    defaultConfig {
        applicationId = "com.example.paceup"
        minSdk = 26 // Health Connect требует minSdk 26+
        targetSdk = 34
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        
        // ────────────────────────── Ограничение ABI ──────────────────────────
        // Исключаем armeabi-v7a (armv7) для уменьшения размера APK
        // Оставляем только arm64-v8a (современные устройства) и x86_64 (эмуляторы)
        ndk {
            abiFilters += listOf(
                "arm64-v8a",  // Современные Android устройства (99% рынка при minSdk 26+)
                "x86_64"      // Для тестирования на эмуляторах
            )
        }
    }

    buildTypes {
        release {
            // Подпись для дебага — замени на свою release-конфигурацию, когда будет готова
            signingConfig = signingConfigs.getByName("debug")
            
            // ────────────────────────── Минификация и обфускация ──────────────────────────
            // Включаем минификацию кода для уменьшения размера APK
            isMinifyEnabled = true
            // Удаляем неиспользуемые ресурсы (изображения, строки и т.д.)
            isShrinkResources = true
            // Подключаем ProGuard правила для корректной работы Flutter, Riverpod и Drift
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }

    // ────────────────────────── Переименование выходного APK ──────────────────────────
    // Настраиваем имя выходного APK файла: paceup-release.apk вместо app-release.apk
    applicationVariants.all {
        val variant = this
        variant.outputs.all {
            val output = this as com.android.build.gradle.internal.api.BaseVariantOutputImpl
            output.outputFileName = when (variant.buildType.name) {
                "release" -> "paceup-release.apk"
                "debug" -> "paceup-debug.apk"
                else -> "paceup-${variant.buildType.name}.apk"
            }
        }
    }
}

dependencies {
    // Kotlin DSL: функции, а не строки
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
    implementation("androidx.health.connect:connect-client:1.1.0")
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-android:1.8.1")
}


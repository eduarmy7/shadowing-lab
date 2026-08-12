import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// 2026-08-11: 스토어 업로드용 릴리스 서명 키. `android/key.properties`는 .gitignore로
// 제외되며(키스토어 파일 자체도 마찬가지) 저장소에 커밋되지 않는다 — 로컬에만 존재.
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(keystorePropertiesFile.inputStream())
}

android {
    namespace = "com.ttara.ttara"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        // 2026-08-10: flutter_local_notifications(학습 리마인더)가 요구 — Java 8+ API를
        // API 24 미만 기기에서도 쓸 수 있게 desugaring된 라이브러리로 백포트해준다.
        isCoreLibraryDesugaringEnabled = true
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.ttara.ttara"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            if (keystorePropertiesFile.exists()) {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = rootProject.file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    buildTypes {
        release {
            // key.properties가 없는 환경(예: CI 없이 로컬 디버그만 하는 경우)에서는
            // 빌드가 깨지지 않도록 debug 서명으로 안전하게 폴백한다.
            signingConfig = if (keystorePropertiesFile.exists()) signingConfigs.getByName("release") else signingConfigs.getByName("debug")
            // 2026-08-12: Flutter Gradle 플러그인이 릴리스 빌드에 기본으로 R8 코드 축소를
            // 켜는데, 이게 flutter_local_notifications가 내부적으로 쓰는 Gson의 제네릭
            // 타입 시그니처(TypeToken)를 지워버려서 예약 알림 로드 시 "Missing type
            // parameter" RuntimeException으로 죽는 실제 원인이었다(디버그 빌드는 축소가
            // 없어 재현이 안 됨 — 실기기 릴리스 설치로만 발견됨). 앱 용량 민감도가 낮아
            // (기존 AAB도 실제 다운로드 크기는 13MB 수준) 축소 자체를 끈다.
            isMinifyEnabled = false
            isShrinkResources = false
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}

flutter {
    source = "../.."
}

pluginManagement {
    val flutterSdkPath =
        run {
            val properties = java.util.Properties()
            file("local.properties").inputStream().use { properties.load(it) }
            val flutterSdkPath = properties.getProperty("flutter.sdk")
            require(flutterSdkPath != null) { "flutter.sdk not set in local.properties" }
            flutterSdkPath
        }

    includeBuild("$flutterSdkPath/packages/flutter_tools/gradle")

    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
    // AGP 9.0.1(Flutter 3.44.8 기본값)부터 built-in Kotlin이 강제되는데, file_picker/
    // package_info_plus/wakelock_plus가 아직 구식 kotlin-android 플러그인을 직접 적용해서
    // 충돌한다(GeneratedPluginRegistrant.java: cannot find symbol FilePickerPlugin).
    // 해당 플러그인들이 built-in Kotlin으로 마이그레이션하기 전까지 AGP 8.x로 고정.
    id("com.android.application") version "8.9.1" apply false
    id("org.jetbrains.kotlin.android") version "2.3.20" apply false
}

include(":app")

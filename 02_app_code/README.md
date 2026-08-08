# 쉐도잉랩 (ShadowingLab) — Flutter 앱 소스

> 2026-08-04 사용자 요청으로 "따라(TTARA)"에서 개명. Dart 패키지명(`ttara`), Android
> applicationId(`com.ttara.ttara`), `TtaraApp` 클래스명 등 내부 식별자는 사용자에게 보이지
> 않는 구조적 값이라 의도적으로 그대로 두었다 — 아래 명령어의 `ttara`/`com.ttara`는 오타가
> 아니다.

자동으로 문장을 나눠주는 영어 쉐도잉 학습 앱. `lib/` 애플리케이션 레이어 소스만 포함되어 있으며,
네이티브 러너(android/ios)는 포함되어 있지 않습니다.

## 로컬 실행 준비

이 디렉토리에는 Dart/Flutter 애플리케이션 코드(`lib/`, `pubspec.yaml`)만 존재합니다.
실제 기기/시뮬레이터에서 빌드하려면 아래 순서로 네이티브 러너를 생성하세요.

```bash
# 1. 별도의 빈 폴더에 표준 Flutter 프로젝트 골격 생성
flutter create --org com.ttara --project-name ttara ttara_runner

# 2. 이 디렉토리의 lib/, pubspec.yaml, analysis_options.yaml 을 방금 생성된
#    ttara_runner/ 위에 덮어쓰기 (android/, ios/ 등 네이티브 폴더는 유지)
cp -r lib pubspec.yaml analysis_options.yaml ttara_runner/

cd ttara_runner
flutter pub get
flutter run
```

## flutter create 이후 필수 네이티브 패치

`flutter create`가 생성하는 기본 `android/`는 이 앱을 그대로 실행하지 못합니다 — 아래 3가지를
빠짐없이 적용해야 스플래시 화면에서 멈추지 않고 실제로 뜹니다 (2026-08-04 Flutter 3.44.8 +
Android emulator 기준 실제 빌드·실행으로 검증됨. `analyze`/코드 리딩만으로는 못 잡는 문제들):

1. **`android/app/src/main/kotlin/.../MainActivity.kt`**: `FlutterActivity` 대신
   `com.ryanheise.audioservice.AudioServiceFragmentActivity`를 상속해야 합니다.
   그렇지 않으면 `main()`의 `JustAudioBackground.init()`이 "wrong Activity class"
   `PlatformException`을 던지며 `runApp()` 도달 전에 조용히 죽어, 앱이 네이티브 스플래시
   화면에서 영원히 멈춥니다(logcat 없이는 원인 파악 불가).
   ```kotlin
   package com.ttara.ttara
   import com.ryanheise.audioservice.AudioServiceFragmentActivity
   class MainActivity : AudioServiceFragmentActivity()
   ```

2. **`android/app/src/main/AndroidManifest.xml`**: 기본 템플릿엔 `<uses-permission>`이
   전혀 없고, `just_audio_background`가 요구하는 `AudioService`/`MediaButtonReceiver`
   서비스 선언도 없습니다. 아래 권한 표의 매니페스트 권한 전부 + 다음 두 컴포넌트를
   `<application>` 안에 추가하세요 (서비스 선언 누락 시 크래시는 안 나지만 백그라운드
   재생이 조용히 실패합니다):
   ```xml
   <service android:name="com.ryanheise.audioservice.AudioService"
       android:foregroundServiceType="mediaPlayback" android:exported="true"
       tools:ignore="Instantiatable">
       <intent-filter><action android:name="android.media.browse.MediaBrowserService" /></intent-filter>
   </service>
   <receiver android:name="com.ryanheise.audioservice.MediaButtonReceiver"
       android:exported="true" tools:ignore="Instantiatable">
       <intent-filter><action android:name="android.intent.action.MEDIA_BUTTON" /></intent-filter>
   </receiver>
   ```
   (manifest 루트에 `xmlns:tools="http://schemas.android.com/tools"` 추가 필요)

3. **`android/settings.gradle.kts`**: `com.android.application` 버전을 `9.0.1`(Flutter
   3.44.8 기본값)이 아니라 **`8.9.1`로 고정**하세요. AGP 9는 built-in Kotlin을 강제하는데
   file_picker/package_info_plus/wakelock_plus가 아직 구식 `org.jetbrains.kotlin.android`를
   직접 적용해서 충돌합니다 — 증상은 Kotlin 에러가 아니라
   `GeneratedPluginRegistrant.java`의 알쏭달쏭한 `cannot find symbol FilePickerPlugin`
   컴파일 에러로 나타나서 원인 추적이 어렵습니다. (`gradle.properties`의
   `android.builtInKotlin=false`만으로는 완전히 우회되지 않았음 — 실제로 검증됨.)

## 필요 권한 (store-manager 전달 사항 — 04 문서 참고)

| 권한 | 플랫폼 | 용도 |
|---|---|---|
| 파일/미디어 접근 | iOS `NSPhotoLibraryUsageDescription` 불필요(문서선택기 사용), Android `READ_MEDIA_AUDIO`/`READ_MEDIA_VIDEO` (API 33+) 또는 `READ_EXTERNAL_STORAGE` | 로컬 음성/영상 파일 업로드 |
| 마이크 | iOS `NSMicrophoneUsageDescription`, Android `RECORD_AUDIO` | 쉐도잉 "따라 말하기" 녹음(선택 기능 — 거부 시 듣기 전용 모드로 대체) |
| 알림 | iOS `UNUserNotificationCenter`, Android `POST_NOTIFICATIONS` (API 33+) | 학습 리마인더 |
| 인앱결제 | iOS StoreKit, Android Billing | PRO 구독 |

## 아키텍처

`_workspace/02_app_architecture.md` 참고.

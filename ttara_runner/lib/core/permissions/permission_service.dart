import 'dart:async';

import 'package:permission_handler/permission_handler.dart';

/// 알림 설정 화면에서 OS 설정 앱으로 이동시키는 용도로만 쓰인다.
///
/// 2026-08-08: 마이크 권한 요청 메서드(`requestMicrophone`/`checkMicrophone`)를
/// 제거했다 — 앱은 어디에서도 실제로 마이크 오디오를 녹음/분석하지 않는다
/// ("따라 말하기" 단계는 사용자가 스스로 말할 시간을 주는 타이머일 뿐이다).
///
/// 2026-08-24: 온보딩에서 쓰던 `requestMediaLibrary()`(미디어 라이브러리 권한
/// 요청)를 제거했다 — 실제 파일 선택은 `file_picker`가 Android SAF(시스템 파일
/// 선택 도구)로 처리해 이 권한이 전혀 필요 없었고, Google Play "사진 및 동영상
/// 권한 정책" 위반으로 업데이트 심사가 거절됐다.
class PermissionService {
  Future<void> openSettings() => openAppSettings();
}

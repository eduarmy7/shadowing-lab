import 'dart:async';

import 'package:permission_handler/permission_handler.dart';

enum AppPermissionStatus { granted, denied, permanentlyDenied }

/// 마이크/파일 접근 권한 요청을 감싼 서비스. 온보딩(#0) 마지막 슬라이드와
/// 파일 업로드(#2)/쉐도잉 학습(#5) 진입 시 사용.
///
/// 마이크 권한은 선택 기능이다 — 거부되어도 "따라 말하기" 단계를 건너뛰고
/// 듣기 전용으로 학습 루프가 정상 동작해야 한다 (접근성 요구사항, ShadowingController 참고).
class PermissionService {
  Future<AppPermissionStatus> requestMicrophone() async {
    final status = await Permission.microphone.request();
    return _map(status);
  }

  Future<AppPermissionStatus> requestMediaLibrary() async {
    // Android 13+ 는 세분화된 미디어 권한, 그 이하는 storage로 폴백.
    final status = await Permission.mediaLibrary.request();
    return _map(status);
  }

  Future<AppPermissionStatus> checkMicrophone() async {
    return _map(await Permission.microphone.status);
  }

  Future<void> openSettings() => openAppSettings();

  AppPermissionStatus _map(PermissionStatus status) {
    if (status.isGranted || status.isLimited) return AppPermissionStatus.granted;
    if (status.isPermanentlyDenied) return AppPermissionStatus.permanentlyDenied;
    return AppPermissionStatus.denied;
  }
}

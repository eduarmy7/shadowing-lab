import 'dart:async';

import 'package:permission_handler/permission_handler.dart';

enum AppPermissionStatus { granted, denied, permanentlyDenied }

/// 파일 접근 권한 요청을 감싼 서비스. 온보딩(#0) 마지막 슬라이드와
/// 파일 업로드(#2) 진입 시 사용.
///
/// 2026-08-08: 마이크 권한 요청 메서드(`requestMicrophone`/`checkMicrophone`)를
/// 제거했다 — 앱은 어디에서도 실제로 마이크 오디오를 녹음/분석하지 않는다
/// ("따라 말하기" 단계는 사용자가 스스로 말할 시간을 주는 타이머일 뿐이다).
class PermissionService {
  Future<AppPermissionStatus> requestMediaLibrary() async {
    // Android 13+ 는 세분화된 미디어 권한, 그 이하는 storage로 폴백.
    final status = await Permission.mediaLibrary.request();
    return _map(status);
  }

  Future<void> openSettings() => openAppSettings();

  AppPermissionStatus _map(PermissionStatus status) {
    if (status.isGranted || status.isLimited) return AppPermissionStatus.granted;
    if (status.isPermanentlyDenied) return AppPermissionStatus.permanentlyDenied;
    return AppPermissionStatus.denied;
  }
}

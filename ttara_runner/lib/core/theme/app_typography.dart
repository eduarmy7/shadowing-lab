import 'package:flutter/material.dart';

/// 01_ux_design.md "타이포그래피" 표 매핑.
/// fontFamily 'Pretendard'는 assets/fonts/ 미배치 시 시스템 폰트(SF Pro/Roboto)로
/// 자동 폴백된다 (pubspec.yaml 주석 참고).
abstract class AppTypography {
  static const String fontFamily = 'Pretendard';

  static const display = TextStyle(
    fontFamily: fontFamily,
    fontSize: 32,
    fontWeight: FontWeight.w700,
    height: 1.25,
  );

  static const headline = TextStyle(
    fontFamily: fontFamily,
    fontSize: 24,
    fontWeight: FontWeight.w600,
    height: 1.3,
  );

  static const title = TextStyle(
    fontFamily: fontFamily,
    fontSize: 18,
    fontWeight: FontWeight.w500,
    height: 1.35,
  );

  /// 쉐도잉 문장 텍스트 — 가변(22~28sp), 기본값 24. Dynamic Type 대응은
  /// 위젯에서 MediaQuery.textScaler를 곱해 최대 200%까지 허용.
  static const sentence = TextStyle(
    fontFamily: fontFamily,
    fontSize: 24,
    fontWeight: FontWeight.w500,
    height: 1.4,
    letterSpacing: 0.2,
  );

  static const body = TextStyle(
    fontFamily: fontFamily,
    fontSize: 15,
    fontWeight: FontWeight.w400,
    height: 1.5,
  );

  static const label = TextStyle(
    fontFamily: fontFamily,
    fontSize: 13,
    fontWeight: FontWeight.w500,
    height: 1.3,
  );

  static const caption = TextStyle(
    fontFamily: fontFamily,
    fontSize: 12,
    fontWeight: FontWeight.w400,
    height: 1.3,
  );
}

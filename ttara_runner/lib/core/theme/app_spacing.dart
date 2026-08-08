/// 8dp 그리드 기반 스페이싱 토큰 (01_ux_design.md "스페이싱/그리드" 표 매핑).
abstract class AppSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 48;

  /// 전 화면 공통 좌우 마진.
  static const double screenMargin = 20;

  static const double cardRadius = 16;
  static const double buttonRadius = 12;

  /// 원형 CTA(쉐도잉 학습 화면 primary 버튼) 등 full-round 컴포넌트.
  static const double fullRadius = 999;

  /// 모든 인터랙션 요소 공통 최소 터치 타깃.
  static const double minTouchTarget = 48;

  /// 학습화면 원형 CTA는 핵심 액션이므로 확대 적용.
  static const double primaryCtaSize = 72;
}

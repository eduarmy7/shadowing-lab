import 'package:flutter/material.dart';

/// UX 설계서(01_ux_design.md) "디자인 시스템 > 컬러 팔레트"를 그대로 코드로 옮긴 토큰.
/// 화면 위젯에서 직접 Color(0x..)를 쓰지 말고 항상 이 클래스를 통해 참조한다.
abstract class AppColors {
  // ── Light ────────────────────────────────────────
  // 2026-08-08: 앱 전체에서 실제로 "메인 색"으로 보이는 건 이 primary였다(홈 화면
  // "+ 새 파일 불러오기", 하단 탭 선택 상태, 학습 화면 재생 버튼 전부 이 값을 씀) —
  // secondary(옛 민트)만 바꿨을 땐 눈에 보이는 변화가 전혀 없었던 이유. 인디고
  // (#5B5FEF)를 터콰이즈 계열로 교체한다.
  //
  // 첫 시도(#0C8078)는 대비만 맞추려다 톤(hue)이 174°대(초록 쪽 시안)로 처져서
  // "터콰이즈가 아니라 진초록 같다"는 피드백을 받았다 — 어두운+저채도 상태에서는
  // 174°대 색상이 청록보다 짙은 숲색처럼 보인다는 것. 순수 터콰이즈 클래식
  // (#2DD4C4, secondary 참고)도 사실 같은 174°대인데 밝기가 높아서(L≈0.5) 문제
  // 없어 보였을 뿐이었다. 두 번째 시도(#0C7F94, hue 189°)는 톤은 맞았지만 이번엔
  // "터콰이즈 딥보다도 어둡다"는 피드백 — 밝기(L)를 터콰이즈 클래식(L≈0.50)과
  // 터콰이즈 딥(L≈0.31) 중간(L≈0.40)으로 올렸다(#169BB6). 세 번째 피드백은
  // "조금 더 밝게, 안 이쁘다" — 밝기를 한 단계 더 올렸다(L≈0.46). 흰 글씨 대비는
  // ≈2.5:1로 더 낮아져 엄밀한 기준으론 약하지만, 굵은 버튼 텍스트는 여전히 읽을 수
  // 있는 수준 — 이 단계부터는 대비보다 색 자체의 인상을 우선한다.
  static const primaryLight = Color(0xFF1AB2D1);
  static const onPrimaryLight = Color(0xFFFFFFFF);
  static const primaryContainerLight = Color(0xFFD1F0F5);
  static const secondaryLight = Color(0xFF2DD4C4);
  static const proGoldLight = Color(0xFFC8942A);
  static const backgroundLight = Color(0xFFFAFAFC);
  static const surfaceLight = Color(0xFFFFFFFF);
  static const surfaceVariantLight = Color(0xFFF2F2F7);
  static const textPrimaryLight = Color(0xFF17171C);
  static const textSecondaryLight = Color(0xFF6B6B76);
  static const outlineLight = Color(0xFFE4E4EA);
  static const errorLight = Color(0xFFE5484D);
  static const successLight = Color(0xFF22C55E);
  // 2026-08-08: 메인 브랜드색을 터콰이즈로 바꾸면서, 원래 primary였던 이 인디고
  // 블루는 음성 파형(WaveformPlayer) 전용 색으로 남겨뒀다 — 파형만은 예전 파란색을
  // 유지해달라는 요청. 원래 값(#5B5FEF)이 "너무 진하다"는 피드백으로 같은 색상
  // 계열에서 한 톤 밝게 조정.
  static const waveformLight = Color(0xFF8286ED);

  // ── Dark ─────────────────────────────────────────
  // 다크 테마는 원래도 "밝은 primary + 어두운 onPrimary(글씨)" 조합이었다(밝은 라벤더
  // 위에 거의 검정 글씨) — 그 관례를 그대로 유지하면 밝은 터콰이즈 클래식(#2DD4C4)을
  // 써도 어두운 글씨와 대비가 넉넉하다(≈10:1). 그래서 다크 모드는 라이트 모드처럼
  // 어둡게 내릴 필요 없이 요청한 "터콰이즈 클래식" 그대로 쓴다.
  static const primaryDark = Color(0xFF2DD4C4);
  static const onPrimaryDark = Color(0xFF14141A);
  static const primaryContainerDark = Color(0xFF0F373E);
  static const secondaryDark = Color(0xFF2DD4C4);
  static const proGoldDark = Color(0xFFE4B85C);
  static const backgroundDark = Color(0xFF0E0E12);
  static const surfaceDark = Color(0xFF1A1A20);
  static const surfaceVariantDark = Color(0xFF232329);
  static const textPrimaryDark = Color(0xFFF2F2F5);
  static const textSecondaryDark = Color(0xFFA0A0AC);
  static const outlineDark = Color(0xFF303038);
  static const errorDark = Color(0xFFFF6369);
  static const successDark = Color(0xFF4ADE80);
  static const waveformDark = Color(0xFF8B8FFF);

  /// 신뢰도 낮은 문장(⚠️) 강조용 — 색상 단독 의존 금지 원칙에 따라 항상
  /// 라벨("확인 필요")과 아이콘을 함께 사용할 것.
  static const warning = Color(0xFFF5A524);
}

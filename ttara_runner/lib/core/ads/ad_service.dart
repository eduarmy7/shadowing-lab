import 'package:flutter/material.dart';

/// 광고 SDK 연동 지점(인터페이스). 실제 AdMob/Applovin 등 SDK 연동은 이번 범위 밖 —
/// api-integrator 또는 별도 광고 연동 작업에서 [AdService] 구현체만 교체하면 된다.
///
/// 배치 원칙(01_ux_design.md):
/// - 배너: [TabScaffold] 레벨에서 하단 탭바 바로 위, 콘텐츠와 16dp 여백으로 분리.
/// - 전면: 세션 종료(#6) 화면 진입 시점에만 트리거. 학습 화면(#5) 내부에서는 절대 호출 금지
///   (Hands-free 루프를 강제로 끊게 되므로 — 2026-08-08 확정, 문장 단위 트리거는 폐기).
abstract class AdService {
  /// 배너 광고 슬롯 위젯. 로드 실패/미초기화 시에도 레이아웃이 깨지지 않도록
  /// 항상 고정 높이 컨테이너를 반환해야 한다.
  Widget bannerAdWidget(BuildContext context);

  /// 전면 광고 표시. [minSkipSeconds] 이후 스킵 가능(01_ux_design.md 요구사항).
  /// 실패하거나 광고 재고가 없으면 조용히 완료 콜백만 호출한다(학습 흐름 차단 금지).
  Future<void> showInterstitial({int minSkipSeconds = 5});

  /// 앱 시작 시 1회 호출되는 SDK 초기화 훅.
  Future<void> initialize();
}

/// SDK 미연동 상태의 기본 구현체 — 배너는 플레이스홀더 박스, 전면 광고는 즉시 no-op.
/// 실제 SDK 연동 시 이 클래스와 동일한 인터페이스로 `AdMobAdService` 등을 추가하고
/// `providers.dart`의 [adServiceProvider] 오버라이드만 교체하면 된다.
class NoOpAdService implements AdService {
  @override
  Future<void> initialize() async {}

  @override
  Future<void> showInterstitial({int minSkipSeconds = 5}) async {
    // 실제 SDK 연동 전까지는 즉시 반환 — 학습 흐름을 막지 않음.
    return;
  }

  @override
  Widget bannerAdWidget(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      key: const Key('ad_banner_slot'),
      width: double.infinity,
      height: 50,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(top: BorderSide(color: theme.dividerColor)),
      ),
      child: Text(
        '광고 영역 (SDK 미연동)',
        style: theme.textTheme.bodySmall,
      ),
    );
  }
}

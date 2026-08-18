import 'package:flutter/material.dart';

/// 광고 SDK 연동 지점(인터페이스). 실제 AdMob/Applovin 등 SDK 연동은 이번 범위 밖 —
/// api-integrator 또는 별도 광고 연동 작업에서 [AdService] 구현체만 교체하면 된다.
///
/// 배치 원칙(01_ux_design.md):
/// - 배너: [TabScaffold] 레벨에서 하단 탭바 바로 위, 콘텐츠와 16dp 여백으로 분리.
///   2026-08-10부터 학습 화면(#5)의 재생 버튼 바로 위에도 동일한 배너 위젯을 추가로
///   노출한다(`shadowing_screen.dart`, 한 문장씩/한꺼번에 보기 둘 다) — 재생 버튼
///   자체를 가리지 않는 위치라 아래 전면 광고 금지 원칙과는 무관하다.
/// - 전면: 2026-08-13 사용자 확정 규칙 — (1) 세션 종료(#6) 화면 진입 시점(완주),
///   (2) 학습 화면에서 시스템 뒤로가기(제스처/하드웨어 back)로 세션을 중도 이탈할 때만
///   (`shadowing_screen.dart`의 `PopScope` → `_exitToHome`) — **닫기(X) 버튼은 2026-08-13
///   후속 요청으로 제외**(너무 가볍게 자주 누르는 버튼이라 매번 광고가 뜨면 마찰이 큼),
///   (3) 앱 자체를 종료(뒤로가기로 앱 나가기)할 때(`tab_scaffold.dart`의 `PopScope`),
///   (4) 문장을 20개 완료할 때마다(`shadowing_screen.dart`의 `ref.listen`).
///   콘텐츠 대부분이 1,900문장 안팎으로 길어서, "세션 완주 시 1회"만으로는 전면 광고가
///   사실상 거의 노출되지 않는다는 문제를 이 4개 트리거로 보완한다(2026-08-08에는
///   반대로 몰입 보호를 위해 문장 단위 트리거를 폐기했었는데, 이번에 재도입).
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

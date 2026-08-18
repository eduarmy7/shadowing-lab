import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../l10n/gen/app_localizations.dart';
import '../providers/purchase_providers.dart';
import '../providers/repository_providers.dart';

/// 공통 위젯화 최우선 순위 컴포넌트 — 2탭(홈/마이) 공통 셸.
/// go_router의 StatefulShellRoute.indexedStack과 결합해 탭별 스택을 독립 유지한다.
/// 2026-08-08: 라이브러리(PRO 구독 뉴스) 탭은 별도 앱으로 분리되며 이 앱에서 제거됨.
///
/// 광고 SDK 배치: 배너 슬롯을 이 레벨에서 공통 관리한다. 홈 탭(#1)에서는 인덱스
/// 0에서만 렌더링한다 — 학습 화면(#5)은 이 셸 바깥의 풀스크린 라우트라 이 위젯과는
/// 별개로 자체적으로 배너를 띄운다(`shadowing_screen.dart`, 2026-08-10 추가).
/// "광고 제거" 구매(#4)를 마친 사용자에게는 인덱스와 무관하게 배너를 아예 렌더링하지 않는다.
class TabScaffold extends ConsumerWidget {
  final StatefulNavigationShell navigationShell;

  const TabScaffold({super.key, required this.navigationShell});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final adService = ref.watch(adServiceProvider);
    final adsRemoved = ref.watch(adsRemovedProvider).maybeWhen(data: (v) => v, orElse: () => false);
    final showBanner = navigationShell.currentIndex == 0 && !adsRemoved;
    final l10n = AppLocalizations.of(context)!;

    return PopScope(
      // 2026-08-13: "앱종료하기" 전면 광고 트리거(사용자 확정 규칙) — 이 셸은 각 탭
      // 내부 스택을 다 빠져나온 뒤에야 도달하는 최상위 라우트라, 여기서 뒤로가기가
      // 막힌다는 건 곧 "앱을 완전히 종료하려는 시도"를 의미한다. 광고를 먼저 보여준
      // 뒤 실제 종료([SystemNavigator.pop])로 이어간다.
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        if (!adsRemoved) {
          await adService.showInterstitial();
        }
        await SystemNavigator.pop();
      },
      child: Scaffold(
        body: navigationShell,
        bottomNavigationBar: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (showBanner) adService.bannerAdWidget(context),
            NavigationBar(
              selectedIndex: navigationShell.currentIndex,
              onDestinationSelected: (index) => navigationShell.goBranch(
                index,
                initialLocation: index == navigationShell.currentIndex,
              ),
              destinations: [
                NavigationDestination(
                    icon: const Icon(Icons.home_outlined), selectedIcon: const Icon(Icons.home), label: l10n.tabHome),
                NavigationDestination(
                  icon: const Icon(Icons.person_outline),
                  selectedIcon: const Icon(Icons.person),
                  label: l10n.tabMy,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

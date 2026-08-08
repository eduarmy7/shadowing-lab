import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../l10n/gen/app_localizations.dart';
import '../providers/repository_providers.dart';

/// 공통 위젯화 최우선 순위 컴포넌트 — 3탭(홈/라이브러리/마이) 공통 셸.
/// go_router의 StatefulShellRoute.indexedStack과 결합해 탭별 스택을 독립 유지한다.
///
/// 광고 SDK 배치: 배너 슬롯을 이 레벨에서 공통 관리한다. 단, 01_ux_design.md 와이어프레임상
/// 배너가 실제로 노출되는 곳은 홈 탭(#1)뿐이므로 인덱스 0에서만 렌더링한다 —
/// 학습 화면(#5)은 이 셸 바깥의 풀스크린 라우트라 애초에 광고 SDK 호출 자체가 없다.
class TabScaffold extends ConsumerWidget {
  final StatefulNavigationShell navigationShell;

  const TabScaffold({super.key, required this.navigationShell});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final adService = ref.watch(adServiceProvider);
    final showBanner = navigationShell.currentIndex == 0;
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
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
                icon: const Icon(Icons.auto_stories_outlined),
                selectedIcon: const Icon(Icons.auto_stories),
                label: l10n.tabLibrary,
              ),
              NavigationDestination(
                icon: const Icon(Icons.person_outline),
                selectedIcon: const Icon(Icons.person),
                label: l10n.tabMy,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

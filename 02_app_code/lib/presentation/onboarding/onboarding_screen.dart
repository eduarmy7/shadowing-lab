import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../l10n/gen/app_localizations.dart';
import '../common_widgets/primary_button.dart';
import '../providers/repository_providers.dart';

const _onboardingDoneKey = 'ttara.onboarding_done.v1';

final onboardingCompletedProvider = FutureProvider<bool>((ref) async {
  final store = ref.watch(localKvStoreProvider);
  final done = await store.getJson<bool>(_onboardingDoneKey, (d) => d as bool);
  return done ?? false;
});

class _OnboardingPage {
  final IconData icon;
  // 2026-08-11: 사용법 안내 슬라이드(#3~#6)는 실제 학습 화면 버튼과 똑같은 아이콘
  // 2개를 나란히 보여줘야 "이 버튼이구나"를 바로 알아본다 — 기존 큰 원 아이콘 1개
  // 방식만으로는 뭘 가리키는지 전달이 안 돼서, 값이 있으면 이 리스트를 대신 그린다.
  final List<IconData>? iconRow;
  final String headline;
  final String subtext;
  const _OnboardingPage({required this.icon, this.iconRow, required this.headline, required this.subtext});
}

List<_OnboardingPage> _pagesOf(AppLocalizations l10n) => [
      _OnboardingPage(
        icon: Icons.graphic_eq,
        headline: l10n.onboardingPage1Headline,
        subtext: l10n.onboardingPage1Subtext,
      ),
      _OnboardingPage(
        icon: Icons.record_voice_over,
        headline: l10n.onboardingPage2Headline,
        subtext: l10n.onboardingPage2Subtext,
      ),
      // 2026-08-11: 사용자 요청 — 첫 실행 튜토리얼에 실제 사용법(화면 오른쪽 위 버튼들,
      // 한 문장⇔목록 전환, 편집에서 길이 조절/합치기/나누기)을 추가한다.
      _OnboardingPage(
        icon: Icons.auto_stories,
        iconRow: const [Icons.view_agenda_outlined, Icons.outlined_flag],
        headline: l10n.onboardingPage3Headline,
        subtext: l10n.onboardingPage3Subtext,
      ),
      _OnboardingPage(
        icon: Icons.view_carousel_outlined,
        headline: l10n.onboardingPage4Headline,
        subtext: l10n.onboardingPage4Subtext,
      ),
      _OnboardingPage(
        icon: Icons.edit_outlined,
        iconRow: const [Icons.edit_outlined, Icons.save_outlined],
        headline: l10n.onboardingPage5Headline,
        subtext: l10n.onboardingPage5Subtext,
      ),
      _OnboardingPage(
        icon: Icons.call_merge,
        iconRow: const [Icons.call_merge, Icons.call_split],
        headline: l10n.onboardingPage6Headline,
        subtext: l10n.onboardingPage6Subtext,
      ),
      _OnboardingPage(
        icon: Icons.auto_stories,
        headline: l10n.onboardingPage7Headline,
        subtext: l10n.onboardingPage7Subtext,
      ),
    ];

/// #0 온보딩 — 풀스크린 3-슬라이드 + 마지막 슬라이드에 권한 요청 결합.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _pageController = PageController();
  int _index = 0;

  // 2026-08-11: 온보딩 완료 여부 확인은 이제 이 화면이 빌드되기 전에 라우터
  // redirect(`app_router.dart`)에서 끝난다 — 이미 완료한 사용자는 이 위젯 자체가
  // 만들어지지 않으므로, 여기서 다시 확인하고 되돌려보낼 필요가 없다.

  // 2026-08-24: 온보딩에서 미디어 라이브러리 권한(READ_MEDIA_VIDEO 등)을 미리
  // 요청하던 단계를 제거했다 — 실제 파일 선택은 `file_picker`가 Android SAF(시스템
  // 파일 선택 도구)로 처리해 애초에 이 권한이 전혀 필요 없었고(요청 결과와 무관하게
  // 항상 그대로 진행시켰을 만큼 있으나 마나 했다), Google Play "사진 및 동영상 권한
  // 정책" 위반으로 업데이트 심사가 거절됐다(2026-08-24, `AndroidManifest.xml`의
  // READ_MEDIA_VIDEO 선언도 함께 제거).
  Future<void> _complete() async {
    await ref.read(localKvStoreProvider).setJson(_onboardingDoneKey, true);
    if (mounted) context.go('/home');
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final pages = _pagesOf(l10n);
    final isLast = _index == pages.length - 1;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: TextButton(
                  onPressed: _complete,
                  child: Text(l10n.onboardingSkip),
                ),
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: pages.length,
                onPageChanged: (i) => setState(() => _index = i),
                itemBuilder: (context, i) {
                  final page = pages[i];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (page.iconRow != null)
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              for (final icon in page.iconRow!) ...[
                                if (icon != page.iconRow!.first) const SizedBox(width: AppSpacing.lg),
                                Container(
                                  width: 96,
                                  height: 96,
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.primaryContainer,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(icon, size: 40, color: theme.colorScheme.primary),
                                ),
                              ],
                            ],
                          )
                        else
                          Container(
                            width: 160,
                            height: 160,
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primaryContainer,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(page.icon, size: 72, color: theme.colorScheme.primary),
                          ),
                        const SizedBox(height: AppSpacing.xxl),
                        Text(page.headline, style: AppTypography.display.copyWith(fontSize: 26), textAlign: TextAlign.center),
                        const SizedBox(height: AppSpacing.md),
                        Text(
                          page.subtext,
                          style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                pages.length,
                (i) => AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: i == _index ? 20 : 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: i == _index ? theme.colorScheme.primary : theme.dividerColor,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenMargin, vertical: AppSpacing.md),
              child: PrimaryButton(
                label: isLast ? l10n.onboardingStart : l10n.onboardingNext,
                onPressed: () {
                  if (isLast) {
                    _complete();
                  } else {
                    _pageController.nextPage(
                      duration: const Duration(milliseconds: 280),
                      curve: Curves.easeOutCubic,
                    );
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

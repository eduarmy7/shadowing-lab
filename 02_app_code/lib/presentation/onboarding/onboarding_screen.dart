import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/permissions/permission_service.dart';
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
  final String headline;
  final String subtext;
  const _OnboardingPage({required this.icon, required this.headline, required this.subtext});
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
      _OnboardingPage(
        icon: Icons.auto_stories,
        headline: l10n.onboardingPage3Headline,
        subtext: l10n.onboardingPage3Subtext,
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
  // 2026-08-08: 번역 문구를 state에 미리 저장해두면 언어를 나중에 바꿔도 화면엔 옛
  // 언어 텍스트가 남는다 — 표시 여부만 상태로 들고, 실제 문구는 build()에서 그때의
  // l10n으로 매번 새로 가져온다.
  bool _showPermissionNotice = false;

  @override
  void initState() {
    super.initState();
    // 이미 온보딩을 마친 사용자는 곧바로 홈으로 — 재실행 시 반복 노출 방지.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final done = await ref.read(onboardingCompletedProvider.future);
      if (done && mounted) context.go('/home');
    });
  }

  Future<void> _complete() async {
    // 2026-08-08: 마이크 권한 요청 제거 — 앱 어디에도 실제 오디오 녹음/분석 코드가
    // 없다("따라 말하기" 단계는 사용자가 스스로 소리 내어 말하는 시간을 확보해주는
    // 타이머일 뿐, 앱은 그 소리를 듣거나 저장하지 않는다). 있으나 마나 한 권한을
    // 요청해 사용자를 불필요하게 막을 이유가 없다.
    final permissionService = ref.read(permissionServiceProvider);
    final mediaResult = await permissionService.requestMediaLibrary();

    // 권한 거부 시에도 진행 허용 — "나중에 설정에서 허용 가능" 안내 후 계속.
    if (mounted && mediaResult != AppPermissionStatus.granted) {
      setState(() => _showPermissionNotice = true);
      await Future.delayed(const Duration(milliseconds: 900));
    }

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
            if (_showPermissionNotice)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenMargin),
                child: Container(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.errorContainer.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(AppSpacing.sm),
                  ),
                  child: Text(l10n.onboardingPermissionNotice, style: theme.textTheme.bodySmall),
                ),
              ),
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

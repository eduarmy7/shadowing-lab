import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/formatters.dart';
import '../../domain/entities/user_stats.dart';
import '../../l10n/gen/app_localizations.dart';
import '../common_widgets/primary_button.dart';
import '../home/home_controller.dart';
import '../providers/repository_providers.dart';

/// #6 학습 완료 요약 — 세션 종료 시 진입. 전면 광고는 여기서만 트리거된다
/// (학습 화면(#5) 내부에는 광고 SDK 호출이 전혀 없음 — 몰입 보호 원칙).
class SessionSummaryScreen extends ConsumerStatefulWidget {
  final LearningSessionResult result;
  const SessionSummaryScreen({super.key, required this.result});

  @override
  ConsumerState<SessionSummaryScreen> createState() => _SessionSummaryScreenState();
}

class _SessionSummaryScreenState extends ConsumerState<SessionSummaryScreen> {
  @override
  void initState() {
    super.initState();
    // 세션 종료 시점의 자연스러운 전환 지점 — 스킵 가능 전면 광고(01_ux_design.md).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(adServiceProvider).showInterstitial(minSkipSeconds: 5);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final statsAsync = ref.watch(userStatsProvider);
    final result = widget.result;
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.screenMargin),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('🎉', style: TextStyle(fontSize: 56)),
                const SizedBox(height: AppSpacing.md),
                Text(
                  result.isFullyCompleted ? l10n.sessionCompletedTitle : l10n.sessionProgressedTitle,
                  style: theme.textTheme.headlineMedium,
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  l10n.sentencesAndDuration(result.sentencesCompleted, Formatters.duration(l10n, result.durationMs)),
                  style: theme.textTheme.bodyMedium,
                ),
                statsAsync.maybeWhen(
                  data: (stats) => stats.currentStreakDays > 0
                      ? Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(l10n.streakDaysCount(stats.currentStreakDays), style: theme.textTheme.bodyMedium),
                        )
                      : const SizedBox.shrink(),
                  orElse: () => const SizedBox.shrink(),
                ),
                const SizedBox(height: AppSpacing.xl),
                Row(
                  children: [
                    Expanded(
                      child: SecondaryButton(
                        label: l10n.continueReview,
                        onPressed: () =>
                            context.pushReplacement('/shadowing/${result.mediaId}?source=local'),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: PrimaryButton(label: l10n.goHome, onPressed: () => context.go('/home')),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

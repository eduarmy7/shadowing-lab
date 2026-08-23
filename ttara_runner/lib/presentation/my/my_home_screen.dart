import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../l10n/gen/app_localizations.dart';
import '../common_widgets/ad_removal_sheet.dart';
import '../common_widgets/skeleton_loader.dart';
import '../home/home_controller.dart';
import '../providers/purchase_providers.dart';

/// #10 마이 홈 — 스트릭 요약, 광고 제거 구매 상태, 설정/기록 메뉴.
class MyHomeScreen extends ConsumerWidget {
  const MyHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final semantic = theme.extension<AppSemanticColors>()!;
    final statsAsync = ref.watch(userStatsProvider);
    final adsRemovedAsync = ref.watch(adsRemovedProvider);
    final adsRemoved = adsRemovedAsync.maybeWhen(data: (v) => v, orElse: () => false);
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.tabMy)),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenMargin, vertical: AppSpacing.md),
        children: [
          statsAsync.when(
            loading: () => const SkeletonCardList(count: 1),
            error: (e, st) => const SizedBox.shrink(),
            data: (stats) => Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                border: Border.all(color: theme.dividerColor),
                borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
              ),
              child: stats.hasAnyRecord
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(l10n.streakStudyingCount(stats.currentStreakDays), style: theme.textTheme.bodyMedium),
                        const SizedBox(height: AppSpacing.sm),
                        _WeekHeatmapRow(heatmap: stats.dailyHeatmap),
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          l10n.totalSentencesAndTime(stats.totalSentences, Formatters.duration(l10n, stats.totalStudyTimeMs)),
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    )
                  : Text(l10n.startFirstStudy, style: theme.textTheme.bodyMedium),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          if (!adsRemoved)
            InkWell(
              onTap: () => showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                builder: (_) => const AdRemovalSheet(),
              ),
              borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
              child: Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
                ),
                child: Row(
                  children: [
                    Icon(Icons.block, color: theme.colorScheme.primary),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(child: Text(l10n.adRemovalBannerTitle)),
                    Icon(Icons.chevron_right, size: 20, color: theme.colorScheme.onSurfaceVariant),
                  ],
                ),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
              child: Row(
                children: [
                  Icon(Icons.check_circle, size: 18, color: semantic.success),
                  const SizedBox(width: AppSpacing.sm),
                  Text(l10n.adRemovalPurchasedLabel, style: theme.textTheme.bodyMedium),
                ],
              ),
            ),
          const SizedBox(height: AppSpacing.lg),
          _MenuTile(label: l10n.allHistory, onTap: () => context.push('/my/history')),
          const Divider(height: AppSpacing.lg),
          _MenuTile(
              label: l10n.sectionLearningDefaults, onTap: () => context.push('/my/settings/learning-defaults')),
          _MenuTile(label: l10n.notificationSettings, onTap: () => context.push('/my/settings/notifications')),
          _MenuTile(label: l10n.displaySettings, onTap: () => context.push('/my/settings/display')),
          _MenuTile(label: l10n.language, onTap: () => context.push('/my/settings/language')),
          _MenuTile(label: l10n.accountLabel, onTap: () => context.push('/my/settings/account')),
          _MenuTile(label: l10n.customerSupport, onTap: () => context.push('/my/support')),
          const Divider(height: AppSpacing.lg),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
            child: Text(l10n.versionText(AppConstants.appVersion), style: theme.textTheme.bodySmall),
          ),
        ],
      ),
    );
  }
}

class _WeekHeatmapRow extends StatelessWidget {
  final Map<String, int> heatmap;
  const _WeekHeatmapRow({required this.heatmap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final now = DateTime.now();
    return Row(
      // 2026-08-23 버그 수정: i=0(맨 왼쪽)이 6일 전이고 오늘이 맨 오른쪽(마지막)에
      // 오게 돼 있어서, "오늘 공부하면 왜 맨 뒤 칸부터 채워지냐"는 사용자 피드백이
      // 있었다 — 오늘이 맨 앞(왼쪽)에 오고 과거로 갈수록 뒤로 가도록 순서를 뒤집는다.
      children: List.generate(7, (i) {
        final day = now.subtract(Duration(days: i));
        final key = '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
        final count = heatmap[key] ?? 0;
        final intensity = count == 0 ? 0.08 : (0.3 + (count / 20).clamp(0, 0.7));
        return Padding(
          padding: const EdgeInsets.only(right: 4),
          child: Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: intensity),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        );
      }),
    );
  }
}

class _MenuTile extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _MenuTile({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(label, style: Theme.of(context).textTheme.bodyMedium),
      trailing: const Icon(Icons.chevron_right, size: 20),
      onTap: onTap,
    );
  }
}

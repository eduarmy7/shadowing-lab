import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/formatters.dart';
import '../../l10n/gen/app_localizations.dart';
import '../common_widgets/ad_removal_sheet.dart';
import '../common_widgets/skeleton_loader.dart';
import '../home/home_controller.dart';
import '../providers/purchase_providers.dart';
import '../providers/repository_providers.dart';

/// #10 마이 홈 — 스트릭 요약, 광고 제거 구매 상태, 설정/기록 메뉴.
class MyHomeScreen extends ConsumerWidget {
  const MyHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final semantic = theme.extension<AppSemanticColors>()!;
    final statsAsync = ref.watch(userStatsProvider);
    final adsRemovedAsync = ref.watch(adsRemovedProvider);
    final packageInfoAsync = ref.watch(packageInfoProvider);
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
            // 2026-08-28: 이전엔 `AppConstants.appVersion`에 박아둔 '1.0.0' 문자열을
            // 그대로 보여줘서, 빌드 번호(+9→...→+15)가 아무리 올라가도 사용자 눈엔
            // 항상 같은 버전으로 보였다(실사용자 제보 — 업데이트됐는지 구분이 안 됨).
            // 실제 설치된 빌드에서 읽은 진짜 버전/빌드번호(`packageInfoProvider`)를
            // 보여줘 항상 정확하게 유지되도록 한다.
            child: Text(
              packageInfoAsync.maybeWhen(
                data: (info) => l10n.versionText('${info.version} (${info.buildNumber})'),
                orElse: () => l10n.versionText('...'),
              ),
              style: theme.textTheme.bodySmall,
            ),
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
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).toString();
    final now = DateTime.now();
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      // 2026-08-23 버그 수정: i=0(맨 왼쪽)이 6일 전이고 오늘이 맨 오른쪽(마지막)에
      // 오게 돼 있어서, "오늘 공부하면 왜 맨 뒤 칸부터 채워지냐"는 사용자 피드백이
      // 있었다 — 오늘이 맨 앞(왼쪽)에 오고 과거로 갈수록 뒤로 가도록 순서를 뒤집는다.
      children: List.generate(7, (i) {
        final day = now.subtract(Duration(days: i));
        final key = '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
        final count = heatmap[key] ?? 0;
        final intensity = count == 0 ? 0.08 : (0.3 + (count / 20).clamp(0, 0.7));
        // 2026-08-27 추가 — 실사용자·지인 다수가 "어느 칸이 오늘인지" 헷갈려했다는
        // 피드백(방향을 안내하는 표시가 전혀 없었다) — 칸 아래에 요일을 작게 붙이고,
        // 오늘 칸만 "오늘" 텍스트로 대체 + 강조색으로 눈에 띄게 한다.
        final label = i == 0 ? l10n.weekHeatmapTodayLabel : DateFormat.E(locale).format(day);
        return Padding(
          padding: const EdgeInsets.only(right: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: intensity),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(height: 2),
              SizedBox(
                width: 20,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    label,
                    style: AppTypography.caption.copyWith(
                      fontSize: 10,
                      color: i == 0 ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant,
                      fontWeight: i == 0 ? FontWeight.w700 : FontWeight.w400,
                    ),
                  ),
                ),
              ),
            ],
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

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/formatters.dart';
import '../../l10n/gen/app_localizations.dart';
import '../common_widgets/empty_state.dart';
import '../common_widgets/skeleton_loader.dart';
import '../home/home_controller.dart';

/// #11 학습 기록 상세 — 캘린더 히트맵(GitHub 잔디 스타일) + 누적 통계.
/// 색상만이 아닌 진하기+숫자 병기로 접근성 확보(색맹 사용자 대응).
class LearningHistoryScreen extends ConsumerWidget {
  const LearningHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(userStatsProvider);
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.historyTitle)),
      body: statsAsync.when(
        loading: () => const Padding(
          padding: EdgeInsets.all(AppSpacing.screenMargin),
          child: SkeletonCardList(count: 3),
        ),
        error: (e, st) => Center(child: Text(l10n.historyLoadError)),
        data: (stats) {
          if (!stats.hasAnyRecord) {
            return Center(
              child: EmptyState(
                icon: Icons.calendar_today_outlined,
                title: l10n.noRecordsTitle,
                description: l10n.noRecordsDescription,
              ),
            );
          }
          return Padding(
            padding: const EdgeInsets.all(AppSpacing.screenMargin),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.last8Weeks, style: theme.textTheme.titleMedium),
                const SizedBox(height: AppSpacing.sm),
                _HeatmapGrid(heatmap: stats.dailyHeatmap),
                const SizedBox(height: AppSpacing.lg),
                Text(l10n.cumulativeStats, style: theme.textTheme.titleMedium),
                const SizedBox(height: AppSpacing.sm),
                _StatRow(label: l10n.totalStudyDaysLabel, value: l10n.totalStudyDaysValue(stats.totalStudyDays)),
                _StatRow(label: l10n.totalSentencesLabel, value: l10n.totalSentencesValue(stats.totalSentences)),
                _StatRow(label: l10n.totalStudyTimeLabel, value: Formatters.duration(l10n, stats.totalStudyTimeMs)),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _HeatmapGrid extends StatelessWidget {
  final Map<String, int> heatmap;
  const _HeatmapGrid({required this.heatmap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final now = DateTime.now();
    final days = List.generate(56, (i) => now.subtract(Duration(days: 55 - i)));

    Color colorFor(int count) {
      if (count == 0) return theme.colorScheme.surfaceContainerHighest;
      if (count < 5) return theme.colorScheme.primary.withValues(alpha: 0.3);
      if (count < 15) return theme.colorScheme.primary.withValues(alpha: 0.6);
      return theme.colorScheme.primary;
    }

    return Wrap(
      spacing: 4,
      runSpacing: 4,
      children: days.map((day) {
        final key = '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
        final count = heatmap[key] ?? 0;
        return Tooltip(
          message: l10n.dateSentencesTooltip(day.month, day.day, count),
          child: Container(
            width: 14,
            height: 14,
            decoration: BoxDecoration(color: colorFor(count), borderRadius: BorderRadius.circular(3)),
          ),
        );
      }).toList(),
    );
  }
}

class _StatRow extends StatelessWidget {
  final String label;
  final String value;
  const _StatRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: theme.textTheme.bodyMedium),
          Text(value, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

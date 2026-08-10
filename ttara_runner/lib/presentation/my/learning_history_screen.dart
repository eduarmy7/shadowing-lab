import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/formatters.dart';
import '../../domain/entities/daily_study_entry.dart';
import '../../l10n/gen/app_localizations.dart';
import '../common_widgets/empty_state.dart';
import '../common_widgets/skeleton_loader.dart';
import '../home/home_controller.dart';

/// #11 학습 기록 상세 — 캘린더 히트맵(GitHub 잔디 스타일) + 누적 통계 +
/// 2026-08-10부터 월별/일별 상세 기록(책별 문장 범위) 추가.
///
/// 이번 달은 접힌 상태 없이 바로 펼쳐서 보여주고, 지난 달들은 [ExpansionTile]로 접어둔
/// 채 제목(연/월)만 노출 — 탭해야 그 달의 일자별 상세가 펼쳐진다(사용자 요청: "해당
/// 달에 해당하는 것만 일자별로 보여주고... 해당 달이 아닌 것은 달을 클릭해야").
class LearningHistoryScreen extends ConsumerWidget {
  const LearningHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(userStatsProvider);
    final dailyLogAsync = ref.watch(dailyStudyLogProvider);
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
          return ListView(
            padding: const EdgeInsets.all(AppSpacing.screenMargin),
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
              const SizedBox(height: AppSpacing.lg),
              const Divider(),
              const SizedBox(height: AppSpacing.sm),
              Text(l10n.monthlyRecordsSectionTitle, style: theme.textTheme.titleMedium),
              const SizedBox(height: AppSpacing.sm),
              dailyLogAsync.when(
                loading: () => const Padding(
                  padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (e, st) => Text(l10n.historyLoadError),
                data: (log) => _MonthlyRecordsList(dailyLog: log),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _MonthlyRecordsList extends StatelessWidget {
  final Map<String, List<DailyStudyEntry>> dailyLog;
  const _MonthlyRecordsList({required this.dailyLog});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    if (dailyLog.isEmpty) {
      return Text(l10n.noRecordsThisMonth, style: Theme.of(context).textTheme.bodyMedium);
    }

    // yyyy-MM-dd 키를 yyyy-MM(월)로 묶는다 — 문자열 사전순 정렬이 곧 날짜순 정렬과
    // 같아서(고정 자릿수 zero-padding) 별도 DateTime 파싱 없이 바로 정렬 가능하다.
    final dateKeys = dailyLog.keys.toList()..sort((a, b) => b.compareTo(a));
    final byMonth = <String, List<String>>{};
    for (final dateKey in dateKeys) {
      (byMonth[dateKey.substring(0, 7)] ??= []).add(dateKey);
    }
    final monthKeys = byMonth.keys.toList()..sort((a, b) => b.compareTo(a));

    final now = DateTime.now();
    final currentMonthKey = '${now.year}-${now.month.toString().padLeft(2, '0')}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final monthKey in monthKeys)
          _MonthSection(
            monthKey: monthKey,
            dateKeys: byMonth[monthKey]!,
            dailyLog: dailyLog,
            isCurrentMonth: monthKey == currentMonthKey,
          ),
      ],
    );
  }
}

class _MonthSection extends StatelessWidget {
  final String monthKey; // yyyy-MM
  final List<String> dateKeys; // yyyy-MM-dd, 최신순 정렬됨
  final Map<String, List<DailyStudyEntry>> dailyLog;
  final bool isCurrentMonth;

  const _MonthSection({
    required this.monthKey,
    required this.dateKeys,
    required this.dailyLog,
    required this.isCurrentMonth,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final parts = monthKey.split('-');
    final year = int.parse(parts[0]);
    final month = int.parse(parts[1]);
    final title = l10n.monthGroupLabel(year, month);

    final dayWidgets = [for (final dateKey in dateKeys) _DaySection(dateKey: dateKey, entries: dailyLog[dateKey]!)];

    if (isCurrentMonth) {
      return Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: AppSpacing.xs),
            ...dayWidgets,
          ],
        ),
      );
    }

    return Theme(
      data: theme.copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        childrenPadding: const EdgeInsets.only(bottom: AppSpacing.sm),
        title: Text(title, style: theme.textTheme.titleSmall),
        children: dayWidgets,
      ),
    );
  }
}

class _DaySection extends StatelessWidget {
  final String dateKey; // yyyy-MM-dd
  final List<DailyStudyEntry> entries;
  const _DaySection({required this.dateKey, required this.entries});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final parts = dateKey.split('-');
    final month = int.parse(parts[1]);
    final day = int.parse(parts[2]);
    final totalMs = entries.fold<int>(0, (sum, e) => sum + e.durationMs);

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.sm),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          border: Border.all(color: theme.dividerColor),
          borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(l10n.dayGroupLabel(month, day),
                    style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                Text(l10n.dailyStudyTimeLabel(Formatters.duration(l10n, totalMs)), style: theme.textTheme.bodySmall),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            for (final e in entries)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  '${e.fileName} · ${_rangeLabel(l10n, e)}',
                  style: theme.textTheme.bodySmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _rangeLabel(AppLocalizations l10n, DailyStudyEntry e) {
    // minIndex/maxIndex는 0-based로 저장돼 있다 — 화면 표기는 다른 화면들(#5 목록 등)과
    // 마찬가지로 1-based(+1)로 보여준다.
    if (e.minIndex == e.maxIndex) {
      return l10n.sentenceRangeSingleLabel(e.minIndex + 1);
    }
    return l10n.sentenceRangeLabel(e.minIndex + 1, e.maxIndex + 1, e.sentencesStudied);
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
